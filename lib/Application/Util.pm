package Application::Util;

use common::sense;

use Exporter;

use Data::Dump qw(dump pp);

our @ISA = qw(Exporter);
our @EXPORT = qw(get_module_subs);

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
