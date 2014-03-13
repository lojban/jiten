#!/usr/bin/perl
# 
# dud.pl
# Created: Sat Feb 13 19:24:23 1999 by jay.kominek@colorado.edu
# Revised: Mon Feb 15 22:39:49 1999 by jay.kominek@colorado.edu
# Copyright 1999 Jay F. Kominek (jay.kominek@colorado.edu)
# This program comes with ABSOLUTELY NO WARRANTY.
# 
#####################################################################
# Dud Dictionary database module
#####################################################################

package dud;

sub loaddb {
    my($type, $name, $argument, $databases, $databasedesc) = @_;
    tie my(%dbhash), $type, $name, $argument;
    $databases->{$name} = \%dbhash;
    $databasedesc->{$name} = tied(%{$databases{$name}})->name();
}

sub TIEHASH {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $this  = {  };
  my $name  = shift;
  my $path  = shift;
    $this->{'name'}  = $name;
  %{$this->{'data'}} = ('keyboard' => "an input device consisting of keys",
			'monitor'  => "an output device with phosphorus",
			'mouse'    => "rodent that eats cheese");
  bless $this, $class;
  return $this;
}

sub FETCH {
  my $this = shift;
  my $key  = shift;
  if(defined($this->{'data'}->{$key})) {
    return [[$this->{'name'},$key,$this->{'data'}->{$key}]];
  } else {
    return [];
  }
}

sub STORE {
  my $this = shift;
  my($key,$value) = @_;
}

sub DELETE {
  my $this = shift;
  my $key  = shift;
}

sub CLEAR {
  my $this = shift;
}

sub EXISTS {
  my $this = shift;
  my $key  = shift;
  return exists $this->{'data'}->{$key};
}

sub FIRSTKEY {
  my $this = shift;
  my $crap = keys %{$this->{'data'}};
  each %{$this->{'data'}};
}

sub NEXTKEY {
  my $this = shift;
  return each %{$this->{'data'}};
}

sub name {
  my $this = shift;
  return "a dud database";
}

sub description {
  my $this = shift;
  return "A dud database used for testing purposes";
}

sub virtual { return 0; }

1;
