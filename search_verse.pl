#!perl -w
use strict;
use warnings;
use IO::Handle;
use 5.010;
use Getopt::Long qw(GetOptions);
use Data::Dumper;

# version 2 : search word based on new kjv text single line

my $p_file = 'kjv_newer.txt'; # main file for reading only
my $o_file = 'verse.txt'; #output file, also printed to console

###############################################################
# get arguments and load into $strSearch , if empty then exit #
###############################################################
my $book;
my $printv='';

my $usage = "Usage: $0 --book <Str_to_search>  \n";

GetOptions(
    'book|b=s' => \$book,
	'print'    => \$printv, 
) or die $usage;
 
my $strSearch = qq{@ARGV}; #get argument string as the verse to search

if ($strSearch eq "") # if no argument, print a msg and exit
{
	die "Search String missing\n";
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
		print "These are the valid books\n";
		print_books();
		exit;
	}
}

if ($printv) {

}

#open kjv text
open (my $fh, '<', $p_file) or die("unable to open $p_file");


open (my $fhwrite, '>', $o_file) or die("Unable to open $o_file");
my $start="";
my $versenum=0;
my $block = '';
my $matchcount = 0;
my $versecount =0;
my $whichbook = "";

#local $/ = "\n\n"; 
FOO: {
	while (<$fh>)
	{
	#	$_ =~ /^\s*$/ and die "Blank line detected at $.\n";
#		$_ =~ /^\s*$/ and next;
		my $match = () = $_ =~ /$strSearch/gi;
		if ($match) {
			chomp; #remove last newline char
			($start) = split /[ \s]+/, $_, 2; #get the verse number
			$versenum=$.; # get the line number
			$whichbook = get_book($versenum,%hash);
			if ($selectedbook ne "") {
				if ($selectedbook eq $whichbook) { #print only for specified book
					print "\"",$whichbook,"$_\"\n" ;
					print $fhwrite "\"",$whichbook,"$_\"\n" ;
					#print "Matches = $match\n";
					$matchcount += $match;
					$versecount++;
				}
			}
			else {  # print for all books
				print "\"",$whichbook,"$_\"\n" ;
				print $fhwrite "\"",$whichbook,"$_\"\n" ;
				#print "Matches = $match\n";
				$matchcount += $match;
				$versecount++;
			}
			#last FOO; #exit loop
		}
	}
}
close $fh; # close kjv.txt

#use Data::Dumper;
#print $fhwrite Dumper(\%hash);

if ($matchcount) {
	print "Total occurences = $matchcount \n";
	print "Total verses found = $versecount \n";
} else {
	print "String \"$strSearch\" not found\n";
}

close $fhwrite; # close output file

#
# end of Main program
#

############################################################################
#                             Subroutines                                  #
############################################################################
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

sub print_books {
	print "Genesis,Gen          Exodus,Exo              Leviticus,Lev           Numbers,Num         Deuteronomy,Deut\n";
	print "Joshua,Jos           Judges,Judg             Ruth,Ruth               1 Samuel,1Sam       2 Samuel,2Sam\n";
	print "1 Kings,1Ki          2 Kings,2Ki             1 Chronicles,1Chro      2 Chronicles,2Chro  Ezra,Ezra\n";
	print "Nehemiah,Neh         Esther,Est              Job,Job                 Psalms,Psa          Proverbs,Pro\n";
	print "Ecclesiastes,Eccl    Song of Songs,Song      Isaiah,Isa              Jeremiah,Jer        Lamentations,Lam\n";
	print "Ezekiel,Eze          Daniel,Dan              Hosea,Hos               Joel,Joe            Amos,Amo\n";
	print "Obadiah,Oba          Jonah,Jon               Micah,Mic               Nahum,Nah           Habakkuk,Hab\n";
	print "Zephaniah,Zep        Haggai,Hag              Zechariah,Zec           Malachi,Mal         Matthew,Matt\n";
	print "Mark,Mar             Luke,Luk                John,Joh                Acts,Act            Romans,Rom\n";
	print "1 Corinthians,1Cor   2 Corinthians,2Cor      Galatians,Gal           Ephesians,Eph       Philippians,Php\n";
	print "Colossians,Col       1 Thessalonians,1Thes   2 Thessalonians,2Thes   1 Timothy,1Tim      2 Timothy,2Tim\n";
	print "Titus,Tit            Philemon,Phm            Hebrews,Heb             James,Jam           1 Peter,1Pet\n";
	print "2 Peter,2Pet         1 John,1Joh             2 John,2Joh             3 John,3Joh         Jude,Jud\n";
	print "Revelation,Rev\n";
}