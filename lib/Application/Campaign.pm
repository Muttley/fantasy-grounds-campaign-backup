package Application::Campaign;

use v5.20;
use feature qw(signatures);

use common::sense;

use Data::Dump qw(pp);
use Digest::SHA qw(sha1_hex);
use File::Find;
use Log::Log4perl qw(:easy);
use Moose;
use Path::Class;

use Application::Cache;

use namespace::clean -except => [qw(meta)];

has 'cache' => (
	is  => 'ro',
	isa => 'Application::Cache',
);

has 'cached_files' => (
	is       => 'rw',
	isa      => 'HashRef[Maybe[HashRef]]',
	default  => sub {return {}},
	lazy     => 1
);

has 'campaign' => (
	is => 'rw',
	isa => 'HashRef',
);

has 'dir' => (
	is  => 'ro',
	isa => 'Path::Class::Dir',
	required => 1,
);

has 'dirty' => (
	is      => 'rw',
	isa     => 'Int',
	default => sub { return 0 },
	lazy    => 1
);

has 'found_files' => (
	is       => 'rw',
	isa      => 'HashRef[Maybe[HashRef]]',
	default  => sub {return {}},
	lazy     => 1
);

has 'name' => (
	is      => 'ro',
	isa     => 'Str',
	default => sub {
		return shift->dir->basename
	},
	lazy => 1
);

sub _check_file {
	my ($self, $file) = @_;

	my $campaign = $self->campaign;

	my $relative_fn = $file->relative($self->dir)->stringify;

	TRACE sprintf("Checking file '%s' for changes", $relative_fn);

	my $digest = sha1_hex($file->slurp);
	my $stat   = $file->stat;

	my $file_details = {
		campaign_id => $campaign->{id},
		file_path   => $relative_fn,
		hash        => $digest,
		modified    => $stat->mtime,
		size        => $stat->size,
	};

	$self->found_files->{$relative_fn} = $file_details;

	if (my $cached = $self->cached_files->{$relative_fn}) {
		if ($file_details->{modified} > $cached->{modified} &&
			$file_details->{size}    != $cached->{size}     &&
			$file_details->{hash}    ne $cached->{hash}
		) {
			DEBUG sprintf("File changed: %s", $relative_fn);
			$self->cache->update_file($cached->{id}, $file_details);
			$self->dirty(1);
		}
	}
	else {
		DEBUG sprintf("New file: %s", $relative_fn);
		$self->cache->add_file($file_details);
		$self->dirty(1);
	}
}

sub check_files {
	my $self = shift;

	find({
		wanted => sub {
			my $entry = $_;
			return if -d $entry;
			$self->_check_file(file($entry))
		},
		no_chdir => 1
	}, $self->dir );

	$self->cleanup_deleted_files;

	return $self;
}

sub cleanup_deleted_files {
	my $self = shift;

	for my $file (keys %{$self->cached_files}) {
		unless ($self->found_files->{$file}) {
			$self->cache->remove_file($self->cached_files->{$file}->{id});
			$self->dirty(1);
		}
	}
}

sub load {
	my $self = shift;

	TRACE "Loading campaign";

	my ($campaign, $dirty) = $self->cache->get_campaign($self->name, $self->dir);

	$self->cached_files(
		$self->cache->get_campaign_files($campaign->{id})
	);

	TRACE sprintf(
		"Campaign has %d cached files",
		scalar keys %{$self->cached_files}
	);

	$self->campaign($campaign);
	$self->dirty($dirty);

	return $self;
}



__PACKAGE__->meta->make_immutable;

1;
