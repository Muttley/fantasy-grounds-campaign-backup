package Application;

use common::sense;

use Archive::Zip;
use Cwd;
use Data::Dump qw(pp);
use DateTime;
use File::Find;
use Log::Log4perl qw(:easy);
use Path::Class;
use Moose;

use Application::Cache;
use Application::Campaign;

use namespace::clean -except => [qw(meta)];

has 'config' => (
	is       => 'ro',
	isa      => 'HashRef',
	required => 1
);

has 'backup_dir' => (
	is       => 'ro',
	isa      => 'Path::Class::Dir',
	required => 1
);

has 'cache' => (
	is       => 'ro',
	isa      => 'Application::Cache',
	default  => sub {
		return Application::Cache->new({dir => shift->backup_dir});
	},
	lazy => 1
);

has 'processed_campaigns' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { return {} },
);

sub _backup_campaign {
	my $self = shift;
	my $campaign = shift;
	my $version  = shift;

	my $dt = DateTime->now;
	my $datestamp = sprintf("%s%s", $dt->ymd(''), $dt->hms(''));

	my $backup_dir = dir($self->backup_dir, $version);
	$backup_dir->mkpath;

	my $archive_base_name = lc $campaign->name;
	$archive_base_name =~ s/\s+/_/g;
	$archive_base_name =~ s/\(|\)//g;
	$archive_base_name =~ s/\[|\]//g;

	my $zip_filename = file(
		$backup_dir, sprintf("%s__%s.zip", $archive_base_name, $datestamp)
	)->stringify;

	INFO "Backing up campaign to: $zip_filename";

	my $cwd = getcwd;

	my $zip = Archive::Zip->new;
	chdir $campaign->dir;
	$zip->addTree('.', $campaign->name);
	$zip->writeToFileNamed($zip_filename);

	chdir $cwd;
}

sub _clean_up_campaigns {
	my $self = shift;

	my $campaigns = $self->cache->get_campaigns;

	for my $campaign (@{$campaigns}) {

		unless ($self->processed_campaigns->{$campaign->{base_dir}}) {
			INFO sprintf("Removing campaign from cache: %s", $campaign->{name});
			$self->cache->remove_campaign($campaign->{id});
		}
	}
}

sub process {
	my ($self, $dir, $version) = @_;

	my $name = $dir->basename;

	DEBUG sprintf("Checking campaign: %s", $dir->basename);

	my $campaign = Application::Campaign->new({dir => $dir, cache => $self->cache})
		->load
		->check_files;

	$self->processed_campaigns->{$dir} = $campaign;

	if ($campaign->dirty) {
		DEBUG "Campaign has been modified";
		$self->_backup_campaign($campaign, $version);
	}
	else {
		DEBUG "Campaign has not been modified";
	}

}

sub run {
	my $self = shift;
	INFO "Running";

	for my $version (keys %{$self->config}) {
		DEBUG "Checking $version campaigns";

		my $version_config = $self->config->{$version};

		my $dir = dir ($version_config->{Directory});

		my @path_elements;
		for my $element (@{$dir->{dirs}}) {
			if ($^O eq 'MSWin32') {
				if ($element =~ m/\%.*\%/) {
					$element =~ s/^\%|\%$//g;
					$element = $ENV{$element};
				}
			}
			else {
				if ($element =~ m/\$.*/) {
					$element =~ s/^\$//;
					$element = $ENV{$element};
				}
			}

			push @path_elements, $element;
		}

		$dir = dir(@path_elements);

		my $dh = $dir->open;

		while (my $entry = $dh->read) {
			chomp $entry;

			next if ($entry eq "." || $entry eq "..");

			next unless -d dir($dir, $entry);

			my $skip = 0;
			for my $match (@{$version_config->{DirectorySkipMatches}}) {
				if ($entry =~ m/$match/i) {
					$skip++;
					last;
				}
			}

			next if $skip;

			$self->process(dir($dir, $entry), $version);
		}
	}

	$self->_clean_up_campaigns;
}


__PACKAGE__->meta->make_immutable;

1;
