#!perl -w
use strict;
use warnings;

my $conf_file = 'books.txt';
my $p_file = 'kjv.txt';

open(my $in,'<', $conf_file) or die("unable to open $conf_file");
my @lines = <$in>;
print @lines;
close $in;

open (my $fh, '<', $p_file) or die("unable to open $p_file");
my $i=0;
my $j=0;
while (<$fh>)
{
#	$_ =~ /^\s*$/ and die "Blank line detected at $.\n";
	$_ =~ /^\s*$/ and next;
	$i++;
	print "$i $_ \n";
	FOO: {
		for my $line (@lines) {
			$j++;
			print "$j $line\n";
			if ($_ =~ m|$line|) {
				print "$& found in line number : $. : $_ \n" ;
				last;
				#last FOO;
			}
		}
	}
}

close $fh;

