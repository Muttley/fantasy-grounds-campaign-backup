package Application::Campaign;

use v5.20;
use feature qw(signatures);

use common::sense;

use Digest::SHA1 qw(sha1_hex);
use Path::Class;
use File::Find;
use Data::Dump qw(pp);
use Moose;

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

	my $relative_fn = $file->relative($self->dir);

	if (my $cached = $self->cached_files->{$relative_fn}) {
		# Check if file has changed
	}
	else {
		# Add file to cache and found_files
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

	return $self;
}

sub load {
	my $self = shift;

	my ($campaign, $dirty) = $self->cache->get_campaign($self->name, $self->dir);

	$self->cached_files(
		$self->cache->get_campaign_files($campaign->{id})
	);

	$self->campaign($campaign);
	$self->dirty($dirty);

	return $self;
}



__PACKAGE__->meta->make_immutable;

1;
