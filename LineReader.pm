# LineReader liesst aus den Einzeldateien jeweils eine Zeile aus.
# Via new() uebergibt man die Dateien eines Telefonbuchs. Mit
# get_line() kann man die Eintraege zeilenweise auslesen.
#
# Das Ergebnis von get_line() ist eine Hashref. Der Zugriff auf die
# einzelnen Werte erfolgt ueber einen Schlussel. Welcher Schluessel
# das dann ist, wird via new() gesteuert.
#
# Eine Besonderheit sind via new() definierte Schluessel, die den
# Unterstrich beinhalten. Der Unterstrich im Schluesselnamen gibt an,
# dass der Inhalt der Datei \t-separiert ist. Im Ergebnishash von
# get_line() findet man dann zwei Schluessel.

package LineReader;

use strict;
use IO::File;

sub new {
    my $class = shift;
    my $basedir = shift;
    my $ref = shift;

    my $self = { fh => {}};

    # open files

    foreach my $key (keys %$ref) {
	$self->{fh}->{$key} = new IO::File;
	if (not $self->{fh}->{$key}->open("$basedir/$ref->{$key}", 'r')) {
	    die "can't open '$ref->{$key}': $!\n";
	}
    }
    
    # calculate number of lines

    my $line_count_file = $basedir;
    $line_count_file =~ s!\W!!g;
    $line_count_file = '.' . $line_count_file;
    if(not -f $line_count_file) {
	print "++ running line count, storing result into '$line_count_file'\n";
	my $fname = (values %$ref)[0];
	$self->{line_count} = int(`wc -l $basedir/$fname`);
	if($self->{line_count} == 0) {
	    die "can't get number of lines for '$basedir/$fname'\n";
	}
	open(LC, "> $line_count_file") or die "can't open line count file '$line_count_file': $!\n";
	print LC $self->{line_count};
	close(LC);
    }
    else {
	print "++ reading line count file '$line_count_file'\n";
	$self->{line_count} = `cat $line_count_file`;
    }
    print "++ $self->{line_count} lines\n";

    bless $self, $class;
}


sub get_line {
    my $self = shift;
    my %result = ();

    my $eof = 1;

    foreach my $key (keys %{$self->{fh}}) {
	my $fh = $self->{fh}->{$key};
	if(!eof $fh) {
	    $eof = 0;
	}
	else {
	    warn "possible eof for $key reached\n";
	}
	my $tmp = <$fh>;
	chomp($tmp);
	my @values = split(/\t/, $tmp);

	foreach my $k (split(/_/, $key)) {
	    $result{$k} = shift @values;
	}
    }

    if(!$eof) {
	return \%result;
    }
    else {
	return undef;
    }
}

sub skip_lines {
    my $self = shift;
    my $line_nr = shift;

    foreach my $key (keys %{$self->{fh}}) {
	my $fh = $self->{fh}->{$key};

	for(my $i = 0; $i < $line_nr; $i++) {
	    <$fh>;
	}
    }

}


sub get_number_of_lines {
    my $self = shift;
    return $self->{line_count};
}


1;
