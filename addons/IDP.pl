#!/usr/bin/perl
# 
# IDP.pl
# Created: Mon Feb 22 12:20:49 1999 by jay.kominek@colorado.edu
# Revised: Wed Feb 24 12:03:55 1999 by jay.kominek@colorado.edu
# Copyright 1999 Jay F. Kominek (jay.kominek@colorado.edu)
# This program comes with ABSOLUTELY NO WARRANTY.
# 
# Reads (most) data from the Internet Dictionary Project
# http://www.june29.com/IDP/
# Doesn't work on the Latin data because it is different.

package IDP;

sub loaddb {
    my($type, $name, $argument, $databases, $databasedesc) = @_;
    tie my(%dbhash), $type, $name, $argument;
    $databases->{$name} = \%dbhash;
    $databasedesc->{$name} = tied(%{$databases{$name}})->name();
}

sub TIEHASH {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $this  = { };

  $this->{'name'} = shift;
  $this->{'path'} = shift;

  open(DATA,$this->{'path'});
  my $pos = 0;
  while(<DATA>) {
    chomp;
    ($a,$b) = split/\t/;
    if(defined($this->{'data'}->{$a})) {
      push(@{$this->{'data'}->{$a}},[$pos+length($a)+2,length($b)])
    } else {
      $this->{'data'}->{$a} = [[$pos+length($a)+2,length($b)]];
    }
    $pos=tell(DATA);
  }
  close(DATA);

  local *datafh;
  open(datafh,$this->{'path'});
  $this->{'datafh'} = *datafh;

  $this->{'description'} = $this->{'path'};
  $this->{'description'} =~ s/\.txt$//;
  $this->{'description'} =~ s@^.+/@@;
  $this->{'description'} = "IDP English->".$this->{'description'}." Dictionary";

  bless $this, $class;
  return $this;
}

sub FETCH {
  my $this = shift;
  my $key  = shift;
  my $search = 0;
  if($key eq '@@keys') {
    my @tmp = keys %{$this->{'data'}};
    return \@tmp;
  }
  if($key =~ /^__/) { $key=~s/^__//; $search = 1; }
  if(defined($this->{'data'}->{$key})) {
    if($search) { return [[$this->{'name'},$key,'']]; }
    my $data = undef;
    my @response = ( );
    foreach(@{$this->{'data'}->{$key}}) {
      sysseek($this->{'datafh'},${$_}[0], SEEK_SET);
      sysread($this->{'datafh'},$data,${$_}[1]);
      push(@response,[$this->{'name'},$key,$data]);
    }
    return \@response;
  } else {
    return undef;
  }
}

sub STORE {
  # We can't change anything
  # my #this = shift;
  # my($key,$value) = @_;
}

sub DELETE {
  # We can't change anything
  # my #this = shift;
  # my($key,$value) = @_;
}

sub CLEAR {
  # We can't change anything
  # my $this = shift;
}

sub EXISTS {
  my $this = shift;
  my $key  = shift;
  return defined($this->{'data'}->{$key});
}

sub FIRSTKEY {
  my $this = shift;
  my $crap = keys %{$this->{'data'}};
  each %{$this->{'data'}};
}

sub NEXTKEY {
  my $this = shift;
  each %{$this->{'data'}};
}

sub name {
  my $this = shift;
  return $this->{'description'};
}

sub description {
  my $this = shift;
  return($this->{'description'});
}

sub virtual { return 0; }

sub DESTROY {
  my $this = shift;
  if(defined($this->{'datafh'})) {
    close($this->{'datafh'});
  }
}

1;
