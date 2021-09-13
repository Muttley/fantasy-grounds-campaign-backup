#!/usr/bin/env perl

use common::sense;

use English qw( -no_match_vars );
use FindBin qw($RealBin);
use lib "$RealBin/../lib";

use Application::Util qw(base_dir);
use Data::Dump qw(pp);
use File::Basename;
use Getopt::Long;
use Readonly;
use Path::Class;
use JSON::XS;
use Log::Log4perl qw(:easy);

use Application;

chdir base_dir;

Readonly our $DEFAULT_CONFIG_FILE => file(base_dir()->relative, "conf/config.json")->relative;
Readonly our $DEFAULT_BACKUP_DIR  => 'S:\Dropbox\Games\Role-Playing Games\.Campaigns\.backups';

Readonly our $LOG_FORMAT => '%d{ISO8601} [%5p] (%c) %m%n';

our $program = fileparse ($PROGRAM_NAME);

our $options = {
	backup_dir  => $DEFAULT_BACKUP_DIR,
	config_file => $DEFAULT_CONFIG_FILE,
	debug       => 0,
	stdout      => 0,
	trace       => 0,
};

our $config = {};

sub main {
	GetOptions(
		'backup_dir|b:s'  => \$options->{backup_dir},
		'config_file|c:s' => \$options->{config_file},
		'debug|v'         => \$options->{debug},
		'trace|vv'        => \$options->{trace},
		'help|usage|?'    => sub { usage(); }
	);

	my $logfile = sprintf("%s/backup.log", $options->{backup_dir});

	my $log_level = $INFO;
	if ($options->{trace} || $options->{debug}) {
		$log_level = $options->{trace} ? $TRACE : $DEBUG;
	}

	Log::Log4perl->easy_init(
		{
			level => $log_level,
			file => ">>$logfile",
			layout => $LOG_FORMAT,
		},
		{
			level => $log_level,
			file => "STDOUT",
			layout => $LOG_FORMAT,
		}
	);

	# Capture and log all fatal errors to our own logger.
	#
	$SIG{__DIE__} = sub {
		if ($^S) {    # We're in an eval {}
			return;
		}
		$Log::Log4perl::caller_depth++;
		my $logger = get_logger("");
		$logger->fatal(@_);
		die @_;       # Now really terminate.
	};

	$SIG{__WARN__} = sub {
		local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
		WARN @_;
	};

	DEBUG "Loading config file: $options->{config_file}";

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

	Application->new({
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

  -v|debug        Provide more verbose output.

  -vv|trace       Provide even more verbose output.

  -?|help|usage   This usage information

USAGE:

  $program
  $program -v
  $program -usage

);
	exit 1;
}

main();
