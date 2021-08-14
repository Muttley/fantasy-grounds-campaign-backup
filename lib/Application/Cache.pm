package Application::Cache;

use v5.20;
use feature qw(signatures);

use common::sense;

use Data::Dump qw(pp);
use Log::Log4perl qw(:easy);
use Moose;
use Path::Class;

use Application::Database;

use namespace::clean -except => [qw(meta)];

has 'dir' => (
	is       => 'ro',
	isa      => 'Path::Class::Dir',
	required => 1,
);

has 'db' => (
	is       => 'ro',
	isa      => 'Application::Database',
	default  => sub {
		my $self = shift;
		return Application::Database->new({
			data_dir => $self->dir,
			trace_db => 0,
		})
	},
	lazy => 1
);

sub get_campaign ($self, $name, $dir) {

	my $campaign = $self->db->get_campaign($name);

	unless ($campaign) {
		$campaign = $self->db->add_campaign($name, $dir)
	}

	return $campaign;
}

__PACKAGE__->meta->make_immutable;

1;
