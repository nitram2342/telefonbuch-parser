package Continuation;

use strict;
use Data::Dumper;
use DBD::Pg;

my @attr = qw( inverse_allowed
	       is_corporation
	       nachname
	       vorname
	       namenszusatz
	       detail
	       strasse
	       hausnummer
	       adresszusatz
	       plz
	       ort
	       ortszusatz
	       lvw
	       vorwahl
	       rufnummer
	       is_phone
	       is_fax
	       email
	       webadresse
	       version);


sub get_attributes {
    return @attr;
}

sub new {

    my $class = shift;
    my $dbh = shift;
    my $self = { dbh => $dbh,
	     list => []};


    bless $self, $class;
}


sub add_line {
    my $self = shift;
    my $ref = shift;

    push @{$self->{list}}, $ref;
}

sub get_numbers {
    my $self = shift;

    my @list = ();
    foreach my $line (@{$self->{list}}) {
	
	if(($line->{vorwahl} ne '') and ($line->{rufnummer} ne '')) {
	    push @list, [$line->{lvw}, $line->{vorwahl}, $line->{rufnummer}];
	}
    }

    return \@list;
}

sub print {
    my $self = shift;
    foreach my $r ( @{$self->{list}}) {
	printf("%-7s %-20s %-20s %-20s %-20s %10s %10s\n", 
	       $r->{cont_id} ne '' ? $r->{cont_id} : "-----", $r->{nachname}, $r->{vorname}, 
	       $r->{namenszusatz}, $r->{adresszusatz}, $r->{vorwahl}, 
	       $r->{rufnummer} . ($r->{is_fax_number} ? ' fax': ''));
    }
}

sub insert {
    my $self = shift;
    my $sth = shift;

    my $cont_id = $self->get_new_cont_id();

    if(not defined $cont_id) {
	die "get_new_cont_id() failed\n";
    }

    my $line_count = 0;

    foreach my $line (@{$self->{list}}) {
	$sth->bind_param(1, $cont_id) || die "can't bind param";
	$sth->bind_param(2, $line_count) || die "can't bind param";
	my $i = 3;
	foreach my $k (@attr) {
	    $sth->bind_param($i, $line->{$k}) || die "can't bind param $i - $k\n";
	    $i++;
	}
	$sth->execute() || die "can't execute insert stm\n";
	$line_count++;
    }

    
}

sub get_new_cont_id {
    my $self = shift;

    my $stm = "select nextval('seq_cont_id')";
    my $sth = $self->{dbh}->prepare($stm) || die "can't prepare stm\n";
    $sth->execute() || die "can't execute\n";
    my $x = $sth->fetchrow_arrayref()->[0];
    $sth->finish();
    return $x;
}

sub load_by_id {
    my $self = shift;
    my $sth = shift;
    my $cont_id = shift;

    $sth->bind_param(1, $cont_id) || die "can't bind param\n";
    $sth->execute() || die "can't execute\n";
    
    while(defined(my $ref = $sth->fetchrow_hashref())) {
	push @{$self->{list}}, $ref;
    }
}



sub merge_old {
    my $self = shift;
    my $src_cont = shift;

#    $src_cont->print();
#    $self->print();

    if($src_cont->number_of_lines() != $self->number_of_lines()) {
	return 0;
    }

    # Anz. Untereintraege gleich. Ueber alle Eintraege iterieren und Attr.
    # vergleichen
    for(my $i = 0; $i < $src_cont->number_of_lines(); $i++) {
	my $src_line = $src_cont->get_line_ref($i);
	my $dst_line = $self->get_line_ref($i);

	# Attribute pruefen, die fuer einen merge identisch sein muessen
	foreach my $attr (qw(nachname vorname strasse hausnummer plz ort lvw vorwahl rufnummer)) {
	    if($src_line->{$attr} ne $dst_line->{$attr}) { return 0;}
	}
    }


    # Untereintraege in allen wichtigen Kriterien gleich. Ueber alle Eintraege iterieren und Attr.
    # mergen oder uebernehmen
    for(my $i = 0; $i < $src_cont->number_of_lines(); $i++) {
	my $src_line = $src_cont->get_line_ref($i);
	my $dst_line = $self->get_line_ref($i);
	
	
	# mergen
	foreach my $attr (qw(namenszusatz detail ortszusatz email webadresse)) {

	    my $mergeable = 1;
	    my @dst_substr = split (/\t/, $dst_line->{$attr});
	    
	    foreach my $subs (@dst_substr) {
		if($subs eq $src_line->{$attr}) {
		    $mergeable = 0; # doch nicht, der Eintrag ist bereits enthalten
		} 
	    }

	    if($mergeable) {
		@dst_substr[$src_line->{version}] = $src_line->{$attr}; 
		$dst_line->{$attr} = join("\t", @dst_substr);
	    }


	}

	# aktuelle Daten uebernehmen
	foreach my $attr (qw(inverse_allowed is_corporation is_phone is_fax)) {
	    $dst_line->{$attr} = $src_line->{$attr};
	}

	$dst_line->{version} = int($dst_line->{version}) | int($src_line->{version});
	#print "merged -> $dst_line->{version}\n";
    }

    return 1;
}


sub lines_are_equal {
    my $self = shift;
    my $src_line = shift;
    my $dst_line = shift;

    # Attribute pruefen, die fuer einen merge identisch sein muessen
    foreach my $attr (qw(nachname vorname strasse hausnummer plz ort lvw vorwahl rufnummer)) {
	if($src_line->{$attr} ne $dst_line->{$attr}) { return 0;}
    }
	
    return 1;
}

sub merge_lines {
    my $self = shift;
    my $src_line = shift;
    my $dst_line = shift;

    foreach my $attr (qw(namenszusatz detail ortszusatz email webadresse)) {
	
	my $mergeable = 1;
	my @dst_substr = split (/\t/, $dst_line->{$attr});
	
	foreach my $subs (@dst_substr) {
	    if($subs eq $src_line->{$attr}) {
		$mergeable = 0; # doch nicht, der Eintrag ist bereits enthalten
	    } 
	}
	
	if($mergeable) {
	    @dst_substr[$src_line->{version}] = $src_line->{$attr}; 
	    $dst_line->{$attr} = join("\t", @dst_substr);
	}
	
	
    }
    
    # aktuelle Daten uebernehmen
    foreach my $attr (qw(inverse_allowed is_corporation is_phone is_fax)) {
	$dst_line->{$attr} = $src_line->{$attr};
    }
    
    $dst_line->{version} = int($dst_line->{version}) | int($src_line->{version});
}

sub merge {
    my $self = shift;
    my $src_cont = shift;

    # Passen Conts zusammen?
    if(not $self->lines_are_equal($src_cont->get_line_ref(0), $self->get_line_ref(0))) {
	return 0;
    }

    my @new_lines;

    
    # Untereintraege in allen wichtigen Kriterien gleich. Ueber alle Eintraege iterieren und Attr.
    # mergen oder uebernehmen

    for(my $i = 0; $i < $src_cont->number_of_lines(); $i++) {
	my $src_line = $src_cont->get_line_ref($i);
	my $dst_line = $self->get_line_ref($i);
	
	if($self->lines_are_equal($src_line, $dst_line)) {
	    $self->merge_lines($src_line, $dst_line);
	    push @new_lines, $dst_line;
	}
	else {
	    push @new_lines, $dst_line, $src_line;
	}
    }

    return 1;
}

sub get_line_ref {
    my $self = shift;
    my $idx = shift;
    return $self->{list}->[$idx];
}

sub number_of_lines {
    my $self = shift;
    return $#{$self->{list}} + 1;
}

#
# Aktuelle Cont speichern
#
sub save {
    my $self = shift;
    my $sth = shift;

    foreach my $line (@{$self->{list}}) {

	my $i = 1;
	foreach my $attr (@attr) {
	    $sth->bind_param($i++, $line->{attr}) || die "can't bind param\n";
	}

	$sth->bind_param($i++, $line->{id}) || die "can't bind param";

	$sth->execute() || die "can't execute insert stm\n";
    }
}

1;
