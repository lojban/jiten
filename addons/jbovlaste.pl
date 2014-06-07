#!/usr/bin/perl
# 
# jbovlaste.pl
# Copyright 2003 Jay F. Kominek (jkominek-jiten@miranda.org)
# This program comes with ABSOLUTELY NO WARRANTY.
# 
# Presents data from the jbovlaste PostgreSQL database.

package jbovlaste;

use DBI;
use Text::Wrap;
use Data::Dumper;

use strict;

my $dbh = undef;
my $lastdbhtime = 0;
my @dbharguments;

sub fixdbh {
    return unless (time-$lastdbhtime)>10;
    if(!defined($dbh) || !$dbh->ping) {
	$dbh = DBI->connect(@dbharguments);
	$dbh->{pg_enable_utf8} = 1;
	$lastdbhtime = time;
    }
}

sub loaddb {
    my($type, $name, $argument, $databases, $databasedesc) = @_;
    @dbharguments=(split/,/, $argument);
    &fixdbh;

    my $languages = $dbh->selectall_arrayref('SELECT langid, tag, englishname FROM languages WHERE langid>0 order by englishname');

    tie my(%dbhash), 'jbovlaste', 'jbo', 1, $languages->[0];
    $databases->{'jbo'} = \%dbhash;
    $databasedesc->{'jbo'} = tied(%{$databases->{'jbo'}})->name();

    for(my $i=1 ; $i<=$#{$languages}; $i++) {
	# print "lang: " . Dumper( $languages->[$i] ) . "\n";
	&internalloaddb(1, $languages->[$i], $databases, $databasedesc);
	&internalloaddb(0, $languages->[$i], $databases, $databasedesc);
    }
}

sub internalloaddb {
    my($tolojban, $natlang, $databases, $databasedesc) = @_;
    my $format = $tolojban ? "%s->jbo" : "jbo->%s";
    my $namestr = sprintf($format, $natlang->[1]);
    tie my(%dbhash), 'jbovlaste', $namestr, $tolojban, $natlang;
    $databases->{$namestr} = \%dbhash;
    $databasedesc->{$namestr} = tied(%{$databases->{$namestr}})->name();
}

sub TIEHASH {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $this  = { };

    $this->{'name'}     = shift;
    $this->{'tolojban'} = shift;
    $this->{'natlang'}  = shift;
    $this->{'data'}     = { };

    if($this->{'natlang'}->[1] eq "jbo") {
	$this->{'description'} = "Pure-Lojban Dictionary";
    } else {
	if($this->{'tolojban'}) {
	    $this->{'description'} =
		$this->{'natlang'}->[2]." to Lojban";
	} else {
	    $this->{'description'} =
		"Lojban to ".$this->{'natlang'}->[2];
	}
    }

    bless $this, $class;
    return $this;
}

sub FETCH {
    my $this = shift;
    my $key  = shift;
    my $search = 0;

    &fixdbh;

    if($key eq '@@keys') {
	&refreshdata($this);
	my @tmp = keys %{$this->{'data'}};
	return \@tmp;
    }
    if($key =~ /^__/) { $key=~s/^__//; $search = 1; }
    my $lowerkey = lc($key);
    if($this->{'tolojban'}) {
	my $response = [];
	my $sth = $dbh->prepare("SELECT * FROM natlangwords nlw,
		natlangwordbestguesses nlwbg, definitions d WHERE
		nlw.wordid=nlwbg.natlangwordid AND
		nlwbg.definitionid=d.definitionid AND lower(nlw.word)=? AND
		nlw.langid=?");
	$sth->execute($lowerkey, $this->{'natlang'}->[0]);
	while(defined(my $row = $sth->fetchrow_hashref)) {
	    push @{$response}, [ $this->{'name'}, $key, &formatToLojban($row) ];
	}
	return $response;
    } else {
	my $result = $dbh->selectrow_hashref("SELECT * FROM valsi v,
		valsibestguesses vbg, definitions d, valsitypes vt WHERE
		v.valsiid=vbg.valsiid AND vbg.definitionid=d.definitionid
		AND vbg.langid=? AND lower(v.word)=? AND v.typeid=vt.typeid", undef,
		$this->{'natlang'}->[0], $lowerkey);
	if(defined($result)) {
	    return [[ $this->{'name'}, $key, &formatFromLojban($result) ]];
	} else {
	    return [ ];
	}
    }
}

sub formatToLojban {
    my $row = shift;
    my @strs = ("", "", "");
    my $str;

    my $meaning; my $place; my $selmaho; my $word; my $valsi;
    foreach my $key (sort keys %{$row})
    {
SWITCH: {
	    $key =~ /^word$/ && do {
		$word = $row->{$key};
		$strs[0] = "{$word}, ";
		last SWITCH;
	    };

	    $key =~ /^meaning$/ && do {
		$meaning = $row->{$key};
		if( $meaning )
		{
		    $strs[1] = "in the sense of \"$meaning\", ";
		}
		last SWITCH;
	    };

	    $key =~ /^valsiid$/ && do {
		$valsi = $dbh->selectrow_array( "SELECT word FROM valsi
			WHERE valsiid=$row->{$key}" );
		last SWITCH;
	    };

	    $key =~ /^place$/ && do {
		$place = $row->{$key};
		last SWITCH;
	    };
	}
    }

    if( $place == 0 )
    {
	$strs[2] = " is the gloss word for {$valsi}.\n";
    } else {
	$strs[2] = " is the keyword for place $place of {$valsi}.\n";
    }
    
    $str = wrap( "", "", join( "", @strs ));
    return $str;
}

sub formatFromLojban {
    my $row = shift;
    my @strs = ("", "", "", "", "", "", "");
    my $str;
    my( $definition, $meaning, $rafsi, $places, $selmaho, $notes, $word, $glossword, $valsi );

    foreach my $key (sort keys %{$row})
    {
SWITCH: {
	    $key =~ /^word$/ && do {
		$word = $row->{$key};
		my $type = $row->{'descriptor'};
		if($type =~ /experimental/) {
		    $type .= " (YOU RISK BEING MISUNDERSTOOD IF YOU USE THIS WORD)";
		}
		$strs[0]  = "      Word: {$word}\n";
		$strs[0] .= "      Type: $type\n";
		last SWITCH
	    };

	    $key =~ /^definition$/ && do {
		$definition = $row->{$key};
		$strs[4] = "Definition: ";
		my $space1 = " " x length $strs[4];
		my $tmp = wrap( $space1, $space1, &deLaTeX($definition) )."\n";
		$tmp =~ s/^\s+//;
		$strs[4] .= $tmp;
		last SWITCH
	    };

	    $key =~ /^notes$/ && do {
		$notes = $row->{$key};
		if( $notes )
		{
		    $strs[5] = "     Notes: ";
		    my $space2 = " " x length $strs[5];
		    my $tmp = wrap( $space2, $space2, &deLaTeX($notes) ). "\n";
		    $tmp =~ s/^\s+//;
		    $strs[5] .= $tmp;
		}
		last SWITCH
	    };

	    $key =~ /^rafsi$/ && do {
		$rafsi = $row->{$key};
		if( $rafsi )
		{
		    $rafsi =~ s/\s+/ /g;
		    $rafsi =~ s/^\s+//g;
		    $rafsi =~ s/\s+$//g;
		    $strs[2] = "     rafsi: $rafsi\n";
		}
		last SWITCH
	    };

	    $key =~ /^selmaho$/ && do {
		$selmaho = $row->{$key};
		if( $selmaho )
		{
		    $strs[3] = "   selma'o: $selmaho\n";
		}
		last SWITCH
	    };

	    $key =~ /^valsiid$/ && do {
		$valsi = $dbh->selectrow_array( "SELECT word FROM valsi
			WHERE valsiid=$row->{$key}" );
		last SWITCH;
	    };

	    $key =~ /^definitionid$/ && do {
		my $placesref = $dbh->selectall_arrayref(
			"SELECT k.place, n.word, n.meaning
			FROM keywordmapping k, natlangwords n
			WHERE k.definitionid=$row->{$key}
			AND k.natlangwordid = n.wordid" );

		my @placewords = @{$placesref};
		
		my $i=0;
		$strs[1]="";
		$strs[6]="";
		foreach my $placerow (@placewords)
		{
		    if( ${$placerow}[0] == 0 )
		    {
			$glossword = ${$placerow}[1];
			$strs[1] .= "Gloss Word: {$glossword}";
			if( ${$placerow}[2] )
			{
			    $strs[1] .= " in the sense of \"${$placerow}[2]\"\n";
			} else {
			    $strs[1] .= "\n";
			}
			next;
		    }

		    $strs[6] .= "  ${$placerow}[0]. {${$placerow}[1]}";
		    if( ${$placerow}[2] )
		    {
			$strs[6] .= " in the sense of \"${$placerow}[2]\"\n";
		    } else {
			$strs[6] .= "\n";
		    }
		    $i++;
		}

		if( $strs[6] )
		{
		    $strs[6] = "Place Keywords:\n". $strs[6];
		}			
		last SWITCH;
	    };
	}
    }

    $str = join( "", @strs );
    return $str;
}

sub deLaTeX {
    my $text = shift;
    sub handleSubscriptedPlace {
      my $foo = shift;
      $foo =~ s/\$//g;
      my @parts = split/=/,$foo;
      @parts = map { /(\w)_(\d|{\d+})/;
		     my($letter,$num) = ($1,$2);
		     $num =~ s/[\{\}]//g;
		     "$letter$num" } @parts;
      return join("=",@parts);
    }
    $text =~
      s/\$(\w_(\d|\{\d+\}))(=(\w_(\d|\{\d+\})))*\$/
			   &handleSubscriptedPlace($1)/ge;
    return $text;
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

sub refreshdata {
    my $this = shift;
    my $lastrefreshed = $this->{'lastrefreshed'} || 0;
    unless(time()-$lastrefreshed>(30*60)) {
	return;
    }
    $this->{'data'} = { };
    if($this->{'tolojban'}) {
	my $sth = $dbh->prepare("SELECT DISTINCT word FROM natlangwords
		WHERE langid=?");
	$sth->execute($this->{'natlang'}->[0]);
	my $row;
	while(defined($row=$sth->fetchrow_arrayref)) {
	    $this->{'data'}->{$row->[0]} = 1;
	}
	$sth->finish;
    } else {
	my $sth = $dbh->prepare("SELECT DISTINCT v.word FROM valsi v
		JOIN valsibestguesses vbg ON vbg.valsiid = v.valsiid
		WHERE vbg.langid=?");
	$sth->execute($this->{'natlang'}->[0]);
	my $row;
	while(defined($row=$sth->fetchrow_arrayref)) {
	    $this->{'data'}->{$row->[0]} = 1;
	}
	$sth->finish;
    }
    $this->{'lastrefreshed'} = time;
}

sub EXISTS {
    my $this = shift;
    my $key  = shift;
    &refreshdata($this);
    return defined($this->{'data'}->{$key});
}

sub FIRSTKEY {
    my $this = shift;

    &refreshdata($this);

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
# wee, no clean up.
}

1;
