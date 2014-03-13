#!/usr/bin/perl
# 
# defaultstrats.pl
# Created: Sat Feb 13 19:23:55 1999 by jay.kominek@colorado.edu
# Revised: Sat Feb 20 16:32:27 1999 by jay.kominek@colorado.edu
# Copyright 1999 Jay F. Kominek (jay.kominek@colorado.edu)
# This program comes with ABSOLUTELY NO WARRANTY.
# 
#####################################################################
# Default search strategies for Jiten
#####################################################################

use strict;

use Dictionary;

Dictionary::addstrategydesc('regexp' => "Standard Perl Regular Expression",
			    'exact'  => "Exact match",
			    'prefix' => "Match prefixes",
			    'suffix' =>"Match suffixes",
			    'substring'=>"Match substrings");

sub strat_regexp {
  my($db,$search) = @_;
  my @matching = ( );
  my $keysref = $db->{'@@keys'};
  foreach my $word (@{$keysref}) {
    if($word =~ /$search/) {
      push(@matching,@{$db->{'__'.$word}});
    }
  }
  return @matching;
}

sub strat_exact {
  my($db,$search) = @_;
  my @matching = ( );
  if(defined($db->{'__'.$search})) {
    my $foo = $db->{'__'.$search};
    push @matching,@{$foo};
  }
  return @matching;
}

sub strat_prefix {
  my($db,$search) = @_;
  my @matching = ( );
  my $keys = $db->{'@@keys'};
  foreach my $word (@{$keys}) {
    if(index($word,$search)==0) {
      my $foo = $db->{'__'.$word};
      push(@matching,@{$foo});
    }
  }
  return @matching;
}

sub strat_suffix {
  my($db,$search) = @_;
  my @matching = ( );
  foreach my $word (@{$db->{'@@keys'}}) {
    if(length($word)==(rindex($word,$search)+length($search))) {
      push(@matching,@{$db->{'__'.$word}});
    }
  }
  return @matching;
}

sub strat_substring {
  my($db,$search) = @_;
  my @matching = ( );
  my $words = $db->{'@@keys'};
  #$words ||= [ ];
  foreach my $word (@{$words}) {
    if(index($word,$search)>=0) {
      push(@matching,@{$db->{'__'.$word}});
    }
  }
  return @matching;
}

1;
