package Application::Database::Schema;

use common::sense;

use Data::Dump qw(pp);
use Moose;

use namespace::clean -except => [qw(meta)];

sub UPGRADE_TO_1 {
	return q(BEGIN TRANSACTION;

COMMIT;
);
}

__PACKAGE__->meta->make_immutable;

1;
