#!/usr/bin/env perl

use common::sense;

use English qw( -no_match_vars );
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Data::Dump qw(pp);
use File::Basename;
use Getopt::Long;
use Readonly;
use Path::Class;
use JSON::XS;
use Log::Log4perl qw(:easy);

use Application::Backup;

Readonly our $DEFAULT_CONFIG_FILE => "$RealBin/config.json";
Readonly our $DEFAULT_BACKUP_DIR  => 'S:\Dropbox\Games\Role-Playing Games\.Campaigns\.backups';

our $program = fileparse ($PROGRAM_NAME);

our $options = {
	backup_dir  => $DEFAULT_BACKUP_DIR,
	config_file => $DEFAULT_CONFIG_FILE,
	verbose     => 0,
};

our $config = {};

sub main {
	GetOptions(
		'backup_dir|b:s'  => \$options->{backup_dir},
		'config_file|c:s' => \$options->{config_file},
		'verbose|v'       => \$options->{verbose},
		'help|usage|?'    => sub { usage(); }
	);

	Log::Log4perl->easy_init({
		level  => $options->{verbose} ? $TRACE : $INFO,
		file   => ">>$RealBin/../log/fg-backup.log",
		layout => '%d{ISO8601} [%5p] (%c) %m%n',
	});

	# Capture and log all fatal errors to our own logger.

	$SIG{__DIE__} = sub {
		if ($^S) {    # We're in an eval {}
			return;
		}
		$Log::Log4perl::caller_depth++;
		my $logger = get_logger("");
		$logger->fatal(@_);
		die @_;       # Now really terminate.
	};

	# $SIG{__WARN__} = sub {
	# 	local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
	# 	WARN @_;
	# };

	TRACE "Loading config file: $options->{config_file}";

	my $config_file = file($options->{config_file});

	if (-e $config_file) {
		$config = decode_json $config_file->slurp;
	}
	else {
		my $error = sprintf("Missing config file: %s", $config_file);
		ERROR $error;
		say $error;
		usage();
	}

	Application::Backup->new({
		backup_dir => dir($options->{backup_dir}),
		config     => $config,
	})->run;

	return undef;
}

sub usage {
	print qq(
$program

  Tool for backing up Fantasy Grounds campaign data

OPTIONS:

  -b|backup_dir   Base backup directory to use.
                  default: $DEFAULT_BACKUP_DIR

  -c|config_file  Location of JSON config file
                  default: $DEFAULT_CONFIG_FILE

  -v|verbose      Provide more verbose output.

  -?|help|usage   This usage information

USAGE:

  $program
  $program -v
  $program -usage

);
	exit 1;
}

main();
