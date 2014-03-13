#!/usr/bin/perl
# 
# extstrat.pl
# Created: Sun Feb 14 10:31:14 1999 by jay.kominek@colorado.edu
# Revised: Fri Feb 19 14:26:54 1999 by jay.kominek@colorado.edu
# Copyright 1999 Jay F. Kominek (jay.kominek@colorado.edu)
# This program comes with ABSOLUTELY NO WARRANTY.
# 
#####################################################################
# Extended default search strategies for Jiten
#####################################################################

use strict;

use Dictionary;

use Text::Soundex;
#use Text::Metaphone;
use String::Approx qw(amatch);

Dictionary::addstrategydesc('soundex' => "Soundex Algorithm as described by Knuth",
#			    'metaphone' => "Metaphone Algorithm (designed for English-only)",
			    'lev' => "Match words within a given Levenshtein distance (default 1)");

sub strat_soundex {
  my($dbref,$search) = @_;
  my %db = %{$dbref};
  my @matching;
  my $soundexsearch = soundex($search);
  foreach my $word (keys %db) {
    if($soundexsearch eq soundex($word)) {
      push(@matching,@{$db{'__'.$word}});
    }
  }
  return @matching;
}

sub strat_metaphone {
  my($dbref,$search) = @_;
  my %db = %{$dbref};
  my @matching;
  my $metaphonesearch = Metaphone($search);
  foreach my $word (keys %db) {
    if($metaphonesearch eq Metaphone($word)) {
      push(@matching,@{$db{'__'.$word}});
    }
  }
  return @matching;
}

sub strat_lev {
  my($dbref,$search,@args) = @_;
  my %db = %{$dbref};
  my $k = $args[0]>1?$args[0]:1;
  return map { @{$db{'__'.$_}} } amatch($search,[$k],keys %db);
}

1;
