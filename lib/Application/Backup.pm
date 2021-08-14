package Application::Backup;

use v5.20;
use feature qw(signatures);

use common::sense;

use Data::Dump qw(pp);
use File::Find;
use Log::Log4perl qw(:easy);
use Path::Class;
use Moose;

use Application::Cache;

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

sub _check_file ($self, $campaign, $dir, $file) {
	$file = file ($file);
	warn $file->relative($dir);
}

sub process ($self, $dir) {
	INFO "Checking campaign: " . $dir->basename;

	my $campaign = $self->cache->get_campaign($dir->basename, $dir);

	find({
		wanted => sub {
			my $entry = $_;
			return if -d $entry;
			$self->_check_file($campaign, $dir, $entry)
		},
		no_chdir => 1
	}, $dir );
}

sub run ($self) {
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

			next if ($entry =~ m/$version_config->{SkipDirectoryMatch}/);

			$self->process(dir($dir, $entry));
		}
	}
}


__PACKAGE__->meta->make_immutable;

1;
