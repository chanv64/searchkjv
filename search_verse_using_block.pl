#!perl -w
use strict;
use warnings;
use IO::Handle;
use 5.010;
use Getopt::Long qw(GetOptions);
use Data::Dumper;


my $p_file = 'kjv_newer.txt'; # main file for reading only
my $o_file = 'verse.txt'; #output file, also printed to console

###############################################################
# get arguments and load into $strSearch , if empty then exit #
###############################################################
my $book;
my $usage = "Usage: $0 --book <Str_to_search>  \n";

GetOptions(
    'book|b=s' => \$book,
) or die $usage;
 
my $strSearch = qq{@ARGV}; #get argument string as the verse to search

if ($strSearch eq "") # if no argument, print a msg and exit
{
	die $usage;
}

#process the book option
my $selectedbook = "";

my %hash=read_ref_file(); # hash variable to store the data read from ref file

if ($book) {
	$selectedbook = book_exist($book,%hash); 
	if ($selectedbook ne "") {
		print $book," found!\n";
	}
	else {
		print $book," not found\n";
	}
}

#open kjv.txt
open (my $fh, '<', $p_file) or die("unable to open $p_file");


open (my $fhwrite, '>', $o_file) or die("Unable to open $o_file");
my $start="";
my $versenum=0;
my $block = '';
my $found = 0;
my $matchcount = 0;
my $versecount =0;
my $whichbook = "";

#local $/ = "\n\n"; 
FOO: {
	while (<$fh>)
	{
	#	$_ =~ /^\s*$/ and die "Blank line detected at $.\n";
#		$_ =~ /^\s*$/ and next;
		if (/^\s*$/) { # blank line
			my $match = () = $block =~ /$strSearch/gi;
			if ($match) {
				$versenum = $.;
				if (($versenum > 49) && ($versenum <99859)) {
					chomp($block); #remove last newline char
					my $line = $block;
					$line =~ s/[\n\r]/ /g; #remove all newline chars from string
					($start) = split /[ \s]+/, $line, 2; #get the verse number
					$versenum=$.; # get the line number
					$whichbook = get_book($versenum,%hash);
					if ($selectedbook ne "") {
						if ($selectedbook eq $whichbook) {
							print "\"",$whichbook,"$line\"\n" ;
							print $fhwrite "\"",$whichbook,"$line\"\n" ;
							#print "Matches = $match\n";
							$matchcount += $match;
							$versecount++;
						}
					}
					else {
						print "\"",$whichbook,"$line\"\n" ;
						print $fhwrite "\"",$whichbook,"$line\"\n" ;
						#print "Matches = $match\n";
						$matchcount += $match;
						$versecount++;
					}
					$found = 1;
					#last FOO; #exit loop
				}
			}
			$block = ''; # reset for next block
		} else {
			$block .= $_;
		}
	}
}
close $fh; # close kjv.txt

#use Data::Dumper;
#print $fhwrite Dumper(\%hash);

if ($found) {
	print "Total occurences = $matchcount \n";
	print "Total verses found = $versecount \n";
} else {
	print "String \"$strSearch\" not found\n";
}

if ($book) {
	if (book_exist($book,%hash) ne "") {
		print $book," found!\n";
	}
	else {
		print $book," not found\n";
	}
}

close $fhwrite; # close output file

#
# subroutine to return hash data read from a reference file
#
sub read_ref_file{
	my $inbook = 'obook2.txt'; # ref file for reading only

	open(my $in,'<', $inbook) or die("unable to open $inbook");
	
	my %localhash; # hash variable to store the data read from ref file

	while (<$in>) {
		chomp; # remove newline from end of string
	#    my ($book, @cols) = split /,/;
		my ($book, $linenum, $bookname, $bookabbr) = split /,/; # data is delimited by ,
		my %comp;
		@comp{qw(Linenum Bookname Abbr)} = ($linenum,$book,$bookabbr);
		$localhash{$bookname} = { %comp};
	#    push @{ $hash{$bookname} }, $book, $linenum, $bookabbr;
	}
	close $in;
	return %localhash;
}

sub book_exist {
	my $booktosearch = shift;
    my %myHash = @_;

	my $found = "";
	foreach my $key (keys %myHash ) {
		if (($key eq $booktosearch) || ($booktosearch eq $myHash{$key}{Abbr})) {
			$found=$myHash{$key}{Abbr};
			last;
		}
	}
	return $found;
}

sub get_book {

	# Hash variable to store  
    # the passed arguments  
	my $verselinenum = shift;
    my %myHash = @_;
	
#	print $fhwrite "verselinenum = $versenum\n";
#	print "Verse Line number ",$verselinenum,"\n";
	
	my @keys = sort { $myHash{$a}{Linenum} <=> $myHash{$b}{Linenum} } keys %myHash;
	my $bookfound="Genesis";

	foreach my $key ( @keys ) {
		if ($myHash{$key}{Linenum} > $verselinenum) {
#			print $fhwrite "Found! in $bookfound\n";
#			print "Found! in $bookfound\n";
			last;
		}
		else {
			$bookfound = $key;
			if ($key eq "Revelation") { # last book
#				print "found! in $bookfound\n";
#				print $fhwrite "found! in $bookfound\n";
				last;
			}
		}
	}
	return $myHash{$bookfound}{Abbr};
#	return $bookfound;
}
