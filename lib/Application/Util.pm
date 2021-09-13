package Application::Util;

use common::sense;

use Data::Dump qw(pp);
use Exporter;
use Path::Class;

our @ISA = qw(Exporter);
our @EXPORT = qw(base_dir get_module_subs);

sub base_dir {
	my $file = file(__FILE__);
	return dir($file->dir, '../../')->resolve;
}

sub get_module_subs {  # get hashref of all coderefs in package
	my $package = shift;
	my $regex   = shift || qr/.*/;

	no strict 'refs';

	my $stash = $package . '::';

	my $subs;
	for my $name (keys %$stash ) {
		next unless $name =~ m/$regex/;

		my $sub = $package->can ($name);   # use UNIVERSAL::can

		next unless defined $sub;

		my $proto = prototype ($sub);

		next if defined $proto and length ($proto) == 0;

		$subs->{$name}++;
	}

	return $subs;
}

1;
