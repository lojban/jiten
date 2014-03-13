use strict;

use Dictionary;

Dictionary::addstrategydesc('rafsi' => "Search by rafsi");

my %rafsi;
my $lojbandatadir = "/srv/jiten/lojban";
open(RAFSIDATA,sprintf("%s/rafsi",$lojbandatadir));
while(<RAFSIDATA>) {
    if(/^(\S+)\s+(\S+)\s+(.+)$/)
    {
	$rafsi{$1} = $2;
    }
}
close(RAFSIDATA);

sub strat_rafsi {
    my($dbref,$search) = @_;
    my @matching;
    if(defined($dbref->{ $rafsi{$search} }))
    {
	push @matching, @{ $dbref->{'__'.$rafsi{$search}} };
    }
    return @matching;
}

1;
