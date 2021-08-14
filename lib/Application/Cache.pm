package Application::Cache;

use common::sense;

use Data::Dump qw(pp);
use Log::Log4perl qw(:easy);
use Moose;
use Path::Class;

use Application::Database;

use namespace::clean -except => [qw(meta)];

has 'dir' => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);

has 'db' => (
	is       => 'ro',
	isa      => 'Application::Database',
	default  => sub {
		my $self = shift;
		return Application::Database->new({
			data_dir => dir($self->dir),
			trace_db => 0,
		})
	},
	lazy => 1
);

sub test {
	my $self = shift;

	my $db = $self->db->dbh;

	INFO "TESTING";
}

__PACKAGE__->meta->make_immutable;

1;
