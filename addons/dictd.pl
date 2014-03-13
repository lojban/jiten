#!/usr/bin/perl
# 
# dictd.pl
# Created: Sat Feb 13 23:16:55 1999 by jay.kominek@colorado.edu
# Revised: Mon Feb 22 14:28:04 1999 by jay.kominek@colorado.edu
# Copyright 1999 Jay F. Kominek (jay.kominek@colorado.edu)
# Portions copyright: Bret Martin (bamartin@miranda.org)
#                     Rik Faith (faith@acm.org)
# This program comes with ABSOLUTELY NO WARRANTY.
# 
#####################################################################
# Module to access (uncompressed) data stored in a format compatible
# with Rik Faith's dictd
#####################################################################

package dictd;

$b64_list = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
@b64_list = split '' , $b64_list;

$X = 100;
@b64_index = ($X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X,
              $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X,
              $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,62, $X,$X,$X,63,
              52,53,54,55, 56,57,58,59, 60,61,$X,$X, $X,$X,$X,$X,
              $X, 0, 1, 2,  3, 4, 5, 6,  7, 8, 9,10, 11,12,13,14,
              15,16,17,18, 19,20,21,22, 23,24,25,$X, $X,$X,$X,$X,
              $X,26,27,28, 29,30,31,32, 33,34,35,36, 37,38,39,40,
              41,42,43,44, 45,46,47,48, 49,50,51,$X, $X,$X,$X,$X,
              $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X,
              $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X,
              $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X,
              $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X,
              $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X,
              $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X,
              $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X,
              $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X, $X,$X,$X,$X,
              );

sub base64_decode ($) {
    my ($val) = @_;

    @val = split '' , $val ;

    $result = 0;
    $offset = 0;
    for ($i = length($val)-1; $i >= 0; $i--) {
        $tmp = $b64_index[ ord($val[$i]) ];
        $result |= ($tmp << $offset);

        $offset += 6;
    }

    $result;
}

sub loaddb {
    my($type, $name, $argument, $databases, $databasedesc) = @_;
    tie my(%dbhash), $type, $name, $argument;
    $databases->{$name} = \%dbhash;
    $databasedesc->{$name} = tied(%{$databases->{$name}})->name();
}

sub TIEHASH {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $this  = { };
  my $fullpath;

  $this->{'name'} = shift;
  $this->{'path'} = shift;
  $indexpath = $this->{'path'}.'.index';

  open(INDEX, $indexpath)
      || die "couldn't open index file for database \"", $this->{name},
             "\"\n  Full path: $indexpath\n  Error: $!\n";
  my @index = <INDEX>;
  close(INDEX);
  foreach(@index) {
    chomp;
    my($key,$start,$length)=split(/\t/,$_,3);
    $this->{'data'}->{$key} = [$start,$length,1];
  }

  undef @index;
  if(-f $this->{'path'}.".dict.dz") {
    $this->{'compressed'} = 1;
    $this->{'zdatapath'} = $this->{'path'}.".dict.dz";
  } else {
    $this->{'compressed'} = 0;
    local *datafh;
    open(datafh,$this->{'path'}.".dict")
        || die "couldn't open data file for database \"", $this->{name},
             "\"\n  Full path: ", $this->{path}.".dict\n  Error: $!\n";
    $this->{'datafh'} = *datafh;
  }

  bless $this, $class;
  my $data = @{@{$this->FETCH('00-database-short')}[0]}[2];
  my @datalines = split(/\n/,$data);
  $datalines[1] =~ s/^\s+//; $datalines[1] =~ s/\s+$//;
  $this->{'description'} = $datalines[1];
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
    my $data = undef;
    if($search) { return [[$this->{'name'},$key,'']]; }
    if(${$this->{'data'}->{$key}}[2]) {
      pop(@{$this->{'data'}->{$key}});
      ${$this->{'data'}->{$key}}[0] =
	base64_decode(${$this->{'data'}->{$key}}[0]);
      ${$this->{'data'}->{$key}}[1] =
	base64_decode(${$this->{'data'}->{$key}}[1]);
    }
    if($this->{'compressed'}) {
      open(DICTZIP,"dictzip -dc -s ".${$this->{'data'}->{$key}}[0]." -e ".${$this->{'data'}->{$key}}[1]." ".$this->{'zdatapath'}."|");
      $data = join('',<DICTZIP>);
      close(DICTZIP);
    } else {
      sysseek($this->{'datafh'}, ${$this->{'data'}->{$key}}[0], SEEK_SET);
      sysread($this->{'datafh'},  $data,  ${$this->{'data'}->{$key}}[1]);
    }
    return [[$this->{'name'},$key,$data]];
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
  my @results = @{$this->FETCH('00-database-info')};
  return @{$results[0]}[2];
}

sub virtual { return 0; }

sub DESTROY {
  my $this = shift;
  if(defined($this->{'datafh'})) {
    close($this->{'datafh'});
  }
}
