#!/usr/bin/perl
#
# Simple perl script to build a self-made full text index.
#
# Martin Schobert <martin@weltregierung.de>
#

use DBD::Pg;
use Getopt::Long;
use strict;
use locale;
use POSIX 'locale_h';

# the minimum length of word to include in the full text index
my $MIN_WORD_LENGTH = 3;

# the minimum length of the substrings in the full text index
my $MIN_SUBSTRING_LENGTH = 3;

my $dbh;

sub quit {
    print "rollback\n"; 
    $dbh->rollback();
    exit(1);
}

sub break_up {

    my $string = lc(shift); # convert strings to lower case

    my @subs = ();
    
    foreach my $s (split(/\W+/, $string)) {
	my $len = length($s);

	next if ($len < $MIN_WORD_LENGTH);

	for(my $i = 0; $i <= $len - $MIN_SUBSTRING_LENGTH; $i++) {
	    my $tmp = substr($s, $i);
	    push(@subs, $tmp);
	}
    }
    
    return \@subs;
}

sub main {

    my $database;
    my $user;
    my $passwd;
    my $table;
    my $primary_key = 'id';
    my $cols;
    my $locale = 'de_DE.ISO8859-15';
    my $rebuild = 0;
    

    GetOptions ("locale=s"  => \$locale,
		"db=s"      => \$database,
		"user=s"    => \$user,
		"passwd=s"  => \$passwd,
		"table=s"   => \$table,
		"primkey=s" => \$primary_key,
		"columns=s" => \$cols,
		"rebuild"   => \$rebuild);


    if (not $database or not $table or not $cols) {
	print 
	    "usage: $0 [--user user] [--passwd pw] [--primkey name] [--locale ident] ".
	    "--db database --table table --columns column[,column...] [--rebuild]\n\n".
	    " locale  : the locate setting. default is 'de_DE.ISO8859-15'\n".
	    " columns : create single sub string index on strings from specified columns\n".
	    " rebuild : drop full text index table before building it";
	return 1;
    }
    
    print "using locale '$locale'\n";
    setlocale(LC_CTYPE, $locale) or die "Invalid locale $locale";

    my @cols = split(/,/, $cols);
    my $itbl_name = 'fti_' . join('_', @cols);
    
    $dbh = DBI->connect("dbi:Pg:dbname=$database", $user, $passwd,
			{ChopBlanks => 1,
			 AutoCommit => 0});
    
    if(not defined $dbh) {
	print "Connecting to database failed!\n";
	return 1;
    }
    
#    $dbh->begin_work();

    $SIG{'INT'} = \&quit;

    
    ### get number of items in table

#    my $count_sth = $dbh->prepare("select count($primary_key) as _count from $table") || return 1;
#    $count_sth->execute() || return 1;
#    my $count = $count_sth->fetchrow_hashref()->{_count};
#    print "table '$table' has $count rows\n";
#    $count_sth->finish();

    my $count = 36000000;
    ### create fti table

    if($rebuild) {
	print "dropping index table '$itbl_name'\n";
	$dbh->do("drop table $itbl_name") || return 1;	
    }

    print "creating index table '$itbl_name'\n";
    $dbh->do("create table $itbl_name (string text, id integer)") || return 1;
    
    ### prepare insert statement
    my $insert_query = "insert into $itbl_name values (?, ?)";
    my $insert_sth = $dbh->prepare_cached($insert_query) || return 1;
  
    ### prepare and run select query
    my $select_query = 
	"declare c cursor for ".
	"select (\"" . join("\" || ' ' || \"", @cols) .
	"\") as string, $primary_key from $table";
    

    $dbh->do($select_query) || return 1;

    my $select_sth = $dbh->prepare("fetch 1 from c") || return 1;
    #my $select_sth = $dbh->prepare($select_query) || return 1;
    #$select_sth->execute() || return 1;
    
    
    ### run ...
    my $i = 0;
    $|=1;
#    while(my $ref = $select_sth->fetchrow_hashref()) {
    while(($select_sth->execute()) and defined(my $ref = $select_sth->fetchrow_hashref())) {
	
	my $subs = break_up($ref->{string});
	foreach my $s (@$subs) {
#	    print "$s -> $ref->{$primary_key}\n";
	    $insert_sth->bind_param(1, $s) || return 1;
	    $insert_sth->bind_param(2, $ref->{$primary_key}) || return 1;
	    $insert_sth->execute() || return 1;
	}
	if($i % 1000 == 0) {
	    my $p = $i * 100 / $count;
	    print "\r" . ( "=" x int(0.65 * $p) ) . sprintf("=> [%.2f %]", $p);
	}
	$i++;
    }

    print "\nfti table create\ncreating index on fti table\n";
    
    $dbh->do("create index idx_${itbl_name}_string on $itbl_name(string)") || return 1;
    $dbh->do("create index idx_${itbl_name}_id on $itbl_name(id)") || return 1;


#    $count_sth = $dbh->prepare("select count(id) as _count from $itbl_name") || return 1;
#    $count_sth->execute() || return 1;
#    $count = $count_sth->fetchrow_hashref()->{_count};
#    print "table '$itbl_name' has $count rows\n";
#    $count_sth->finish();
    
    print "\nfinished\n";
    $dbh->commit();
    $select_sth->finish();
    $insert_sth->finish();
    $dbh->disconnect();
    return 0;
}

if(main() == 1) {
    print "error\n";
    quit();
}
else {
    exit 0;
};
