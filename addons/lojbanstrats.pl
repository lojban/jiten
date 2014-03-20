use strict;

use File::Basename qw[ dirname ];

use Dictionary;


Dictionary::addstrategydesc('rafsi' => "Search by rafsi");

my %rafsi;
my $lojbandatadir = dirname(__FILE__) . '/../lojban';
my $rafsipath = sprintf("%s/rafsi",$lojbandatadir);
die qq{Can't read rafsi file '$rafsipath'} unless -r $rafsipath;

open(RAFSIDATA, $rafsipath);
binmode(RAFSIDATA, ":utf8");
while(<RAFSIDATA>) {
    if(/^(\S+)\s+(\S+)\s+(.+)$/)
    {
	$rafsi{lc($1)} = lc($2);
    }
}
close(RAFSIDATA);

sub strat_rafsi {
    my($dbref,$search) = @_;
    my @matching;
    my $gismu = $rafsi{lc($search)};
    if (defined($gismu))
    {
        if(exists($dbref->{ $gismu }))
        {
            push @matching, @{ $dbref->{'__'.$gismu} };
        }
    }
    return @matching;
}

1;
