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

sub add_file {
	my $self = shift;
	my $file_details = shift;

	return $self->db->add_file($file_details);
}

sub get_campaign {
	my ($self, $name, $dir) = @_;

	my $dirty = 0;

	my $campaign = $self->db->get_campaign($name, $dir);

	unless ($campaign) {
		$campaign = $self->db->add_campaign($name, $dir);
		$dirty++;
	}

	return ($campaign, $dirty);
}

sub get_campaign_files {
	my ($self, $id) = @_;

	my $files = $self->db->get_campaign_files($id) || [];

	my $result = {};
	for my $file (@{$files}) {
		$result->{$file->{file_path}} = $file
	}

	return $result;
}

__PACKAGE__->meta->make_immutable;

1;
