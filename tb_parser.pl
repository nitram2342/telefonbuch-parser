#!/usr/bin/perl
#
# Repair-Script
#
# <martin@berlin.ccc.de>
#

use strict;
use LineReader;
use ContinuationHandler;
use locale;
use POSIX 'locale_h';
use Data::Dumper;

my $locale = 'de_DE.ISO8859-15';
setlocale(LC_CTYPE, $locale) or die "Invalid locale $locale";

$| = 1;

### file sets

my $base_dir = '../telefon';

my $fileset_new = { flags => '01_Flags',
		    nachname => '02_Nachname',
		    vorname => '03_Vorname',
		    namenszusatz_addresszusatz => '04_05_Namenszusatz_Addresszusatz',
		    strassenindex_hausnummer => '07_08_Strassenindex_Hausnummer',
		    strasse => '07_Strasse',
		    detail => '09_Detail',
		    plz => '10_Postleitzahl',
		    ort => '11_Ort',
		    vorwahl => '12_Vorwahl',
		    rufnummer => '13_Rufnummer',
		    webadresse_email => '14_15_Email_Webadresse', # XXX genau verkehrt herum?
		    # strassenname => '99_Strassenname'
		};


my $fileset_mid = { flags => '01_Flags',
		    nachname => '02_Nachname',
		    vorname => '03_Vorname',
		    namenszusatz => '04_Namenszusatz',
		    addresszusatz => '05_Adresszusatz',
		    ortszusatz => '06_Ortszusatz', # XXX
		    strasse => '07_Strasse',
		    hausnummer => '08_Hausnummer',
		    detail => '09_Detail',
		    plz => '10_Postleitzahl',
		    ort => '11_Ort',
		    vorwahl => '12_Vorwahl',
		    rufnummer => '13_Rufnummer',
		    email => '14_Email',
		    webadresse => '15_Webadresse',
		    # strassenname => '99_Strassenname'
		   };

my $fileset_old = { flags => '01_Flags',
		    nachname => '02_Nachname',
		    vorname => '03_Vorname',
		    namenszusatz => '04_Namenszusatz',
		    addresszusatz => '05_Adresszusatz',
		    ortszusatz => '06_Ortszusatz', # XXX
		    strasse => '07_Strasse',
		    hausnummer => '08_Hausnummer',
		    detail => '09_Verweise',
		    plz => '10_Postleitzahl',
		    ort => '11_Ort',
		    vorwahl => '12_Vorwahl',
		    rufnummer => '13_Rufnummer',
		    #email => '14_Email',
		    #webadresse => '15_Webadresse',
		    #strassenname => '99_Strassenname'
		   };
    


### which file and version bit set for which phone book version
my %pbook_version = ( '2007_Fruehjahr' => [$fileset_new, 17],
		      '2006_Herbst'    => [$fileset_new, 16],
		      '2006_Fruehjahr' => [$fileset_new, 15],
		      '2005_Herbst'    => [$fileset_new, 14], # -> 08_Hausnummer fehlt
		      '2005_Fruehjahr' => [$fileset_new, 13],
		      '2004_Herbst'    => [$fileset_new, 12],
		      '2004_Fruehjahr' => [$fileset_new, 11],

		      '2003_Herbst'    => [$fileset_mid, 10],
		      '2003_Fruehjahr' => [$fileset_mid, 9],
		      '2002_Herbst'    => [$fileset_mid, 8],
		      '2002_Fruehjahr' => [$fileset_mid, 7],
		      '2001_Herbst'    => [$fileset_mid, 6],
		      '2001_Fruehjahr' => [$fileset_mid, 5],
		      '2000_Herbst'    => [$fileset_mid, 4],
		      '2000_Fruehjahr' => [$fileset_mid, 3],
		      '1999_Herbst'    => [$fileset_mid, 2],

		      '1999_Fruehjahr' => [$fileset_old, 1],
		      '1998_Herbst'    => [$fileset_old, 0]
		      );


### Sonstige Konstanten

my @service_prefix = ( '0900',
		       '09009',
		       '01888', # IVBB
		       '0180',
		       '0137' , # MABEZ, Gewinnsp. u. Televoting
		       '0138' , # T-VoteCall
		       '0800' , # freecall
		       '0700' , # Rufweiterleitung, "persoenliche Rnr"
		       '0190' , # premium rate, bis 31. dez. 2005
		       '0130' , #
		       '011',

		       '032'    # voip
		       );

# + pager
my @mobile_prefix = sort {length($b) <=> length($a) } qw( 0161
							  0151 
							  0160 0170 0171 0175
							  01520 01522 0162 0172 0173 0174 0152
							  01577 0163 0177 0178
							  0159 0176 0179
							  0157
							  0169 0168 0165 0166
);


my %mobile_prefix;

foreach my $prefix (@mobile_prefix) {
    $mobile_prefix{$prefix} = 1;
}


my %service_prefix;
foreach my $prefix (@service_prefix) {
    $service_prefix{$prefix} = 1;
}

### Vorwahlverzeichnis (VwV)

my %area_code_directory = ();
my $area_code_file = "vorwahlverzeichnis_2007.dat";
open(ACODE, "< $area_code_file") or die "can't open $area_code_file: $!\n";
while(<ACODE>) {
    chomp;
    if(m!^(\d+)\s+(.*)!) {
	if(ref $area_code_directory{$1}) {
	    push @{$area_code_directory{$1}}, $2;
	}
	elsif(not exists $area_code_directory{$1}) {
	    $area_code_directory{$1} = [ $2 ];
	}
    }
}
close ACODE;

my @area_code_list = sort { length($b) <=> length($a) } (keys %area_code_directory);

### parameter

# Telefonbuchversion = s
# resume
# patchfile
# base_dir


my %log_msg = ( zip_code_in_city => 1,
		service_prefix_with_tariff => 0,
		prefix_in_number => 0,
		display_vanity_numbers => 1,
		display_uncertain_vanity_numbers => 1,
		
		cleanup_prefix => 1,
		cleanup_number => 1,
		cleanup_post_code => 1,
		cleanup_city_name => 1,
		cleanup_web => 1,
		cleanup_email => 1,
		check_number => 1
		);


### initialize the line reader

#my $pbook = '2007_Fruehjahr';
#my $pbook = '2006_Herbst';

#my $pbook = '2002_Fruehjahr';

my $pbook = shift;
my $mode = shift;

if(($pbook !~ m!^\d\d\d\d\_(Fruehjahr|Herbst)$!) or ($mode eq '')) {
    print "perl tb_parser.pl <Version> <mode>\n";
    exit 1;
}

my $lr = LineReader->new( $base_dir . '/' . $pbook, $pbook_version{$pbook}->[0]);

### line number handling for progress calclulation and for resuming aborted tasks

my $count = $lr->get_number_of_lines();
 
my $line = 0;

if(($mode eq 'check') and (-f ".current_line.$pbook")) {
    $line = `cat .current_line.$pbook`;
    chomp($line);
    if($line) {
	msg("skipping lines and start with line $line");
	$lr->skip_lines($line);
    }
}


# ------------------------------------------------------------------------------
# main loop
# ------------------------------------------------------------------------------
my $checks = 14;
my $debug_exit = 1;

# modes
my $correct_later = 1;
my $parse_only = 1;
my @lines_to_repair;

if($mode eq 'fixmelater') {
    $correct_later = 1;
    $parse_only = 1;
}
elsif($mode eq 'import') {
    $correct_later = 0;
    $parse_only = 0;
}
elsif($mode eq 'check') {
    $correct_later = 0;
    $parse_only = 1;
}
elsif($mode eq 'repair') {
    $correct_later = 0;
    $parse_only = 1;
    @lines_to_repair = split(/\n/, `grep fixlater .${pbook}.patch | cut -f 1 -d ';' | sort -n | uniq`);
    print Dumper(\@lines_to_repair);
    if(not @lines_to_repair) {
	msg("there is nothing to repair");
	exit;
    }
    my $to_line = shift @lines_to_repair;
    msg("skip [$to_line] lines");
    $lr->skip_lines($to_line);
    $line = $to_line;
}
else {
    die "unknown command";
}

my $start_time = time();
my $prev_version_bit = 0;
my $cont = ContinuationHandler->new(my $prev_version_bit) if(not $parse_only);

while(defined(my $raw_line = $lr->get_line()) and $debug_exit) {
    
    my $result = 0;
    $raw_line->{version} = 1 << $pbook_version{$pbook}->[1];

    my $recheck = 0;
    while($result != $checks) {
	$result  = basic_fix( $raw_line, \&remove_spaces, 'remove_spaces', $recheck, $line, $pbook);
	$result += basic_fix( $raw_line, \&expand_street_name, 'expand_street_name', $recheck, $line, $pbook, 'strasse');
	$result += basic_fix( $raw_line, \&cleanup_prefix, 'cleanup_prefix', $recheck, $line, $pbook, 'vorwahl'); # check prefix before number
	$result += basic_fix( $raw_line, \&cleanup_number, 'cleanup_number', $recheck, $line, $pbook, 'rufnummer');
	$result += basic_fix( $raw_line, \&check_number, 'check_number', $recheck, $line, $pbook, 'rufnummer');
	$result += basic_fix( $raw_line, \&check_constraints_number_length, 'check_constraints_number_length', $recheck, $line, $pbook, 'rufnummer');
	$result += basic_fix( $raw_line, \&cleanup_post_code, 'cleanup_post_code', $recheck, $line, $pbook, 'plz');
	$result += basic_fix( $raw_line, \&cleanup_city_name, 'cleanup_city_name', $recheck, $line, $pbook, 'ort');
	$result += basic_fix( $raw_line, \&convert_flag, 'convert_flag', $recheck, $line, $pbook, 'ort'); # convert before constraint-check on name
	$result += basic_fix( $raw_line, \&check_name_constraints, 'check_name_constraints', $recheck, $line, $pbook, 'ort');
	$result += basic_fix( $raw_line, \&cleanup_web, 'cleanup_web', $recheck, $line, $pbook, 'webadresse');
	$result += basic_fix( $raw_line, \&cleanup_email, 'cleanup_email', $recheck, $line, $pbook, 'email');
	$result += basic_fix( $raw_line, \&cleanup_lvw, 'cleanup_lvw', $recheck, $line, $pbook, 'lvw');
	$result += basic_fix( $raw_line, \&remove_spaces, 'cleanup_spaces', $recheck, $line, $pbook);

	if($result != $checks) {
	    msg("any checks failed for line $line, RECHECK ...");
	}
	$recheck++;
    }

    if($mode eq 'repair') {
	my $to_line = shift @lines_to_repair;
	if(not defined $to_line) {
	    msg("done");
	    exit;
	}
	msg("jump to line [$to_line]");
	$lr->skip_lines($to_line - $line - 1);
	$line = $to_line;
    }
    else {
	$debug_exit = $cont->handle($raw_line) if(not $parse_only);

	if($line % 10000 == 0) {
	    my $p = $line * 100 / $count;
	    if($p) {
		print "\r" . ( "=" x int(0.65 * $p) ) . 
		    sprintf("=> [%.2f%% %.2f h]", $p, 100 /$p * (time()-$start_time) /3600 );
		$cont->commit() if(not $parse_only);
	    }
	}

	$line++;
    }
}

msg("finished");
$cont->finished() if(not $parse_only);

sub msg {
    my $str = shift;
    my $tag = shift;

    if($log_msg{$tag} or not exists $log_msg{$tag}) {
	print "\r++ [".localtime(time())." line $line] $str\n";
    }
}

# ------------------------------------------------------------------------------
# Patchverwaltung
# ------------------------------------------------------------------------------

sub patch_available {
    my $ref = shift;
    my $file = '.' . shift() . '.patch';
    my $line = shift;
    my $test_case = shift;

    if(not open(FILE, "< $file")) {
	msg("no patch file '$file': $!");
	return 0;
    }

    while(defined(my $l = <FILE>)) {
	chomp $l;

	if($l =~ m!^$line\;action=ignore;test=$test_case!) {
	    msg("have to ignore line $line with $test_case");
	    close FILE;
	    return 1;
	}
	elsif($l =~ m!^${line}\;action=replace;test=$test_case;(.*)!) {
	    my $subs = $1;
	    foreach my $str (split /\;/, $subs) {
		if($str =~ m!^([a-z]+)=(.*)!) {
		    $ref->{$1} = $2;
		}
	    }
	    close FILE;
	    return 1;
	}
	elsif(($mode ne 'repair') and ($l =~ m!^$line\;action=fixlater;test=$test_case!)) {
	    msg("have to ignore line $line with $test_case");
	    close FILE;
	    return 1;
	}
    }
    
    close FILE;
    msg("no patch for line $line / $test_case in $file available");
    return 0;
}

sub store_patch {
    my $ref = shift;
    my $file = '.' . shift() . '.patch';
    my $line = shift;
    my $test_case = shift;
    my $action = shift;
    my $substitution = shift;

    open(FILE, ">> $file") or die "can't open patch file '$file': $!\n";
    if($action eq 'ignore') {
	print FILE "$line;action=$action;test=$test_case\n";
    }
    elsif($action eq 'fixlater') {
	print FILE "$line;action=$action;test=$test_case\n";
    }
    elsif($action eq 'replace') {
	print FILE "$line;action=$action;test=$test_case;$substitution\n";
    }
    close FILE;
}

sub basic_fix {
    my $record = shift;
    my $func = shift;
    my $func_name = shift;
    my $recheck = shift;
    my $line = shift;
    my $pbook = shift;
    my $main_key = shift;  # Schluessel, der hauptsaechlich ueberprueft wird


    my $backup_value = $record->{$main_key};

    if(not &{$func}($record)) {

	my $answer;
	if(not patch_available($record, $pbook, $line, $func_name)) {

	    msg("\a\a\abasic fix failed in line $line when applying $func_name()");
	    msg(Dumper($record));
	    msg("Maybe problem with $main_key=[$record->{$main_key}], was [$backup_value] before transformation"); 

	    if($correct_later) {
		msg("ignore problem for now");
		store_patch($record, $pbook, $line, $func_name, 'fixlater');
	    }
	    else {
		msg("[i]gnore now, [a]lways ignore, [u]ndefine $main_key, [c]ancel, [l]ater or key=value[;key2=...] ?\n");
		print ">> ";
		$answer = <STDIN>;
		chomp($answer);

		if($answer eq '') {
		    return 0; # -> Versehentlich Enter gedrueckt?
		}
		elsif(lc($answer) eq 'i') {
		    msg("ignoring line $line");
		}
		elsif(lc($answer) eq 'l') {
		    msg("correct line $line later");
		    $correct_later = 1;
		    store_patch($record, $pbook, $line, $func_name, 'fixlater');
		}
		elsif(lc($answer) eq 'a') {
		    msg("always ignore line $line");
		    store_patch($record, $pbook, $line, $func_name, 'ignore');
		}
		elsif(lc($answer) eq 'u') {
		    msg("Loesche $main_key in line $line");
		    $record->{$main_key} = undef;
		    store_patch($record, $pbook, $line, $func_name, 'replace', $main_key .'=');
		    return 0;
		}
		elsif((lc($answer) eq 'c') or (lc($answer) eq 'x')) {
		    # Es gibt offensichtlich ein Problem. Wir speichern mal die aktuelle Zeilennummer weg,
		    # falls wir an der selben Stelle weitermachen wollen.
		    
		    open(CURRLINE, "> .current_line.$pbook") or die "can't open '.current_line.$pbook': $!\n";
		    print CURRLINE $line;
		    close(CURRLINE);
		    exit;
		}
		elsif($answer =~ m!^[a-z]+=.*$!i) {
		    msg("save new values for line  $line");
		    store_patch($record, $pbook, $line, $func_name, 'replace', $answer);
		    
		    return 0; # -> retest
		}
		else {
		    return 0;
		}
	    }

	}
	else {
	    msg("basic fix failed in line $line when applying $func_name(), but there is a patch. Record for check=$recheck is now " . Dumper($record));
	    return ($recheck < 2) ? 0 : 1;
	}
	
    }
    
    return 1;
}

# ------------------------------------------------------------------------------
# Pruef- und Reperaturfunktionen
# ------------------------------------------------------------------------------


sub remove_spaces {
    my $ref = shift;

    foreach my $k (keys %$ref) {
	$ref->{$k} =~ s!^ +!!;
	$ref->{$k} =~ s! +$!!;
	$ref->{$k} =~ s![\t\s]+! !g;
    }

    return 1;
}

# e.: was bedeutet nochmal flag = 0..3?
# <e.> nitram: welche Ausgabe?
# alle?
# gibt es da unterschiede?
# <e.> bisher nur 1,2 oder 3 fuer Privat, Gewerblich und Continuation, jetzt
# <e.> 0x80 - gewerblich
# <e.> 0x40 - Hat der Inersesuche nicht widersprochen
# <e.> 0x10 - Beinhaltet eine URL oder Mailadresse
# <e.> 0x00 - einzeilig, 0x01 mehrzeilig - start, 0x02 mehrzeilig - weiter
# ich meinte flag & 0xf = 0..3
# <e.> nitram: ja, die Flags unterschieden sich
# <e.> nitram: Aenderungen Herbst 2003 zu Fruehjahr 2004
# e.: d.h. wenn flag einstellig, dann 1,2 oder 3 fuer Privat, Gewerblich und Continuation, sonst wie genannt
# <e.> nitram: ab Fruehjahr gabs die neuen Flags
# <e.> nitram: vorher warn die Flags als Zahl vor den Nachnamen geklatscht
# <e.> nitram: Da stand dann immer 1M?ller
# <e.> nitram: das habbick schon gesplittet

sub convert_flag {
    my $ref = shift;
    $ref->{oflags} = int hex $ref->{flags};
    if($ref->{version} > 10) {
	$ref->{flags} = int(hex($ref->{flags}));
	$ref->{is_corporation} = int($ref->{flags} & 128) ? 1 : 0;
	$ref->{inverse_allowed} = int($ref->{flags} & 64) ? 1 : 0;
	$ref->{cont} = int($ref->{flags} & 0xf) ? 1 : 0;
	$ref->{cont_start} = int($ref->{flags} & 0xf) <= 1 ? 1 : 0
    }
    else {
	#$ref->{is_corporation} = $ref->{flags} == 1 ? 1 : 0;
	$ref->{cont_start} = ($ref->{flags} == 3 || $ref->{flags} == 1) ? 1 : 0;
	$ref->{cont} = $ref->{flags} == 2 ? 1 : 0;
    }
    
    return 1;
}


#
# 0 - einzeleintrag
# 1 - begin einer cont
# 2 - ein folgeeintrag

sub check_name_constraints {
    my $ref = shift;

    if(not defined($ref->{vorname}) and not defined($ref->{nachname}) and ($ref->{flag} & 0xf > 2) ) {
	return 0;
    }
    
    return 1;
}

sub expand_street_name {
    my $ref = shift;

    if($ref->{strasse} eq '') {
	return 1;
    }

    # Ein '..' am Ende kann man gefahrlos durch den einzlnen Punkt ersetzen.
    # Das machen wir gleich am anfang, damit moeglichst viele darauffolgende Regeln
    # matchen.
    $ref->{strasse} =~ s!\.\.$!\.!;

    # Abkuerzungen, die expandiert werden sollen, sofern sie am Ende stehen.
    # Das Substituieren mittendrin kann schiefgehen, also lassen wir das besser


    ### Strasse

    if($ref->{strasse} =~ s!([Ss])tr\.$!"${1}tra\xdfe"!ie) {
	return 1;
    }
    if($ref->{strasse} =~ s!([a-z])\-$!"${1}stra\xdfe"!e) {
	return 1;
    }
    if($ref->{strasse} =~ s![\w]\-$!"${1}stra\xdfe"!e) {
	return 1;
    }
    if($ref->{strasse} =~ s!\-$!"Stra\xdfe"!e) {
	return 1;
    }

    ### Siedlung
    
    elsif($ref->{strasse} =~ s!Sdlg\.$!Siedlung!) {
	return 1;
    }
    
    elsif($ref->{strasse} =~ s!([Ss])iedl\.$!"${1}iedlung"!e) {
	return 1;
    }
	  
    ### Bahnhof

    elsif($ref->{strasse} =~ s!bahnh\.$!bahnhof!) {
	return 1;
    }
    elsif($ref->{strasse} =~ s!bhf\.$!bahnhof!) {
	return 1;
    }
    elsif($ref->{strasse} =~ s!([Bb])ahnhofst\.$!"${1}ahnhofstra\xdfe"!e) {
	return 1;
    }

    ### Platz

    elsif($ref->{strasse} =~ s!([Pp])lz?\.$!"${1}latz"!e) {
	return 1;
    }

    ### Chaussee, wenn eigenes Wort

    elsif($ref->{strasse} =~ s! Ch\.$! Chaussee!) {
	return 1;
    }
	  
    # Manchmal steht hinter Strassennamen versehentlich ein Punkt, ohne das
    # der Str.namen expandiert werden soll. Hier ist eine Whitelist, wo
    # das dann ok ist, wenn man den Punkt entfernt.
    # Man kann den Punkt nicht immer entfernen. Und zwar dann, wenn es sich 
    # tatsaechlich um eine Abkuerzung handelt, z.B. '...tierp.' fuer Tierpark.
    #
    # 'ch.' fuer Chaussee etc. sollte nicht unbedingt explandiert werden, denn
    # es gibt eine Reihe von Worten, die auch auf 'ch' enden, z.B. Teich.
    # Gleiches gilt fuer '...al' (Allee). Vorsicht mit 'thal' und 'th?al?. Dahinter koennte sich eine
    # Allee verbergen.
    # Wenn man das wirklich expanden will, sollte man das nicht mitten im Wort versuchen.

    # XXX -> Ins Webinterface sollte der Hinweis, dass man Strings, die man ueblicherweise auch abkuerzt,
    # nicht fuer die suche benutzt (z.B. 'w.' fuer '...weg', 'Johann-v.-Neumann-Str.', ...).

    if(($ref->{strasse} =~ m!(weg|wegen|busch|wasser|steig|stiege|moor|moos|felde?|wehl|bett|teich|bruch|deich|diek|dieken|esch|ecke?|
			      egge|kalk|spitze|boden|reihe|ende|forst|torf|brand|
			      strand|kathen|hagen|haag|sohl|stock|breite|bach|bree?de|stieg|steig|
			      burg|berge?|bergen|barg|grunde?|brink|rau|leuchte|hof|heide|strat|straa[td]|platz|hecke|Allee|
			      werk|gebiet|Neistigh|b\xfcll|S\xfcd|ost|west|nord|hain|damm?|hoog|kamp|k[a\xe4]mpen?|lid|
			      tannen|stein|m\xfchle|ring|turm|brunnen|b\xfchl|buckel|
			      hafen|ac?ker|wiete|wieke|bee?k|redder|bau|furth?|wurth|koppel|krug|walde?|bad|kjer|mus|stee?g|
			      reeg|sande?|warft?|wai|stadt|stedt|ort|dorf|born|weiler|keller|holz|lohe|
			      center|chaussee|see|linge|wisch|aue|bahn|wall|siedlung|g[a\xe4]rten|winkel|birken?|eichen?|linden?|
			      strang|hausen|haus|h\xe4usern?|riethe|markt?|riede?|kolonie|worth|revier|lande?|anger|ritt|
			      weiher|lingen|hang|gasse|thal|grube|graben|furche|h\xf6he?|h\xfcfe|stumpf|rain|gang|schaft|schacht|
			      kuhlen?|kirche|kippel|schlade|lage|kiel|beeke|passage|schlag|sch\xfctt|
			      wehr|sicht|hub|zentrum|wiese?|seite|weide|blick|hang|holder|mauer|st\xfcck|pfad|pforte|halde|hude|
			      tor|br\xfccke|heim|park|h\xfctte|chen)\.$!ix)) {

	$ref->{strasse} =~ s!\.$!!;
	return 1;
    }

    # Einfach ignorieren
    elsif($ref->{strasse} =~ m!(liegend|geb|anl|parz)\.$!i) {
	return 1;
    }
    # Sollte sich irgendwo ein Punkt befinden, dann lieber mal
    # msggen, damit man draufkucken kann.
    
#    elsif($ref->{strasse} =~ m!\.$!) {
#	print "[$ref->{strasse}]\n";
#	return 1;
#    }

    return 1;

}



#
# kann zusaetzliche Keys erzeugen:
# - fax_equals_fon
# - is_fax

sub cleanup_number {
    my $ref = shift;

    if($ref->{rufnummer} eq '') {
	return 1;
    }

    # Erstmal sinnlose lange Zeichenketten entfernen

    $ref->{rufnummer} =~ s!(Schreib|Bild|M\xfcnz|C)-?Tel!!i;
    $ref->{rufnummer} =~ s!^(T\-Netv\.Ort|Info\-?Box|Mailbox|Data\s*ISDN|ISDN-?Leonardo|VoIP|ISDN|T\-?View|T\-?Net\-?Box|Video|Modem|eurofile|DF.|City|E\-?Plus|Scall|Quix|Skyper|City\-?Ruf|Tfx\s*D1C\-?)\s*!!i;


    my @stop_words = grep {$_ ne ''} sort {length($b) <=> length($a) }  
    qw( 
	D\"C-Tel
	D1
	D1C\-Telt
	D1DC\-Tel
	D1Du
	D1F
	D1FDu
	D1Fu
	D1Fz
	D1u
	D2
	D2[\-\s]C-Tel
	D2\-Nr
	D2\-Nrs
	D22C-Tel
	D2DN
	D2Du
	D2F
	D2FDu
	D2Fe
	D2Fi
	D2Fz
	D2u
	D3C\-Tel
	DC\-Tel
	DD2\-Nr
	DF2C\-Tel
	DeC\-Tel
	Desloch
	DiC\-Tel
	Dia
	E
	E\-PLUS
	E\-
	Fu
	IDN
	IDSDN
	IDSN
	ISDB
	ISDDN
	ISDEN
	ISDM
	ISDSN
	ISN
	ISND
	ISSDN
	Kfz
	Tfz
	Telmi
	TfxN
	Tfk
	Q
	x
	01u
	
	[^A-Za-z\d]b
	);


    my $xxx = match_longest_prefix($ref->{rufnummer}, \@stop_words, 1);
    $ref->{rufnummer} =~ s!^$xxx\s*!!gi;


    # Sinnlose Zeichen entfernen. Da '-' in einigen Worten wie 'e-plus', ... vorkommt,
    # scheiden wir das wirklich ganz zum Schluss erst raus.

    $ref->{rufnummer} =~ s![\,\+\.\(\)]!!g;

    $ref->{rufnummer} =~ s![\?]$!!g;

    if(($ref->{vorwahl} ne '') and ($ref->{rufnummer} ne '')) {
	$ref->{is_phone} = 1;
    }

    # Der Sonderfall, dass eine Faxweiche gibt
    if($ref->{rufnummer} =~ s!^(fax\s*\&\s*fon|Tel\s*\/\s*Fax)\s*!!i) {
	$ref->{fax_equals_fon} = 1;
	$ref->{is_fax} = 1;
    }

    # Faxnummern sind i.d.R. als solche markiert. Damit der Bereinigungsprozess
    # ohne Unterscheidung von Tel/Fax weiterlaufen kann, schneiden wir nur
    # das Wort Fax heraus. Und lassen den Bereinigungsprozess weiterlaufen
    if($ref->{rufnummer} =~ m!^(Tele)?Fax\s*!i) {
	$ref->{is_phone} = 0;
	$ref->{is_fax} = 1;
	$ref->{rufnummer} =~ s!^(Tele)?Fax\s*(Europa|Intern|D1Fu|D2\-?Nr|EPlus)?\s*!!i;
    }


    # An dieser Stelle mal die Spaces rausschneiden.

    $ref->{rufnummer} =~ s!\s!!g;

    # Hier koennen wir die '-' u '/'-Zeichen entfernen
    $ref->{rufnummer} =~ s![\-/]!!g;


    # Bevor Vanitynummern aufgeloest werden, sollten wir wirklich alle sonstigen
    # alphanummerischen Zeichen behandelt haben.

    # Merkmale von Vanitynummern:
    # - die Vorwahl ist eigentlich immer leer
    # - vor der Vanitynr. ist eigentlich immer eine Service- oder Mobil-Prefix

    if(($ref->{vorwahl} eq '') and ($ref->{rufnummer} =~ m!^00[78]00\d*[a-z]!i)) {
	msg("Ganz sicher eine Vanity-Nr. [$ref->{rufnummer}] mit fehlerhaftem Prefix. Repariere.") if($log_msg{display_vanity_numbers});;
	$ref->{rufnummer} =~ s!^0!!;
    }

    if(($ref->{vorwahl} eq '') and ($ref->{rufnummer} =~ m!^0[^0]\d*[a-z]!i)) {
	msg("ganz sicher eine Vanity-Nr. [$ref->{vorwahl}][$ref->{rufnummer}]") if($log_msg{display_vanity_numbers});
	cleanup_vanity_number($ref);
    }
    elsif((exists($service_prefix{$ref->{vorwahl}})) and ($ref->{rufnummer} =~ m![a-z]!i)) {
	msg("ganz sicher eine Vanity-Nr. [$ref->{vorwahl}][$ref->{rufnummer}]") if($log_msg{display_vanity_numbers});
	cleanup_vanity_number($ref);
    }
    elsif($ref->{rufnummer} =~ m!^\d+([a-z][a-z]?)$!i) {
	msg("Hoechstwahrscheinlich keine Vanity-Nr! [$ref->{vorwahl}][$ref->{rufnummer}]. Entferne letzte(s) Zeichen am Ende.") 
	    if($log_msg{display_uncertain_vanity_numbers});;
	$ref->{rufnummer} =~ s!$1$!!;
    }
    elsif((length($ref->{rufnummer})>10) and ($ref->{rufnummer} =~ m![a-z]!i)) {
	msg("Vanity? Hoechstwahrscheinlich ein Fehler, weil Nummer zu lang. [$ref->{vorwahl}][$ref->{rufnummer}]") 
	    if($log_msg{display_uncertain_vanity_numbers});;
	return 0;
    }
    elsif($ref->{rufnummer} =~ m![a-z]!i) {
	msg("Vanity? [$ref->{vorwahl}][$ref->{rufnummer}]") if($log_msg{display_uncertain_vanity_numbers});;
	#cleanup_vanity_number($ref)
	return 0;
    }


    if($ref->{rufnummer} eq '0') {
	msg("Rufnummer ist exakt '0'. Entferne Rufnummer.", 'cleanup_number');
	$ref->{rufnummer} = undef;
    }
    
    return 1;

}

sub check_constraints_number_length {
    my $ref = shift;

    # Check auf Laenge fuer 0700-Nummern. Die muessen eigentlich 8 Stellen haben. Es kan aber auch sein,
    # dass Leute die mit einer Durchwahl angeben.

    if(($ref->{vorwahl} eq '0700') and (length($ref->{rufnummer}) < 7) and (length($ref->{rufnummer}) >= 9)) {
	msg("0700er Nummern koennen eigentlich nicht weniger als 8 Stellen haben.", 'cleanup_number');
	return 1;
    }

    # Abbrechen, wenn die Rufnummer sehr lang ist
    if(length($ref->{rufnummer}) > 13) {
	msg("Rufnummer vielleicht zu lang?", 'cleanup_number');
	return 1;
    }

    #
    # Wenn jetzt noch irgendwas unklar ist, dann lieber mal abbrechen.
    #

    if($ref->{rufnummer} =~ m![^\w]!) {
	return 0;
    }

    return 1;
}


#
# Diese Funktion ist, zugegeben, etwas sehr laenglich und damit schwer zu ueberblicken.
# Wir untersuchen den Zusammenhang zw. Vorwahl und Rufnummer und unterscheiden dabei
# anhand der Beispiele gegeben:
#
# Vorwahl | Rufnummer
#
#         | 0800 123456
#         | 0177 123456
#         | 0045 77 123456
#         | 
#


sub check_number {
    my $ref = shift;

    # Bedingungen

    my $prefix_empty              = ($ref->{vorwahl} eq '') ? 1 : 0;
    my $prefix_is_mobile_pref     = exists( $mobile_prefix{$ref->{vorwahl}});
    my $prefix_is_service_pref    = exists($service_prefix{$ref->{vorwahl}});

    my $number_starts_with_0      = ($ref->{rufnummer} =~ m!^0!) ? 1 : 0;
    my $number_has_service_prefix = match_longest_prefix($ref->{rufnummer}, \@service_prefix);
    my $number_has_mobile_prefix  = match_longest_prefix($ref->{rufnummer}, \@mobile_prefix);

    #
    # Keine Vorwahl vorhanden, alle relevanten Informationen muessen im Nummernteil stecken
    #
    if($prefix_empty) {

	#
	# Servicegassen: 0800 ...
	#
	if(length $number_has_service_prefix) {
	    msg("Leere Vorwahl, Rufnummer hat Service-Prefix [$number_has_service_prefix]. Repariere [$ref->{rufnummer}].", 'prefix_in_number');
	    $ref->{vorwahl} = $number_has_service_prefix;
	    $ref->{rufnummer} =~ s!^$number_has_service_prefix!!;
	}
	#
	# Mobilfunkgassen: ...
	#
	elsif(length $number_has_mobile_prefix) {
	    msg("Leere Vorwahl, Rufnummer hat Mobil-Prefix [$number_has_mobile_prefix]. Repariere [$ref->{rufnummer}].", 'prefix_in_number');
	    $ref->{vorwahl} = $number_has_mobile_prefix;
	    $ref->{rufnummer} =~ s!^$number_has_mobile_prefix!!;
	}
	#
	# Laendervorwahl
	#
	elsif($ref->{rufnummer} =~ m!^00!) {
	    msg("Landesvorwahl?", 'check_number');
	    return 0;
	}

	#
	# Normale Ortskennzahl
	#
	elsif($number_starts_with_0) {
	    # hoechstwahrscheinlich eine Ortsvorwahl oder ein Fuckup
	    msg("Rufnummer ohne Vorwahl. Split.", 'check_number');

	    my $new_pref_number = split_prefix_from_number($ref->{vorwahl} . $ref->{rufnummer});
	    if(ref $new_pref_number) {
		$ref->{vorwahl} = $new_pref_number->[0];
		$ref->{rufnummer} = $new_pref_number->[1];
		return 1;
	    }
	    msg("Split nicht erfolgreich.");
	    return 0;
	}
    }
    #
    # Als Vorwahl ist eine Mobilfunkgasse angegeben
    #
    elsif(length $prefix_is_mobile_pref) {

	#
	#
	#
	if(length $number_has_mobile_prefix) {
	    msg("Vorwahl [$ref->{vorwahl}] ist Mobilprefix und Rufnummer [$ref->{rufnummer}] hat Mobilprefix.", 'check_number');
	    return 0;
	}
	elsif($number_starts_with_0) {
	    msg("Vorwahl [$ref->{vorwahl}] ist Mobilprefix und Rufnummer [$ref->{rufnummer}] beginnt mit 0. Ignorieren.", 'check_number');
	}
    }
    #
    # Vorwahl ist eine Servicegasse
    #
    elsif(length $prefix_is_service_pref) {

	if($number_has_service_prefix) {
	    msg("Vorwahl [$ref->{vorwahl}] ist Serviceprefix und Rufnummer [$ref->{rufnummer}] hat Serviceprefix, Ignorieren.", 
		'check_number');
	}

    }
    #
    # landesvorwahl
    #
    elsif($ref->{rufnummer} =~ m!^00(\d\d)$!) {
	my $lvw = $1;
	msg("Rufnummer ist [$ref->{vorwahl}][$ref->{rufnummer}]. Das ist wohl eine Landesvorwahl. Entferne Vorwahl. Uebernehme LVw als eigenes Feld.", 'check_number');
	$ref->{lvw} = '00' . $lvw;
	$ref->{rufnummer} =~ s!^00$lvw!!;
	$ref->{vorwahl} = undef;
	return 0;
    }

    #
    # Normale Ortskennung als Vorwahl vorhanden
    #
    else { #normale ortsk

	if($ref->{rufnummer} =~ m!^\(?$ref->{vorwahl}\)?!) {  # Vorwahl ist nicht leer
	    msg("Ortsrufnummer [$ref->{vorwahl}][$ref->{rufnummer}] beinhaltet Vorwahl auch im Rufnr.teil. Entferne Vorwahl.", 'check_number');
	    $ref->{rufnummer} =~ s!^\(?$ref->{vorwahl}\)?!!;

	    $number_starts_with_0 = ($ref->{rufnummer} =~ m!^0!) ? 1 : 0; # recheck
	}


	if(not exists $area_code_directory{$ref->{vorwahl}}) {
	    msg("UNBEKANNTE VORWAHL [$ref->{vorwahl}], BEHANDLE WIE BEI KOLLISIONEN.", 'check_number');
	    $number_starts_with_0 = 1;
	}


	if($number_starts_with_0) { # nummer beginnt mit 0

	    msg("Vorwahl [$ref->{vorwahl}] vorhanden. Rufnummer [$ref->{rufnummer}] beginnt mit 0.", 'check_number');

	    if($number_has_service_prefix) {
		$ref->{vorwahl} = $number_has_service_prefix;
		$ref->{rufnummer} =~ s!^$number_has_service_prefix!!;
		msg("Rufnummernteil ist Servicenummer und passt nicht zur Vorwahl -> Repariere -> [$ref->{vorwahl}][$ref->{rufnummer}] ",
		    'check_number');
	    }
	    elsif($number_has_mobile_prefix) {
		$ref->{vorwahl} = $number_has_mobile_prefix;
		$ref->{rufnummer} =~ s!^$number_has_mobile_prefix!!;
		msg("Rufnummernteil ist Mobilfunknummer und passt nicht zur Vorwahl-> Repariere -> [$ref->{vorwahl}][$ref->{rufnummer}] ", 
		    'check_number');
	    }
	    else {
		msg("------------------------------------------------------------------");
		msg("Vorwahlkollision. Vermeintl. Ortsvw. [$ref->{vorwahl}] als Vorwahl vorhanden und Rufnummer [".
		    $ref->{rufnummer} . "] hat vermeintl. Ortsvorwahl." . Dumper($ref), 'check_number');

		my $acode = match_longest_prefix($ref->{rufnummer}, \@area_code_list);
		my $new_pref_number = split_prefix_from_number($ref->{vorwahl} . $ref->{rufnummer});

		my $solutions = 0;

		if(exists $area_code_directory{$ref->{vorwahl}}) {
		    msg("+ Vorhandene Vorwahl [$ref->{vorwahl}] gilt fuer Orte: " . join(', ', @{$area_code_directory{$ref->{vorwahl}}} ), 'check_number');
		    $solutions+=1;
		}
		else {
		    msg("- Vorhandene Vorwahl [$ref->{vorwahl}] existiert NICHT im VwV", 'check_number');
		}

		if($acode ne '') {
		    msg("+ Rufnummernteil beinhaltet Vorwahl [$acode] fuer Orte: ". join(', ', @{$area_code_directory{$acode}}), 'check_number'); # ref != 0 !!!
		    $solutions+=1;
		}
		else {
		    msg("- Rufnummernteil beinhaltet KEINE im VwV auffindbare Vorwahl.", 'check_number');
		}

		my $extract_from_number = 0;
		if(ref $new_pref_number) {
		    msg("+ Komplette Rufnummer laesst sich nach [" . $new_pref_number->[0] . "][" . $new_pref_number->[1] . 
			"] aufteilen. Orte: ". join(', ', @{$area_code_directory{$new_pref_number->[0]}} ), 'check_number');
		    $solutions+=1;
		
		}
		else {
		    msg("- Rufnummer laesst sich NICHT in Vorwahl/Rufnummer aufteilen.", 'check_number');
		}

		if($solutions == 0) {
		    msg("Es gibt keine Aufloesung des Konfliktes", 'check_number');
		    return 1; #### XXXX war 0
		}
		elsif($solutions > 2) {
		    msg("Loesung nicht eindeutig", 'check_number');
		    
		    if(ref $new_pref_number and (length($ref->{rufnummer}) - length($new_pref_number->[0]) >= 4) ) {
			msg("Rufnummer minus eingebautes Prefix recht lang. Das ist wahrscheinlich die Loesung.", 'check_number');
			$extract_from_number = 1;
		    }
		    else {
			msg("Rufnummer minus eingebautes Prefix zu kurz, als dass eingebautes prefix als Vorwahl gelten koennte", 'check_number');
			return 1; # XXXX war 0
		    }
		}

		msg("Ein oder zwei Loesung vorhanden.", 'check_number');
		
		if(ref $new_pref_number and ($new_pref_number->[0] eq $ref->{vorwahl}) and ($acode ne '') and !$extract_from_number) {
		    msg("Loesung entspricht bestehender Situation. Also doch nur eine Loesung. Weiter.", 'check_number');
		    return 1;
		}
		elsif(ref $new_pref_number and !$extract_from_number) {
		    msg("Uebernehme Ort/Vorwahl/Nummer aus konkatenierter Rufnummer. Entspricht moeglicherweise bestehender Loesung.", 'check_number');
		    $ref->{vorwahl} = $new_pref_number->[0];
		    $ref->{rufnummer} = $new_pref_number->[1];
		    $ref->{ort} = undef;

		    my $loc_name = $area_code_directory{$ref->{vorwahl}};
		    if($#$loc_name == 1) {
			msg("Originaleintrag hat Ort [$ref->{ort}]". 
			    Dumper($ref), 'check_number');
			
			$ref->{ort} = $loc_name->[0];
			msg("Uebernehme [$loc_name->[0]].", 'check_number');
		    }
		}
		elsif($acode ne '') {
		    msg("Die Rufnummer [$ref->{rufnummer}] hat das valide Prefix [$acode]. Extrahiere [$acode].", 'check_number');
		    
		    $ref->{rufnummer} =~ s!^$acode!!;
		    $ref->{vorwahl} = $acode;
		    $ref->{ort} = undef;

		    my $loc_name = $area_code_directory{$acode};
		    
		    if($#$loc_name == 1) {
			msg("Originaleintrag hat Ort [$ref->{ort}]". 
			    Dumper($ref), 'check_number');
			
			$ref->{ort} = $loc_name->[0];
			msg("Uebernehme [$loc_name->[0]].", 'check_number');
		    }
		}

		elsif(exists $area_code_directory{$ref->{vorwahl}}) {
		    msg("Die Vorwahl [$ref->{vorwahl}] hat das valide Prefix. Die Rufnummer beginnt aber trotzdem mit 0.", 'check_number');
		    msg("Konflikt kann nur manuell geloest werden", 'check_number');
		    return 1; # xxxx war 0
		    
		}
		else {
		    return 0;
		}

	    }

	} # end of number starts with 0

    } # end of real location prefix
    
    return 1;
}

sub match_longest_prefix {
    my $number = shift;
    my $prefix_list = shift;
    my $ignore_check = shift;

    return undef if(!$ignore_check and $number =~ m!^[^0]!); # Ruecksprung, wenn Nummer nicht mit 0 beginnt

    foreach my $pref (@$prefix_list) {
#	print "match [$pref] against [$number]\n";
	if($number =~ m!^$pref\s*!i) {
	    return $pref;
	}
    }
    return undef;
}

sub cleanup_prefix {
    my $ref = shift;

    $ref->{vorwahl} =~ s!^\+!!;
    $ref->{vorwahl} =~ s![\+\/]$!!;

    if($ref->{vorwahl} =~ s! !!g) {
	msg("Vorwahl enthaelt Leerzeichen. Entferne Leerzeichen.", 'cleanup_prefix');
    }

    if($ref->{vorwahl} =~ m!^0[\,\+xt](0[^\0][^\0][^\0])$!) {
	$ref->{vorwahl} = $1;
	msg("Vorwahl matched auf '0,0xxx'. Bereinige Vorwahl.", 'cleanup_prefix');
    }

    ## Service-Nummern mit einer 0 zuviel
    if($ref->{vorwahl} =~ m!^00([87])00$!) {
	$ref->{vorwahl} = "0${1}00";
    }

    if($ref->{vorwahl} =~ m!^00(\d\d)$!) {
	$ref->{lvw} = $1;
	msg("Extrahiere LVw. [$1] aus Vorwahl [$ref->{vorwahl}]");
	$ref->{vorwahl} = undef;
    }

    my $service_pref = match_longest_prefix($ref->{vorwahl}, \@service_prefix);
    my $mobile_pref = match_longest_prefix($ref->{vorwahl}, \@mobile_prefix);

    if($ref->{vorwahl} eq '') {
	return 1;
    }
    elsif($ref->{vorwahl} eq '0c') {
	$ref->{vorwahl} = undef;
	return 1;
    }

    #
    # Serviceprefix mit Tarifkennziffer
    #
    elsif($service_pref ne '') {
	if($ref->{vorwahl} =~ m!^$service_pref(\d+)$!) {
	    my $suffix = $1;
	    
	    msg("Vorwahl beinhaltet ein Servicenummernprefix [$service_pref][$suffix]. Fuege Tarifierungsziffer ".
		"[$suffix] vor Rufnummer ein.") if($log_msg{service_prefix_with_tariff});
	    $ref->{rufnummer} = $ref->{rufnummer} . $suffix;
	    $ref->{vorwahl} =~ s!$suffix$!!;
	}
	
    }
    #
    # Mobilf mit Tarifkennziffer
    #
    elsif($mobile_pref ne '') {
	if($ref->{vorwahl} =~ m!^$mobile_pref(\d+)$!) {
	    my $suffix = $1;
	    
	    msg("Vorwahl beinhaltet ein Mobilfunknummernprefix [$mobile_pref][$suffix]. Fuege Tarifierungsziffer ".
		"[$suffix] vor Rufnummer ein.") if($log_msg{service_prefix_with_tariff});
	    $ref->{rufnummer} = $ref->{rufnummer} . $suffix;
	    $ref->{vorwahl} =~ s!$suffix$!!;
	}
	
    }

#    elsif(length($ref->{vorwahl}) > 6) {
#	msg("Vorwahl [$ref->{vorwahl}] ist zu lang. Max. fuenf geltende Ziffern nach der verkehrsausscheidungsziffer.", 'cleanup_prefix');
#	return 0;
#    }
    elsif($ref->{vorwahl} =~ m![^\d]!) {
	return 0;
    }

    return 1;
}

sub split_prefix_from_number {
    my $number_with_pref = shift;

    my $mobile_pref = match_longest_prefix($number_with_pref, \@mobile_prefix);
    my $service_pref = match_longest_prefix($number_with_pref, \@service_prefix);

    if(($mobile_pref eq '') and ($service_pref eq '')) {
	# also eine Ortsnummer
	# YYY
	for(my $i= length($number_with_pref); $i >= 3; $i--) {
	    my $p = substr($number_with_pref, 0, $i);
	    
	    if(exists $area_code_directory{$p}) {
		msg("Zur Vorwahl [$p] gibt es Eintraeg(e) im VwV");
		return [$p, substr($number_with_pref, $i)];
	    }
	    
	}
	
    }
    
    return undef;
   
}

sub cleanup_vanity_number {
    my $ref = shift;

    $ref->{rufnummer} = uc $ref->{rufnummer}; # to upper-case
    $ref->{rufnummer} =~ tr!A-Z!22233344455566677778889999!;

    return 1;
}

sub cleanup_city_name {
    my $ref = shift;


    if($ref->{ort} eq '') {
	return 1;
    }

    # Sternchen (evtl. mit Spaces) am Ende entfernen
    $ref->{ort} =~ s!\s*\*$!!;

    # Muell entfernen:
    # Die eckigen Klammern kommen eigentlich ausschliesslich im Ortsnamen vor,
    # wenn da auch noch eine PLZ kodiert ist.
    # Keine runden Klammern entfernen, weil 'Berlin (Spree)' o.ae. durchaus gewohenlich ist

    $ref->{ort} =~ s![\[\]]!!g;

    #
    # Zahlen im Ortsnamen kommen eigentlich nicht vor, aber ...
    #

    # ... wenn Ortsname mit PLZ (evtl. mit Punkten) beginnt und keine PLZ dann
    # bereinigen, und trotzdem weitere Checks durchfuehren

    if($ref->{ort} =~ m!^([\d\.][\d\.][\d\.][\d\.][\d\.])!) {
	my $plz = $1;

	msg("Ortsname enthaelt PLZ, repariere ... [$ref->{ort}]") if($log_msg{zip_code_in_city});
	$ref->{ort} =~ s!^[\d\.][\d\.][\d\.][\d\.][\d\.]\s*!!;

	if(not defined $ref->{plz}) {
	    $ref->{plz} = $plz;
	}
	else {
	    msg("PLZ ist als [$ref->{plz}] angegeben und eine PLZ im Ortsnamen. Einfach PLZ aus Ortsname entfernen.", 'cleanup_city_name');
	    # falls die PLZ im Record genauer ist, egal ...
	}
    }
    elsif($ref->{ort} =~ m!^[\d\.]+$!) {
	$ref->{ort} = undef;
    }

    # Einzelne Ziffer am Ende ist ok
    if($ref->{ort} =~ m![^\d]\d$!) {
	return 1;
    }

    # sollten noch Zahlen vorkommen, dann Fehler propagieren
    if($ref->{ort} =~ m!\d!) {

	# XXXXX nur fuer Herbst 1998:
#	if($pbook eq '2005_Herbst') {
#	    $ref->{ort} = undef;
#	    return 1;
#	}
	return 0;
    }

    return 1;
}

sub cleanup_post_code {
    my $ref = shift;

    # wohldefinierte PLZ (meint auch PLZs mit Punkten)
    if($ref->{plz} =~ m!^[\d\.][\d\.][\d\.][\d\.][\d\.]$!) {
	return 1;
    }
    # fast wohldefinierte PLZ (meint auch PLZs mit Punkten)
    elsif($ref->{plz} =~ m!^([\d\.][\d\.][\d\.][\d\.][\d\.])[\-\*]+$!) {
	$ref->{plz} = $1;
	return 1;
    }

    # PLZ ist versehentlich ein Ort und Ort ist nicht angegeben -> ort reparieren

#    elsif((not defined $ref->{ort}) and ($ref->{plz} =~ m![^\d]!)) {
#	msg("kein Ort, aber PLZ enthaelt vermutlich Ortsnamen PLZ=[$ref->{plz}], repariere Eintrag", 'cleanup_post_code');
#	$ref->{ort} = $ref->{plz};
#	$ref->{plz} = undef;
#	return 1;
#    }

    # keine PLZ vorhanden -> ist auch ok

    elsif(not defined $ref->{plz}) {
	return 1;
    }

    # Muell, der sich hoechstwahrscheinlich nicht reparieren laesst, loeschen.

    elsif(($ref->{plz} =~ m![^\d]!) or (length($ref->{plz}) <= 2) ) {
	msg("PLZ kaputt. Entferne [$ref->{plz}].", 'cleanup_post_code');
	$ref->{plz} = undef;
	return 1;
    }

    else {
	return 0;
    }
}



sub is_email_address {
    my $str = shift;

    if($str =~ m!\@!) {
	return 1;
    }

    if($str =~ m!^[^\.\@]+$!) {
	return 0;
    }

    if($str =~ m!^http(:?[\\//]+)!i) {
	return 0;
    }

    if($str =~ m!^www\..+?\.[a-z]{2,3}$!i) {
	return 0;
    }

    return undef;
}

sub is_web_address {
    my $str = shift;

    if($str =~ m!\@!) {
	return 0;
    }
    if($str =~ m!^[^\.]+$!) {
	return 0;
    }
    if($str =~ m!^http(:[\\//]+)!i) {
	return 1;
    }

    if($str =~ m!^(www\.)?[\-\w\.]+?\.[a-z]{2,3}$!i) {
	return 1;
    }

    if($str =~ m!^(www\.)?[\-\w\.]+?\.[a-z]{2,3}\/.*!i) {
	return 1;
    }

    return undef;
}

sub cleanup_web {
    my $ref = shift;
    
    if($ref->{webadresse} eq '') {
	return 1;
    }
    if(length($ref->{webadresse}) <= 4) {
	msg("[$ref->{webadresse}] ist viel zu kurz fuer keine Webadresse. Loesche Eintrag.", 'cleanup_web');
	$ref->{webadresse} = undef;
	return 1;
    }
    if($ref->{webadresse} =~ m!\&!) {
	msg("[$ref->{webadresse}] enhaelt kaufm. Und. Loesche Eintrag.", 'cleanup_web');
        $ref->{webadresse} = undef;
        return 1;
    }

    $ref->{webadresse} =~ s!\\!\/!g;
    $ref->{webadresse} =~ s!\,!\.!g;

    $ref->{webadresse} =~ s!:(de|com|net|org|info)$!$1!ei;
    $ref->{webadresse} =~ s!(de|com|net|org|info)\.$!$1!ei;

    if(is_email_address($ref->{webadresse})) {
	msg("[$ref->{webadresse}] ist eine Mailadresse.", 'cleanup_web');
	if($ref->{email} eq '') {
	    $ref->{email}= $ref->{webadresse};
	    $ref->{webadresse} = undef;
	    return 1;
	}
	elsif(is_web_address($ref->{email})) { # tauschen
	    msg("Tauschen", 'cleanup_web');
	    my $tmp = $ref->{email};
	    $ref->{email} = $ref->{webadresse};
	    $ref->{webadresse} = $tmp;
	    return 1;
	}
	elsif(is_email_address($ref->{email})) {
	    msg("Web und Mail sind Mailadresse. Loesche Eintrag fuer Webadresse.", 'cleanup_web');
	    $ref->{webadresse} = undef;
            return 1;

	}
	else {
	    msg("Keine weiteren Alternativen.", 'cleanup_web');
	}
	return 0;
    }
       
    # kaputte eintraege entfernen
    if($ref->{webadresse} =~ m!^(http[\.:]?[\/\\]*)?(www\.?)?$!i) {
	$ref->{webadresse} = undef;
	return 1;
    }

    $ref->{webadresse} =~ s!^http([:\.]?[\/\\I]*)?!!i;
    $ref->{webadresse} =~ s!^www[^\.]!www\.!i;

    if($ref->{webadresse} =~ m!^(www\.)?(.+?)\.[a-z]+$!i) {
#	msg("[$ref->{webadresse}] is ok", 'cleanup_web');
	return 1;
    }
    elsif($ref->{webadresse} =~ m!^(www\.)?(.+?)\.[a-z]+\/.*!i) {
#	msg("[$ref->{webadresse}] is ok", 'cleanup_web');
	return 1;
    }
    elsif(not is_web_address($ref->{webadresse})) {
        msg("[$ref->{webadresse}] ist keine Webadresse. Loesche Eintrag.", 'cleanup_web');
        $ref->{webadresse} = undef;
        return 1;
    }


    return 0;
}

sub cleanup_email {
    my $ref = shift;

    if($ref->{email} eq '') {
	return 1;
    }
    if(length($ref->{email}) <= 5) {
	msg("[$ref->{email}] ist viel zu kurz fuer eine Mailadresse. Loesche Eintrag.", 'cleanup_email');
	$ref->{email} = undef;
	return 1;
    }
    if($ref->{email} =~ m!\&!) {
	msg("[$ref->{email}] enhaelt kaufm. Und. Loesche Eintrag.", 'cleanup_email');
        $ref->{email} = undef;
        return 1;
    }

    $ref->{email} =~ s!\,!\.!g;
    $ref->{email} =~ s!:(de|com|net|org|info)$!$1!ei;

    $ref->{email} =~ s![\^\!\$\:\~\*\(]\@!\@!;
    $ref->{email} =~ s!\@[\+\>\^\)]!\@!;
    $ref->{email} =~ s!\@\@!\@!;

    $ref->{email} =~ s!\%20!!g;


    if(is_web_address($ref->{email})) {
	msg("[$ref->{email}] ist eine Webadresse.", 'cleanup_email');
	if($ref->{webadresse} eq '') {
	    $ref->{webadresse} = $ref->{email};
	    $ref->{email} = undef;
	    return 1;
	}
	elsif(is_email_address($ref->{webadresse})) { # tauschen
            my $tmp = $ref->{email};
            $ref->{email} = $ref->{webadresse};
            $ref->{webadresse} = $tmp;
            return 1;
        }
	return 0;
    }
    elsif($ref->{email} =~ m![\w\d\-\_\.]+\@[\w\d\-\.]+$!i) {
	return 1;
    }
    elsif(not is_email_address($ref->{email})) {
	msg("[$ref->{email}] ist keine Mailadresse. Loesche Eintrag.", 'cleanup_email');
	$ref->{email} = undef;
	return 1;
    }
    elsif(($ref->{email} =~ m!\@$!) or ($ref->{email} =~ m!^@!)) {
	msg("[$ref->{email}] endet auf '\@' oder beginnt damit. Ist keine Mailadresse. Loesche Eintrag.", 'cleanup_email');
	$ref->{email} = undef;
	return 1;
    }
    
    elsif($ref->{email} =~ s![\/\+\-]$!!) {
	msg("Entferne letztes Zeichen in Mailadresse", 'cleanup_email');
	return 1;
    }
    elsif($ref->{email} =~ s![\/\\]!-!g) {
	msg("Ersetze '/' in Mailadresse durch normale Trenner.", 'cleanup_email');
	return 1;
    }

    elsif($ref->{email} =~ s!\(.+?\)$!!g) {
	return 1;
    }
    elsif($ref->{email} =~ s!\?subject=.*$!!i) {
	return 1;
    }

    
    ### XXX
    $ref->{email} = undef;
    return 1;
}


sub cleanup_lvw {
    my $ref = shift;

    if(($ref->{lvw} eq '') and ($ref->{vorwahl} ne '') and ($ref->{rufnummer} ne '')) {
	$ref->{lvw} = '49';
    }
    return 1;
}
