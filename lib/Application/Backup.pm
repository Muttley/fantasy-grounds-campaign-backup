package Application::Backup;

use common::sense;

use Data::Dump qw(pp);
use File::Find;
use Log::Log4perl qw(:easy);
use Path::Class;
use Moose;

use Application::Cache;

use namespace::clean -except => [qw(meta)];



__PACKAGE__->meta->make_immutable;

1;
