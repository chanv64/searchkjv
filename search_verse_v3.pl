#!perl -w
use strict;
use warnings;
use IO::Handle;
use 5.010;
use Getopt::Long qw(GetOptions);
use Data::Dumper;
use Win32::Console::ANSI;
use Term::ANSIColor;
use Path::Tiny qw(path);
use Benchmark 'cmpthese';

# version 2 : search word based on new kjv text single line
# version 3 : tiny slurp mode

my $p_file = 'kjv_newer.txt'; # main file for reading only
#my $o_file = 'verse.txt'; #output file, also printed to console

###############################################################
# get arguments and load into $strSearch , if empty then exit #
###############################################################
my $book;
my $printv='';
my $lastverse='';
my $abook='';
my $info='';
my $random='';

my $usage = "Usage: $0 --info --random --book <bookname> --print <verse> --lastverse <book> <Str_to_search>  \n";

GetOptions(
    'book|b=s' => \$book,
	'print|p'    => \$printv, 
	'lastverse|l'    => \$lastverse, 
	'abook'			=> \$abook,
	'info'			=> \$info,
	'random'			=> \$random,
) or die $usage;

my %refhash=read_ref_file(); # hash variable to store the data read from ref file
my %kjvhash=read_kjv_file(%refhash); # hash variable to store the data read from ref file

#process the info option
if ($info) {
	print_info_length(%kjvhash);

#	cmpthese -1 => {
#		info 		=>  sub {print_info(%refhash)},
#		infolen		=>  sub {print_info_length(%refhash)},
#	};
	exit;
}

if ($random) {
	$SIG{INT} = sub { die "Caught a sigint $!" };
	while (1) {
		print_random_verse(%kjvhash);
		sleep 2;
	}
	exit;
}
 
my $strSearch = qq{@ARGV}; #get argument string as the verse to search

if ($strSearch eq "") # if no argument, print a msg and exit
{
	if ($printv) {
		die "Enter a verse to search\n";
	}
	elsif ($lastverse) {
		die "Enter a Book to search for last verse\n";
	}
	elsif ($abook) {
		die "Enter a Book to print\n";
	}
	else {
		die "Search String missing\n\n$usage";
	}
}
#process the book option
my $selectedbook = "";

if ($book) {
	$selectedbook = book_exist($book,%refhash); 
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

#process the printv option
if ($printv) {
	my ($bbook) = $strSearch =~ /(^[1-2]{0,1}[a-zA-Z]{3,5})/;   #
	my ($verse) = $strSearch =~ /(\d{1,3}:\d{1,3})/;  # 
	if ($bbook) {
		print "book = $bbook\n";
	}
	if ((defined $bbook) && (defined $verse)) {
		$selectedbook = book_exist($bbook,%refhash); 
		if ($selectedbook ne "") {
#for testing
#			my $bindex=1;
#			foreach my $key (keys %refhash ) {
#				print "$bindex. ";
#				print_verse($refhash{$key}{Abbr},$verse,%refhash);
#				$bindex++;
#			}
			print_verse($bbook,$verse,%refhash);
		}
		else {
			print $bbook," not found\n";
			print "These are the valid books\n";
			print_books();
		}
	}
	exit;
}

#process the lastverse option
if ($lastverse) {
	$selectedbook = book_exist($strSearch,%refhash); 
	if ($selectedbook ne "") {
#		print "Selected Book = $selectedbook\n";
		print "Last Verse of Book $selectedbook\n";
		print print_last_verse($selectedbook,%refhash);
	}
	else {
		print $strSearch," not found\n";
		print "These are the valid books\n";
		print_books();
	}
	exit;
}

#process print all verses in the book
if ($abook) {
	my ($bb) = $strSearch =~ /(^[1-3]{0,1}[a-zA-Z]{3,4})/;
	my ($ch) = $strSearch =~ /(\d+$)/;

	$selectedbook = book_exist($bb,%refhash); 
	if ($selectedbook ne "") {
#		print_book($selectedbook,$ch,%refhash);
		print_book_new($selectedbook,$ch,%kjvhash);
	}
	else {
		print $strSearch," not found\n";
		print "These are the valid books\n";
		print_books();
	}
	exit;
}

#process the book option
my ($nmatch,$nverse) = search_for_verses($selectedbook,$strSearch);

if ($nmatch) {
	print "Total occurences = $nmatch \n";
	print "Total verses found = $nverse \n";
} else {
	print "String \"$strSearch\" not found in $selectedbook\n";
}


#
# end of Main program
#

############################################################################
#                             Subroutines                                  #
############################################################################
sub print_info_length {
	my %myHash = @_;
	
	my $longestverse=0;
	my $shortestverse=1000;
	my $nlongwords=0;
	my $nshortwords=0;
	my (@lverse, @sverse);
	my $countnumverses = 0;
	my $midVerseNum = 15551;
	my $lastVerseNum = 31102;
	my ($firstVerse, $midVerse, $lastVerse);
	my $tchars = 0;
	my $twords = 0;
	my (%ccount, %vcount, %wcount, %booklw);
	my @orderedbooks = qw (Gen Exo Lev Num Deut Jos Judg Ruth 1Sam 2Sam 1Kings 2Kings 
				1Chro 2Chro Ezra Neh Est Job Psa Pro Eccl Song Isa Jer Lam 
				Eze Dan Hos Joe Amo Oba Jon Mic Nah Hab Zep Hag Zec Mal 
				Matt Mar Luk Joh Act Rom 1Cor 2Cor Gal Eph Php Col 1Thes 
				2Thes 1Tim 2Tim Tit Phm Heb Jam 1Pet 2Pet 1Joh 2Joh 3Joh Jud Rev);

	$SIG{INT} = sub { die "Caught a sigint $!" };

	my %handles;

	foreach my $bk (@orderedbooks) {
		my $fileName = "./out/$bk.csv";

		if (!exists $handles{$fileName}) {
			open my $fileOut, '>', $fileName or die "Failed to create $fileName: $!\n";
			$handles{$bk} = $fileOut;
		}
	}

	#kjv in %myHash
	# the key is actually the line number in the kjv file from 1st to last line
	# but for the hash, the key is stored as string. But if the sort is done on
	# numeric, it will sort as numeric. <=> sort in numeric, 'cmp' sort in string
	#
	foreach my $key (sort {$a <=> $b} keys %myHash) {
		my $line = $myHash{$key}{Verse};
		my $nchars = $myHash{$key}{NumOfChars};
		my $currentverse = $myHash{$key}{BookVerse};

		# print info about Bible
		# find number of verses in each chapter
		my ($tmpbook) = $currentverse =~ /(^[1-3]{0,1}[a-zA-Z]{3,5})/;
		$vcount{$tmpbook}++;

		# find number of chapters in each book
		my ($chap) = $currentverse =~ /(^[1-3]{0,1}[a-zA-Z]{3,5}\d{1,3}):/;
		$ccount{$chap}++;

		# count total chars in Bible
		$tchars = $tchars + $nchars;

		# count total words in Bible
		my $nwords = count_words($line);
		$twords = $twords + $nwords;
		$wcount{$tmpbook}+=$nwords;

		# find longest verse in each book and list the verse
		if ($booklw{$tmpbook}) {
			if ($nwords > $booklw{$tmpbook}{lw}) {
				$booklw{$tmpbook}{wverse} = $currentverse;
				$booklw{$tmpbook}{lw} = $nwords;
			}
			if ($nchars > $booklw{$tmpbook}{lc}) {
				$booklw{$tmpbook}{cverse} = $currentverse;
				$booklw{$tmpbook}{lc} = $nchars;
			}
		}
		else {
			$booklw{$tmpbook}{wverse} = $currentverse;
			$booklw{$tmpbook}{lw} = $nwords;
			$booklw{$tmpbook}{cverse} = $currentverse;
			$booklw{$tmpbook}{lc} = $nchars;
		}

		my $verse = "${currentverse} ${line}";

		my $nline = join '|', split / /, $line;
		print {$handles{$tmpbook}} "$nwords\|$nline\n";

		# find longest verse
		if ($nchars == $longestverse) {
			push @lverse, $verse;
		} elsif ($nchars > $longestverse) {
			$longestverse = $nchars;
			while (@lverse) {shift @lverse}
			push @lverse, $verse;			
			$nlongwords = $nwords;
		}

		# find shortest verse
		if ($nchars == $shortestverse) {
			push @sverse, $verse;
		} elsif ($nchars < $shortestverse) {
			$shortestverse = $nchars;
			while (@sverse) {shift @sverse}
			push @sverse, $verse;			
			$nshortwords = $nwords;
		}

		$countnumverses++;
		if ($countnumverses == 1) {
			$firstVerse = $verse;
		}
		elsif ($countnumverses == $midVerseNum) {
			$midVerse = $verse;
		}
		elsif ($countnumverses == $lastVerseNum) {
			$lastVerse = $verse;
		}
	}
	close $_ foreach values %handles;

	print "Longest verse = ";
	print "\"@lverse\"\n";
	print "Number of chars in longest verse  = $longestverse; ";
	print "Number of words in longest verse  = ",$nlongwords,"\n";
	print "Shortest verse = ";
	print "\"@sverse\"\n";
	print "Number of chars in shortest verse = $shortestverse; ";
	print "Number of words in shortest verse = ",$nshortwords,"\n";
	print "Total number of verses in Bible   = $countnumverses\n";
	print "Total number of chars in Bible    = $tchars\n";
	print "Total number of words in Bible    = $twords\n";
	print "First verse  = $firstVerse\n";
	print "Middle verse = $midVerse\n";
	print "Last verse   = $lastVerse\n";

	my @keys = sort { $myHash{$a}{NumOfChars} <=> $myHash{$b}{NumOfChars} } keys %myHash;
	my $i = 1;
	print "Shortest and longest 5 verses\n";
	my %count;

	foreach my $key ( @keys ) {
		if (($i<6)||($i>($countnumverses-5))) {
#			print "$myHash{$key}{NumOfChars}\n";
#			print "${myHash{$key}{BookVerse}} ${myHash{$key}{Verse}}\n";
		}
		$i++;

		#sort according to frequency 
		foreach my $str (split /\s+/, $myHash{$key}{Verse}) {
			$count{$str}++;
		}
	}

	# count number of chapters for each book
	my %chapcount;
	foreach my $bookchapter (keys %ccount) {
	#foreach my $bookchapter (sort {$a cmp $b} keys %ccount) {
		# same as : foreach my $bookchapter (sort keys %ccount) {
		my ($bookonly) = $bookchapter =~ /(^[1-3]{0,1}[a-zA-Z]{3,5})/;
		$chapcount{$bookonly}++;
	}

	my $booknum = 1;
	my ($tnumchap, $tnumverses, $tnumwords);

	use IO::Tee;
	my $teelog = "binfo.txt";
	open my $fn, ">", $teelog or die "open tee failed.\n";
	my $tee = new IO::Tee(\*STDOUT, $fn);

	printf $tee "%28s\n","OLD TESTAMENT";
	printf $tee "%-4s %-10s %-10s %-10s %-10s %-18s %-10s %-18s %-10s\n", "Num", "Book" ,
       		"Chapters" , "Verses" , "Words" , "Longest by word", "NumofWords" ,
       		"Longest by char" , "NumofChars" ;
	foreach my $cbook (@orderedbooks) {
		printf $tee "%-4s %-10s %-10s %-10s %-10s %-18s %-10s %-18s %-10s\n", $booknum, $cbook, 
			$chapcount{$cbook}, $vcount{$cbook}, $wcount{$cbook}, 
			$booklw{$cbook}{wverse}, $booklw{$cbook}{lw}, $booklw{$cbook}{cverse}, $booklw{$cbook}{lc};
		$booknum++;
		$tnumchap+=$chapcount{$cbook};
		$tnumverses+=$vcount{$cbook};
		$tnumwords+=$wcount{$cbook};
		if ($booknum == 40) {
			print $tee "\n";
			printf $tee "%28s\n","NEW TESTAMENT";
			printf $tee "%-4s %-10s %-10s %-10s %-10s %-18s %-10s %-18s %-10s\n", "Num", "Book" , 
			"Chapters" , "Verses" , "Words", "Longest Verse", "NumofWords" ,
			"Longest by char" , "NumofChars" ;
		}
	}
	printf $tee "%-4s %-10s %-10s %-10s %-10s\n", "", "" , $tnumchap , $tnumverses , $tnumwords;

	#sort according to frequency 
	print $tee "\n";
	print $tee "Frequency of words\n";
	my $j=0;
	foreach my $word (sort { $count{$a} <=> $count{$b} } keys %count) {
		printf $tee "%-22s %-7s", $word, $count{$word};
		$j++;
		if (!($j % 5)) {
			print $tee "\n";
		}
	}
	print $tee "\n";

       # use this if the key is not needed
       #	use List::Util qw(max);
       #	my $highest = max values %count;
       #	print "$highest\n";
	
	#otherwise use this
	use List::Util qw(reduce);
	my $highest = List::Util::reduce { $count{$b} > $count{$a} ? $b : $a } keys %count;
	print "Highest frequency word: $highest:$count{ $highest }\n";
	$tee->close;
}

sub count_words {
	my ($str) = @_;
	my $num; 
	$num++ while $str =~ /\S+/g;     #/
	return $num;
}

sub print_random_verse {
	my %myHash = @_;
	
	my $randnum = 1+ int rand(31102);
	
	#kjv in %myHash
	foreach my $key (sort {$a <=> $b} keys %myHash) {
		if ($key == $randnum) {
			print "$myHash{$key}{BookVerse} $myHash{$key}{Verse}\n"; 
		}	
	}
}

#
# print book
#
sub print_book {
	my $b = shift;
	my $c = shift;
	my %myHash = @_;
	
	my $linenum=0;
	my $vfound=0;
	
	# return the line number where the book is located
	foreach my $key (keys %myHash ) {
		my $lb = lc $b;
		if ( (lc($key) eq $lb) || ($lb eq lc($myHash{$key}{Abbr}))) {
			$linenum=$myHash{$key}{Linenum};
			$b = $myHash{$key}{Abbr};
			last;
		}
	}
	$SIG{INT} = sub { die "Caught a sigint $!" };
	
	# start searching for the matching string
	#open kjv text
	open (my $fh, '<', $p_file) or die("unable to open $p_file");
BAR3: {
		my $i=1;
		while (<$fh>)
		{
			if (($. == 1) && ($linenum == 1)) {
				next;
			} elsif ($. <= $linenum) {
				next;
			}
			# We are at the beginning of the book now, check if line has the verse numbers
			if (/^(\d{1,3}:\d{1,3})/) {
				if ($c) { # if there is a chapter number
					my ($c1) = $_ =~ /(^\d+)/;
					if ($c == $c1) {
						print "$b$_";
						if (!($i % 10)) {
							print "Press <ENTER> to continue:";
							<STDIN>;
						}
						$i++;
					}
				}
				else {
					print "$b$_"; #otherwise print all verses in the book
					if (!($i % 10)) {
						print "Press <ENTER> to continue:";
						<STDIN>;
					}
					$i++;
				}
				
			}
			else {
				# all verses in the book processed, exit loop
				last BAR3;
			}
		}
	}
	close $fh; # close kjv.txt
}

#
# print book
#
sub print_book_new {
	my $bs = shift;
	my $ch = shift;
	my %myHash = @_;
	
	$SIG{INT} = sub { die "Caught a sigint $!" };
	my $i=1;
	
	# start searching for the matching string
	foreach my $key (sort {$a <=> $b} keys %myHash) {
		my $bv = $myHash{$key}{BookVerse};
		my ($bn) = $bv =~ /(^[1-3]{0,1}[a-zA-Z]{3,4})/;
#		print "bv=$bv bn=$bn\n";
		if (lc($bs) eq lc($bn)) {
			if ($ch) { # if there is a chapter number
				my ($c1) = $bv =~ /(\d+):/;
				if ($ch == $c1) {
					print "$bv $myHash{$key}{Verse}\n";
					if (!($i % 10)) {
						print "Press <ENTER> to continue:";
						<STDIN>;
					}
					$i++;
				}
			}
			else {
				print "$bv $myHash{$key}{Verse}\n"; #otherwise print all verses in the book
				if (!($i % 10)) {
					print "Press <ENTER> to continue:";
					<STDIN>;
				}
				$i++;
			}
		}
	}
}

#
# print last verse
#
sub print_last_verse {
	my $b = shift;
	my %myHash = @_;

	my $linenum=0;
	my $vfound=0;

	# return the line number where the book is located
	foreach my $key (keys %myHash ) {
		my $lb = lc $b;
		if ( (lc($key) eq $lb) || ($lb eq lc($myHash{$key}{Abbr}))) {
			$linenum=$myHash{$key}{Linenum};
			$b = $myHash{$key}{Abbr};
			last;
		}
	}

	# start searching for the last verse
	#open kjv text
	my @buffer;
	open (my $fh, '<', $p_file) or die("unable to open $p_file");
	BAR1: {
		while (<$fh>)
		{
			if (($. == 1) && ($linenum == 1)) {
				next;
			} elsif ($. <= $linenum) {
				next;
			}
			# check also if beginning of string is a numeric char, otherwise stop searching
			if (/^(\d{1,3}:\d{1,3})/) {
				#keep in buffer
				push @buffer, $_;
				shift @buffer if @buffer > 1;	
			}
			else {
				# not numeric char, last verse was previous read
				last BAR1;
			}
		}
	}
	close $fh; # close kjv.txt
	#	print "Last Verse of Book $b\n";
	#	print "@buffer";
	return "@buffer";
}

#
# print verse
#
sub print_verse {
	my $b = shift;
	my $v = shift;
	my %myHash = @_;

	my $linenum=0;
	my $vfound=0;

	# return the line number where the book is located
	foreach my $key (keys %myHash ) {
		my $lb = lc $b;
		if ( (lc($key) eq $lb) || ($lb eq lc($myHash{$key}{Abbr}))) {
			$linenum=$myHash{$key}{Linenum};
			$b = $myHash{$key}{Abbr};
			last;
		}
	}

	# start searching for the matching string
	#open kjv text
	open (my $fh, '<', $p_file) or die("unable to open $p_file");
	BAR2: {
		while (<$fh>)
		{
			if (($. == 1) && ($linenum == 1)) {
				next;
			} elsif ($. <= $linenum) {
				next;
			}
			# check also if beginning of string is a numeric char, otherwise stop searching
			if (/^(\d{1,3}:\d{1,3})/) {
				if (/$v/) {
					$vfound=1;
					print "$b$_";
					last BAR2;
				}
			}
			else {
				# otherwise string is not found
				last BAR2;
			}
		}
	}
	close $fh; # close kjv.txt
	if (!$vfound) {
		print "Verse $b$v doesn't exist in $b\n";
	}
}

#
# subroutine to search for verses
#
sub search_for_verses {
	my ($mybook,$strtoSearch) = @_;

	#open kjv text
	open (my $fh, '<', $p_file) or die("unable to open $p_file");

	my $start="";
	my $versenum=0;
	my $matchcount = 0;
	my $versecount =0;
	my $whichbook = "";
	my @ostr;
	while (<$fh>)
	{
		#	$_ =~ /^\s*$/ and die "Blank line detected at $.\n";
		#	$_ =~ /^\s*$/ and next;
		my $match = () = $_ =~ /\b$strtoSearch\b/gi;
		if ($match) {
			chomp; #remove last newline char
			($start) = split /[ \s]+/, $_, 2; #get the verse number
			$versenum=$.; # get the line number
			$whichbook = get_book($versenum,%refhash);
			if ($mybook) {
				if ($mybook eq $whichbook) { #print only for specified book
					push @ostr, print_found_verse_color($whichbook,$_,$strtoSearch);
					$matchcount += $match;
					$versecount++;
				}
			}
			else {  # print for all books
				push @ostr, print_found_verse_color($whichbook,$_,$strtoSearch);
				$matchcount += $match;
				$versecount++;
			}
		}
	}
	close $fh; # close kjv.txt
	if (@ostr) {
		print @ostr;
	}
	return ($matchcount , $versecount);
}

#
#
#
sub print_found_verse_color {
	my ($wb,$str,$ss) = @_;
	my $len = length($ss);
	my $poscolor=0;
	while ($str =~ /\b$ss\b/ig) {
		$poscolor = $-[0];
		$str = substr($str,0,$poscolor)
		. colored(substr($str,$poscolor,$len),'bold blue')
		. substr($str,$poscolor+$len);
	}
	return "\"",$wb,"$str\"\n";
}

#
# subroutine to return hash data read from a reference file
#
sub read_ref_file{
	my $inbook = 'obook.txt'; # ref file for reading only

	open(my $in,'<', $inbook) or die("unable to open $inbook");

	my %localhash; # hash variable to store the data read from ref file

	while (<$in>) {
		chomp; # remove newline from end of string
		#    my ($book, @cols) = split /,/;
		my ($book, $linenum, $bookname, $bookabbr) = split /,/; # data is delimited by ,
		my %comp;
		@comp{qw(Linenum Bookname Abbr)} = ($linenum,$book,$bookabbr);
		$localhash{$bookname} = { %comp};
		#    push @{ $refhash{$bookname} }, $book, $linenum, $bookabbr;
	}
	close $in;
	return %localhash;
}

sub read_kjv_file {
	my %myHash = @_;
	
	my $infile = "kjv_newer.txt";
	
	#open kjv text
	my @text = path($infile)->lines;

	my $bn = "Gen";
	my $countnumverses = 0;
	my %localhash;
	my $linenum = 1;

	foreach my $line (@text) {
		chomp $line;
		# Check if line has the verse numbers
		if ($line =~ /^(\d{1,3}:\d{1,3})/) {
			my $ostr = $line;
			my ($vv) = $ostr =~ /(\d{1,3}:\d{1,3})/;
			my ($str) = $ostr =~ /\d+:\d+ (.*)/;
			my $nchars = length($str);
			my $currentverse = "$bn$vv";
			my $verse = "$str";
			$countnumverses++;
			my %comp;
			@comp{qw(BookVerse NumOfChars Verse)} = ($currentverse,$nchars,$verse);
			$localhash{$countnumverses} = { %comp};
		}
		else {
			$bn=get_book_name($linenum,%myHash);
		}
		$linenum++;
	}
	return %localhash;
}

sub book_exist {
	my $booktosearch = shift;
	my %myHash = @_;

	my $found = "";
	my $bts = lc $booktosearch;
	foreach my $key (keys %myHash ) {
		if ( (lc($key) eq $bts) || ($bts eq lc($myHash{$key}{Abbr}))) {
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

	my @keys = sort { $myHash{$a}{Linenum} <=> $myHash{$b}{Linenum} } keys %myHash;
	my $bookfound="Genesis";

	foreach my $key ( @keys ) {
		if ($myHash{$key}{Linenum} > $verselinenum) {
			# print $fhwrite "Found! in $bookfound\n";
			# print "Found! in $bookfound\n";
			last;
		}
		else {
			$bookfound = $key;
			if ($key eq "Revelation") { # last book
				# print "found! in $bookfound\n";
				# print $fhwrite "found! in $bookfound\n";
				last;
			}
		}
	}
	return $myHash{$bookfound}{Abbr};
	# return $bookfound;
}

sub get_book_name {
	# Hash variable to store  
	# the passed arguments  
	my $verselinenum = shift;
	my %myHash = @_;

	my @keys = sort { $myHash{$a}{Linenum} <=> $myHash{$b}{Linenum} } keys %myHash;
	my $bookfound="Genesis";

	foreach my $key ( @keys ) {
		if ($myHash{$key}{Linenum} == $verselinenum) {
			$bookfound=$key;
			last;
		}
	}
	return $myHash{$bookfound}{Abbr};
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
