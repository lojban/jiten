#!/usr/bin/perl
# 
# virtual.pl
# Created: Sun Feb 14 12:44:45 1999 by jay.kominek@colorado.edu
# Revised: Sat Feb 20 16:30:31 1999 by jay.kominek@colorado.edu
# Copyright 1999 Jay F. Kominek (jay.kominek@colorado.edu)
# This program comes with ABSOLUTELY NO WARRANTY.
# 
#####################################################################
# This provides a virtual database handle which can be used to group
# multiple databases into a single database.
#####################################################################

package virtual;

use strict;
use Dictionary;

sub TIEHASH {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $this  = { };

  $this->{'name'} = shift;
  @{$this->{'dbnames'}} = @_;
  @{$this->{'dbs'}} =
    map { Dictionary::getdatabase($_) } @{$this->{'dbnames'}};

  $this->{'description'} = join(' ',"Virtual combination of",
				@{$this->{'dbnames'}});

  bless $this, $class;
  return $this;
}

sub loaddb {
    my($type, $name, $argument, $databases, $databasedesc) = @_;
    my @includelist = split/,/,$argument;
    tie my(%dbhash), 'virtual', $name, @includelist;
    $databases->{$name} = \%dbhash;
    $databasedesc->{$name} = tied(%{$databases->{$name}})->name();
}

sub FETCH {
  my $this = shift;
  my $key  = shift;
  my @response = ( );
  if($key eq '@@keys') {
    my $i;
    foreach my $db (@{$this->{'dbs'}}) {
	next unless defined $db;
	my $data = $db->{'@@keys'};
	#print Dumper($data);
	push @response, @{$data};
    }
    my %tmp = map { $_ => 1 } @response;
    return [ keys %tmp ];
  }
  foreach my $db (@{$this->{'dbs'}}) {
    if(defined($db->{$key})) {
      my $data = $db->{$key};
      push @response, @{$data};
    }
  }
  return \@response;
}

sub STORE {
  # my $this = shift;
  # my($key,$value) = @_;
}

sub DELETE {
  # my $this = shift;
  # my($key,$value) = @_;
}

sub CLEAR {
  # my $this = shift;
  # my($key,$value) = @_;
}

sub EXISTS {
  my $this = shift;
  my $key  = shift;
  foreach my $db (@{$this->{'dbs'}}) {
    if(exists $db->{$key}) {
      return 1;
    }
  }
  return 0;
}

sub FIRSTKEY {
  my $this = shift;
  delete($this->{'keys'});
  %{$this->{'keys'}} = map { $_ => 1 } (map { @{$_->{'@@keys'}} } @{$this->{'dbs'}});
  each %{$this->{'keys'}};
}

sub NEXTKEY {
  my $this = shift;
  each %{$this->{'keys'}};
}

sub name {
  my $this = shift;
  return $this->{'description'};
}

sub description {
  my $this = shift;
  return ("A virtual grouping database");
}

sub virtual { return 1; }

sub DESTROY {
  my $this = shift;
}

1;
