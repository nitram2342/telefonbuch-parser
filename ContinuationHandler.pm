package ContinuationHandler;

use strict;
use IO::File;
use DBD::Pg;
use Data::Dumper;
use Continuation;

#my $database = 'phonebook2';
my $database = 'pb2';
my $user = 'martin';
my $passwd = undef;

my $table = 'tb_eintrag';



sub new {
    my $class = shift;
    my $last_version_bit = int(1 << shift());
    my $self = {};

    $self->{dbh} = DBI->connect("dbi:Pg:dbname=$database", $user, $passwd,
				{ChopBlanks => 1,
				 RaiseError => 1,
				 Warn => 1,
				 AutoCommit => 0});
    

    my $check_conts = "select distinct(cont_id) from $table where lvw = ? and vorwahl = ? and rufnummer = ? and version & $last_version_bit != 0";
    $self->{check_conts_sth} = $self->{dbh}->prepare_cached($check_conts) || die "can't prepare statement";

    my $load_cont = "select * from $table where version & $last_version_bit != 0 and cont_id = ? order by cont_pos";
    $self->{load_cont_sth} = $self->{dbh}->prepare_cached($load_cont) || die "can't prepare statement";
    
    my $insert = "insert into $table (cont_id, cont_pos, ". join(',', Continuation::get_attributes() ) .") values (?,?," . 
	join(',', map { '?'} Continuation::get_attributes()) . ")";
    $self->{insert_sth} = $self->{dbh}->prepare_cached($insert) || die "can't prepare statement";

    my $update = "update $table set ". join(', ', map { "$_ = ? "} Continuation::get_attributes() ) ." where id = ?";
    $self->{update_sth} = $self->{dbh}->prepare_cached($update) || die "can't prepare statement";

    bless $self, $class;
}


sub handle {
    my $self = shift;
    my $ref = shift;
    
    if(not $ref) { die "undefined reference"; }

    if($ref->{cont_start}) {

	if(ref $self->{current_cont}) {
	    $self->save();
#	    if($self->{cont_counter}++ == 100000) {
#		return 0;
#	    }
	    #$self->{current_cont}->print();
	}

	$self->{current_cont} = Continuation->new( $self->{dbh} );
	$self->{current_cont}->add_line($ref);
    }
    elsif($ref->{cont}) {
	$self->{current_cont}->add_line($ref);
    }
    else {
	die "error: ". Dumper($ref);
    }

    return 1;
}

sub commit {
    my $self = shift;
    $self->{dbh}->commit();
}

sub finished {
    my $self = shift;
    ### hier die letzte continuation wegspeichern
    # ...
    $self->save();

    # letztes commit
    $self->{dbh}->commit();
}


sub save {
    my $self = shift;

    # Die akt. Continuation enthaelt 0..N Nummern.
    # Jede Nummer kommt in 0..M bereits gespeicherten Continuations vor.

    # Liste laden.
    my $number_matching_conts = $self->get_continuations_by_number();
    # Die aktuelle Contination ist gaenzlich unbekannt. Einfach speichern
    if(not @$number_matching_conts) {
#	print "akt. Cont unbekannt. Speichern\n";
	$self->{current_cont}->insert($self->{insert_sth});
	return 1;
    }

    # Es gibt mehrere Continations in der DB, die eine der Nummern aus
    # der akt. Cont. enthaelt.

    my $was_merged = 0;
    foreach my $cont_id (@$number_matching_conts) {

	# Lade
#	print "Lade cont $cont_id\n";
	my $a_cont = Continuation->new($self->{dbh});
	$a_cont->load_by_id($self->{load_cont_sth}, $cont_id);

#	print "Vergleiche akt. Cont. mit Cont $cont_id\n";
	# Vergleiche

	my $result = $a_cont->merge_old($self->{current_cont});
	
	if($result) {
#	    $a_cont->print();
#	    print "akt. Cont entspricht (weitgehend) Cont $cont_id\naktualisiere DB-Eintrag fuer Cont $cont_id\n";
	    $a_cont->save($self->{update_sth});
	    $was_merged = 1;
	}
#	elsif(defined $x) {
#	    print "akt. Cont ungleich Cont $cont_id\n";
#	}
    }

    if(not $was_merged) {
#	print "akt. Cont unbekannt. Speichern 2\n";
	$self->{current_cont}->insert($self->{insert_sth});
    }

    
}

# Alle Telefonnummern der aktuellen Kontinuation auslesen
# und die DB nach Objekten befragen. -> Cont-IDs als Liste

sub get_continuations_by_number {
    my $self = shift;

    my %matching_conts = ();

    foreach my $number_ref (@{$self->{current_cont}->get_numbers()}) {

	$self->{check_conts_sth}->bind_param(1, $number_ref->[0]) || die "can't bind param";
	$self->{check_conts_sth}->bind_param(2, $number_ref->[1]) || die "can't bind param";
	$self->{check_conts_sth}->bind_param(3, $number_ref->[2]) || die "can't bind param";
	
	$self->{check_conts_sth}->execute();

	while(defined(my $ref = $self->{check_conts_sth}->fetchrow_arrayref() )) {
	    $matching_conts{$ref->[0]}++;
	}
	
    }
    return [keys %matching_conts];
}




1;
