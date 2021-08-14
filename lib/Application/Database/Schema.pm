package Application::Database::Schema;

use common::sense;

use Data::Dump qw(pp);
use Moose;

use namespace::clean -except => [qw(meta)];

sub UPGRADE_TO_1 {
	return q(BEGIN TRANSACTION;

CREATE TABLE campaign (
	id       INTEGER PRIMARY KEY AUTOINCREMENT,
	base_dir TEXT NOT NULL,
	name     TEXT NOT NULL,

	UNIQUE (base_dir, name)
);

CREATE TABLE files (
	id          INTEGER PRIMARY KEY AUTOINCREMENT,
	campaign_id INTEGER NOT NULL,
	file_path   TEXT_NOT_NULL,
	modified    INTEGER NOT NULL,
	size        INTEGER NOT NULL,
	hash        TEXT NOT NULL,

	UNIQUE(campaign_id, file_path)
)
COMMIT;
);
}

__PACKAGE__->meta->make_immutable;

1;
