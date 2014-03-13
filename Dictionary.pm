#!/usr/bin/perl
# 
# Dictionary.pm
# Created: Sat Feb 13 18:00:21 1999 by jay.kominek@colorado.edu
# Revised: Sat Feb 20 16:38:53 1999 by jay.kominek@colorado.edu
# Copyright 1999 Jay F. Kominek (jay.kominek@colorado.edu)
# This program comes with ABSOLUTELY NO WARRANTY.
# 
#####################################################################
# Dictionary database accessing code
#####################################################################

package Dictionary;
use Data::Dumper;

use strict;
no strict 'refs';

my %dbhandlers = ( );
my %databases  = ( );
my %strategies = ( );
my %users      = ( );

my %databasedesc = ( );
my %strategydesc = ( );

my($defaultdb,$defaultstrat) = ("test","exact");

sub loadconfiguration {
  my $conffile = shift;
  open(CONF,$conffile);
  while(<CONF>) {
    chomp;
    s/\s+\#.+//;
    my($cnfcmd,@args) = split/\s+/;
    if($cnfcmd eq "dbhandler") {
      my($name,$path) = @args[0..1];
      &loaddbhandler($name,$path);
    } elsif($cnfcmd eq "db") {
      my($name,$path,$type) = @args[0,1,2];
      &loaddb($name,$path,$type);
    } elsif($cnfcmd eq "strat") {
      my($name,$path) = @args[0..1];
      &loadstrat($name,$path);
    } elsif($cnfcmd eq "user") {
      # no auth-fu yet
    } else {
      # unknown
    }
  }
  close(CONF);
  if(defined($dbhandlers{'virtual'})) {
    my @nonvirtual;
      foreach my $database (keys %databases) {
	  my $type = ref(tied(%{$databases{$database}}));
	  unless($type eq 'virtual') {
	      push @nonvirtual, $database;
	  }
      }
    tie my %dbhash, 'virtual', '*', @nonvirtual;
    $databases{'*'} = \%dbhash;
    $databasedesc{'*'} = tied(%{$databases{'*'}})->name();
  }
}

sub loaddbhandler {
  my($name,$path) = @_;
    $path =~ m/([\w\/.:]*)/;
    $path = $1;
  require $path;
  $dbhandlers{$name} = 1;
}

sub loaddb {
  my($name,$type,$argument) = @_;
  if(defined($dbhandlers{$type})) {
    &{$type."::loaddb"}($type, $name, $argument, \%databases, \%databasedesc);
    #tie my(%dbhash), $type, $name, $argument;
    #$databases{$name}    = \%dbhash;
    #$databasedesc{$name} = tied(%{$databases{$name}})->name();
  } else {
    # we don't have a handler for this db type
  }
}

sub loadstrat {
  my($name,$path) = @_;
    $path =~ m/([\w\/.:]*)/;
    $path = $1;
  require $path;
    $name =~ m/([\w\/.:,]*)/;
    $name = $1;
  foreach my $name (split/,/,$name) {
    my $subref;
    eval "\$subref = \\&strat_$name;";
    $strategies{$name} = $subref;
  }
}

sub databases {
  return map { $_ => $databasedesc{$_} } keys %databases;
}

sub strategies {
  return map { $_ => $strategydesc{$_} } keys %strategies;
}

sub getdatabase {
  my $db = shift;
  return $databases{$db};
}

sub getstrat {
  my $strat = shift;
  return $strategies{$strat};
}

sub getdbdesc {
  my $db = shift;
  return tied(%{$databases{$db}})->description();
}

sub havedatabase {
  my $db = shift;
  return defined($databases{$db});
}

sub havestrat {
  my $strat = shift;
  return defined($strategies{$strat});
}

sub addstrategydesc {
  my %descs = @_;
  foreach(keys %descs) {
    $strategydesc{$_} = $descs{$_};
  }
}

sub match {
  my $db     = shift;
  my $strat  = shift;
  my $search = shift;
  my @args   = @_;
  $db    = ($db    eq "!" ? $defaultdb    : $db);
  $strat = ($strat eq "." ? $defaultstrat : $strat);
  my $stratcoderef = $strategies{$strat};
  my @results = &{$stratcoderef}($databases{$db},$search,@args);
  return @results;
}

sub define {
  my $db     = shift;
  my $search = shift;
  $db = (($db eq "!") ? $defaultdb : $db);
  my $results = $databases{$db}->{$search};
  if(defined($results)) {
    return @{$results};
  } else {
    return ( );
  }
}

1;
