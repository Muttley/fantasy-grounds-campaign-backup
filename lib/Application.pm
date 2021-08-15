package Application;

use common::sense;

use Data::Dump qw(pp);
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


sub process {
	my ($self, $dir) = @_;

	my $name = $dir->basename;

	INFO sprintf("Checking campaign: %s", $dir->basename);

	# my $campaign = $self->cache->get_campaign($dir->basename, $dir);
	my $campaign = Application::Campaign->new({dir => $dir, cache => $self->cache})
		->load
		->check_files;
}

sub run {
	my $self = shift;
	INFO "Running";

	for my $version (keys %{$self->config}) {
		INFO "Checking $version campaigns";

		my $version_config = $self->config->{$version};

		my $dir = dir ($version_config->{Directory});
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

			$self->process(dir($dir, $entry));
		}
	}
}


__PACKAGE__->meta->make_immutable;

1;
