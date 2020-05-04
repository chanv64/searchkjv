#!perl -w
use strict;
use warnings;

my $book1 = 'books.txt';
my $book2 = 'books_proper_name.txt';
my $p_file = 'kjv_newer.txt';
my $o_file = 'obook3.txt';

open(my $in1,'<', $book1) or die("unable to open $book1");
my @lines = <$in1>;
close $in1;

open(my $in2,'<', $book2) or die("unable to open $book2");
my @bookslines = <$in2>;
close $in2;

open (my $fh, '<', $p_file) or die("unable to open $p_file");

open (my $fhwrite, '>', $o_file) or die("Unable to open $o_file");

my $k = @lines;
print "Number of books = $k\n";
#print $fhwrite "Number of books = $k\n";

my $i=0;
my $j=0;
FOO: {
	while (<$fh>)
	{
	#	$_ =~ /^\s*$/ and die "Blank line detected at $.\n";
		$i++;
		$_ =~ /^\s*$/ and next;
#		print "$i $_";
		my $book = $lines[$j];
		if ($_ =~ m|$book|) {
			chomp($_);
			print "The book $j. $_ is found in line number $. : $_\n" ;
			print $fhwrite "$_,$.,$bookslines[$j]" ;
			$j++; # move to the next book
			if ($j == @lines) {
				last FOO;
			}
		}
	}
}

close $fh;
close $fhwrite;

