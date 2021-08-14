package Application::Backup;

use common::sense;

use Data::Dump qw(pp);
use Log::Log4perl qw(:easy);
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
	isa      => 'Str',
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

sub run {
	my $self = shift;

	$self->cache->test;

	INFO "Running";
}


__PACKAGE__->meta->make_immutable;

1;
