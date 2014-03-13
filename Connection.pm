#!/usr/bin/perl
# 
# Connection.pm
# Created: Sat Feb 13 14:28:01 1999 by jay.kominek@colorado.edu
# Revised: Sat Dec  9 23:54:09 2000 by jay.kominek@colorado.edu
# Copyright 1999 Jay F. Kominek (jay.kominek@colorado.edu)
# This program comes with ABSOLUTELY NO WARRANTY.
# 
#####################################################################
# Connection module for Jiten, The Perl DICT Server
#####################################################################

package Connection;
use strict;
use Socket;
use Sys::Hostname;

use Dictionary;

my %commandhandlers = ('DEFINE' => \&handle_define,
		       'MATCH'  => \&handle_match,
		       'XMATCH' => \&handle_xmatch,
		       'SHOW'   => \&handle_show,
		       'CLIENT' => \&handle_client,
		       'STATUS' => \&handle_status,
		       'HELP'   => \&handle_help,
		       'QUIT'   => \&handle_quit,
		       'OPTION' => \&handle_option,
		       'AUTH'   => \&handle_auth,
		       'SASLAUTH' => \&handle_saslauth,
		       'SASLRESP' => \&handle_saslresp);
my @options = ('mime', 'xmatch');

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $this  = { };

  $this->{'socket'}    = shift;
  $this->{'outbuffer'} = shift;

  my($port,$iaddr)     = sockaddr_in(getpeername($this->{'socket'}));
  $this->{'host'}      = inet_ntoa($iaddr);

  $this->{'define'} = $this->{'match'} = 0;

  $this->{'last_active'} = $this->{'connected'} = time();

  $this->{'msgid'} = sprintf("<%i.%i\@%s>",$$,time,hostname);

  bless($this, $class);
  $this->sendnumeric(220,sprintf("%s jiten %1.1f <%s> %s",
				 hostname,
				 0.6,
				 join(".",@options),
				 $this->{'msgid'}));
  return $this;
}

sub lastactive {
  my $this = shift;
  return $this->{'last_active'};
}

sub handle {
  my $this = shift;
  my $line = shift;
  $line =~ s/^\s+//; $line =~ s/\s+$//;
  $this->{'last_active'} = time();
  $line =~ /^(\S+)/;
  chomp(my $command = $1);
  $command =~ tr/a-z/A-Z/;
  if(defined($commandhandlers{$command}) && ref($commandhandlers{$command})) {
#    print "$line\n";
    return (&{$commandhandlers{$command}}($this,$line));
  } else {
    $this->sendnumeric(500,"Syntax error, command not recognized");
  }
}

#####################################################################
# Protocol command handlers
#####################################################################

# DEFINE database word
sub handle_define {
  my $this = shift;
  my $line = shift;
  my($command,$database,$word) = &tokenize($line);
  if(Dictionary::havedatabase($database)) {
    my @results = Dictionary::define($database,$word);
    if(scalar @results>0) {
      my %dbs     = Dictionary::databases();
      $this->sendnumeric(150,($#results+1)." definitions retrived");
      foreach my $result (@results) {
	my @tmp = @{$result};
	$this->sendnumericmultiline(151,"\"$tmp[1]\" $tmp[0] \"$dbs{$tmp[0]}\"",$tmp[2]);
      }
      $this->sendnumeric(250,"ok");
    } else {
      $this->sendnumeric(552,"no match");
    }
  } else {
    $this->sendnumeric(501,"Syntax error, illegal parameters");
  }
  $this->{'define'}++;
}

# MATCH database strategy word
sub handle_match {
  my $this = shift;
  my $line = shift;
  my($command,$database,$strategy,$word) = &tokenize($line);

  if((Dictionary::havedatabase($database) || $database eq "!") &&
     (Dictionary::havestrat($strategy)) || $strategy eq ".") {
    my @results = Dictionary::match($database,$strategy,$word);
    if(scalar @results>0) {
      $this->sendnumericmultiline(152,($#results+1)." matches found",
				  map { sprintf("%s \"%s\"",@{$_}) }
				  @results);
      $this->sendnumeric(250,"ok");
    } else {
      $this->sendnumeric(552,"no match");
    }
  } else {
    $this->sendnumeric(501,"Syntax error, illegal parameters");
  }
  $this->{'match'}++;
}

# XMATCH database strategy word [arguments]...
sub handle_xmatch {
  my $this = shift;
  my $line = shift;
  my($command,$database,$strategy,$word,@args) = &tokenize($line);

  if((Dictionary::havedatabase($database) || $database eq "!") &&
     (Dictionary::havestrat($strategy) || $strategy eq ".")) {
    my @results = Dictionary::match($database,$strategy,$word,@args);
    if(scalar @results>0) {
      $this->sendnumericmultiline(152,($#results+1)." matches found",
				  map { sprintf("%s \"%s\"",@{$_}) }
				  @results);
      $this->sendnumeric(250,"ok");
    } else {
      $this->sendnumeric(552,"no match");
    }
  } else {
    $this->sendnumeric(501,"Syntax error, illegal parameters");
  }
  $this->{'match'}++;
}

# SHOW what
sub handle_show {
  my $this = shift;
  my $line = shift;
  my($command,$thing,@args) = &tokenize($line);
  $thing =~ tr/a-z/A-Z/;
  if($thing eq "DB" or $thing eq "DATABASES") {
    my %dbs = Dictionary::databases();
    if($dbs{'*'}) { delete($dbs{'*'}); }
    $this->sendnumericmultiline(110,(scalar keys %dbs)." databases present",
		       map { "$_ \"$dbs{$_}\"" } keys %dbs);
    $this->sendnumeric(250,"ok");
  } elsif($thing eq "STRAT" or $thing eq "STRATEGIES") {
    my %strats = Dictionary::strategies();
    $this->sendnumericmultiline(111,(scalar keys %strats)." strategies present", map { "$_ \"$strats{$_}\"" } keys %strats);
    $this->sendnumeric(250,"ok");
  } elsif($thing eq "INFO") {
    my $db = $args[0];
    if(Dictionary::havedatabase($db)) {
      $this->sendnumericmultiline(112,"Information for $db",
				  Dictionary::getdbdesc($db));
      $this->sendnumeric(250,"ok");
    } else {
      $this->sendnumeric(550,"Invalid database");
    }
  } elsif($thing eq "SERVER") {
    $this->sendnumericmultiline(114,"server information",
				"Jiten 0.6",
				"This information is worthless and hardcoded.");
    $this->sendnumeric(250,"ok");
  } else {
    $this->sendnumeric(501,"Syntax error, illegal parameters");
  }
}

# CLIENT string
sub handle_client {
  my $this = shift;
  my $line = shift;
  $line =~ /^(\S+) (.+)$/;
  $this->{'client'} = $2;
  $this->sendnumeric(250,"ok");
}

# STATUS
sub handle_status {
  my $this = shift;
  my @times = times();
  $this->sendnumeric(210,sprintf("running [%s u/s/cu/cs ; %s/%s d/m]",
				 join("/",times),
				 join("/",@{$this}{'define','match'})));
}

my @helptext = ("The following commands are valid:",
		"DEFINE db word",
		"MATCH db strat word",
		"XMATCH db strat word [args]..",
		"SHOW {DB,DATABASES}",
		"SHOW STRAT{EGIES,}",
		"SHOW INFO db",
		"SHOW SERVER",
		"CLIENT infostring",
		"OPTION MIME",
		"STATUS",
		"HELP",
		"QUIT");
# HELP
sub handle_help {
  my $this = shift;
  $this->sendnumericmultiline(113,"help text follows",
			      @helptext);
  $this->sendnumeric(250,"ok");
}

# QUIT
sub handle_quit {
  my $this = shift;
  $this->sendnumeric(221,"Closing Connection. Goodbye");
  return -1;
}

# OPTION name
sub handle_option {
  my $this = shift;
  my $line = shift;
  my($command,$option,@args) = &tokenize($line);
  if(uc($option) eq "MIME") {
    $this->{'mime'} = 1;
    $this->sendnumeric(250,"ok - using MIME headers");
  } else {
    $this->sendnumeric(501,"Syntax error, illegal parameters");
  }
}

# AUTH userid authentication-string
sub handle_auth {
  my $this = shift;
  $this->sendnumeric(502,"Command not implemented");
}

# SASLAUTH mechanism initial-response
sub handle_saslauth {
  my $this = shift;
  $this->sendnumeric(502,"Command not implemented");
}

# SASLRESP response
sub handle_saslresp {
  my $this = shift;
  $this->sendnumeric(502,"Command not implemented");
}

#####################################################################
# Data transmitting whatnot
#####################################################################

sub sendnumeric {
  my $this    = shift;
  my $numeric = shift;
  if(length($numeric)<3) {
    $numeric = ("0" x (3 - length($numeric))).$numeric;
  }
  $this->sendline(join(' ',$numeric,@_));
}

sub sendnumericmultiline {
  my $this    = shift;
  my $numeric = shift;
  my $numericline = shift;
  my @lines   = @_;
  $this->sendnumeric($numeric,$numericline);
  if($this->{'mime'}==1) {
    $this->sendline(""); # send blank line. (default mime headers)
  }
  foreach my $line (@lines) {
    foreach my $thisline (split(/\n/, $line)) {
      $this->sendline($thisline);
    }
  }
  $this->sendline(".");
}

sub sendline {
  my $this = shift;
  my $line = shift;
  $this->senddata($line."\r\n");
}

sub senddata {
  my $this = shift;
  $this->{'outbuffer'}->{$this->{'socket'}} .= shift;
}

#####################################################################
# Other
sub tokenize {
  my $line = shift;
  my @tokens;
  while($line=~s/(\".+?\"|\S+)\s*/push @tokens,$1;'';/e) { ; }
  return map{s/^\"//;s/\"$//;$_;} @tokens;
}

sub last_active {
  my $this = shift;
  return $this->{'last_active'};
}  

##################
# Class destructor
sub DESTROY {
  my $this = shift;
  my $duration = time()-$this->{'connected'};
}

1;
