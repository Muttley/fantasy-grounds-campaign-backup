package Application::Database;

use common::sense;

use Data::Dump qw(pp);
use DateTime;
use DBI qw(:sql_types);
use Log::Log4perl qw(:easy);
use MIME::Base64 qw(encode_base64);
use Moose;
use Path::Class;
use Scalar::Util qw(looks_like_number);
use Path::Class;

use Application::Database::Schema;
use Application::Util qw(get_module_subs);

use namespace::clean -except => [qw(meta)];

has 'data_dir' => (
	is       => 'ro',
	isa      => 'Path::Class::Dir',
	required => 1,
);

has 'dbh' => (
	is  => 'ro',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $filename = $self->filename;
		my $db_exists = (-e $filename);

		my $dbh = DBI->connect (
			"dbi:SQLite:dbname=$filename",
			"",
			"",
			{sqlite_allow_multiple_statements => 1}
		);
		$dbh->{RaiseError} = 1;

		if ($self->trace_db) {
			$dbh->sqlite_trace (sub {
				my $statement = shift;

				my $logger = get_logger("");

				if ($logger->is_trace) {
					TRACE $statement;
				}
			});
		}

		my $schema = $self->schema;

		my $db_version = $dbh->selectrow_arrayref ('pragma user_version')->[0];

		my $schema_subs = get_module_subs (ref $schema);

		while (1) {
			my $next_schema_version = $db_version;
			$next_schema_version++;

			my $upgrade_method = "UPGRADE_TO_${next_schema_version}";

			last unless $schema_subs->{$upgrade_method};

			my $padded_db_version = sprintf("%04d", $db_version);

			# backup database with current version tag
			my $backup_file = file(
				$self->data_dir,
				"database_backup.schema${padded_db_version}.db"
			)->stringify;

			INFO "Backing up current database to file: $backup_file";

			$dbh->sqlite_backup_to_file ($backup_file);

			$dbh->{AutoCommit} = 0;

			eval {
				INFO "Upgrading database to schema version $next_schema_version";
				my $upgrade_sql = $schema->$upgrade_method ($dbh);

				if ($upgrade_sql) {
					INFO "Running schema upgrade SQL statements";
					$dbh->do ($upgrade_sql);
				}

				$db_version = $next_schema_version;
				$dbh->do ("pragma user_version = $db_version;");
			};
			die $@ if $@;

			$dbh->{AutoCommit} = 1;
		}

		$dbh->do ('pragma temp_store = memory');

		return $dbh;
	}
);

has 'filename' => (
	is       => 'ro',
	isa      => 'Str',
	default  => sub {
		return file (shift->data_dir, "database.db")->stringify;
	}
);

has 'schema' => (
	is       => 'ro',
	isa      => 'Application::Database::Schema',
	default  => sub {
		return Application::Database::Schema->new;
	}
);

has 'trace_db' => (
	is       => 'ro',
	isa      => 'Int',
	default  => sub { return 0 },
	lazy     => 1
);

sub _insert_object {
	my ($self, $table, $object) = @_;

	my @fields;
	my @values;
	my @placeholders;
	for my $key (sort keys %{$object}) {
		push @fields, $key;

		if (looks_like_number ($object->{$key})) {
			push @values, $object->{$key} * 1.0
		}
		else {
			push @values, $object->{$key} || "";
		}

		push @placeholders, "?";
	}

	my $all_fields   = join (", ", @fields);
	my $placeholders = join (", ", @placeholders);

	my $statement = "INSERT INTO $table ($all_fields) VALUES ($placeholders)";

	my $sth = $self->_run_query(
		$statement,
		@values
	);

	my $new_object;

	my $insert_id = $self->dbh->sqlite_last_insert_rowid;

	if ($insert_id) {
		$new_object = $self->_selectall_arrayref_hashes(
			"SELECT * FROM $table WHERE id = ?",
			$insert_id
		)->[0];
	}

	return $new_object || undef;
}

sub _update_object {
	my ($self, $table, $object, $where) = @_;

	my @fields;
	my @values;
	for my $key (sort keys %{$object}) {
		push @fields, "$key=?";

		if (looks_like_number ($object->{$key})) {
			push @values, $object->{$key} * 1.0
		}
		else {
			push @values, $object->{$key} || "";
		}
	}

	my $all_fields   = join (", ", @fields);

	my $statement = "update $table set $all_fields";

	if ($where) {
		my $where_field = (keys %{$where})[0];
		$statement .= " where $where_field=?";
		push @values, $where->{$where_field};
	}

	my $sth = $self->_run_query(
		$statement,
		@values
	);

	return $sth;
}

sub _run_query {
	my ($self, $statement, @values) = @_;

	my $sth = $self->dbh->prepare ($statement);

	$sth->execute (@values) || die $self->dbh->errstr;

	return $sth;
}

sub _selectall_arrayref {
	my ($self, $statement, @values) = @_;

	my $result = $self->dbh->selectall_arrayref(
		$statement,
		{},
		@values
	);

	return $result || [];
}

sub _selectall_arrayref_hashes {
	my ($self, $statement, @values) = @_;

	my $result = $self->dbh->selectall_arrayref(
		$statement,
		{Slice => {}},
		@values
	);

	return $result || [];
}

sub _selectone_arrayref_hashes {
	my ($self, $statement, @values) = @_;

	my $result = $self->_selectall_arrayref_hashes(
		$statement, @values
	)->[0];

	return $result;
}

sub add_file {
	my ($self, $file_details) = @_;

	return $self->_insert_object('files', $file_details);
}

sub add_campaign {
	my ($self, $name, $dir) = @_;

	my $result = $self->_insert_object(
		'campaigns',
		{
			base_dir => $dir->stringify,
			name     => $name
		}
	);

	return $result;
}

sub backup {
	my ($self, $filename) = @_;

	unless ($filename) {
		my $dt = DateTime->now;
		my $ext = $dt->ymd("") . "-" . $dt->hms("");

		$filename = file(
			$self->data_dir,
			"database_backup.$ext.db"
		)->stringify;
	}

	$self->dbh->sqlite_backup_to_file ($filename);
}

sub get_campaign {
	my ($self, $name, $dir) = @_;

	my $result = $self->_selectone_arrayref_hashes(
		'SELECT * FROM campaigns WHERE name=? AND base_dir=?',
		$name, $dir
	);

	return $result;
}

sub get_campaign_files {
	my ($self, $id) = @_;

	my $result = $self->_selectall_arrayref_hashes(
		'SELECT * FROM files WHERE campaign_id=?', $id
	);

	return $result;
}
__PACKAGE__->meta->make_immutable;

1;
