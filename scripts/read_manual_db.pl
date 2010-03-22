#!/usr/bin/env perl

# $Id$

# usage: perl -I../perl read_manual_db.pl

use strict;
use encoding 'euc-jp';
binmode STDERR, ':encoding(euc-jp)';
use Encode;
use FileHandle;
use SynGraph;
use Getopt::Long;
use Constant;

my (%opt);
GetOptions(\%opt, 'synonymout=s', 'isaout=s', 'antonymout=s', 'definitionout=s', 'isa=s', 'debug');

my $edit_db = $Constant::SynGraphBaseDir . '/db/synonym_db_for_edit_keyrep_new.db';

my @types = ('synonym', 'isa', 'antonym', 'definition');

my (%SYNDB, %SYNDB_NEW, %FREQ);

&SynGraph::tie_mldbm($edit_db, \%SYNDB);

my %hypernym;
# 下位語数取得
&read_isa($opt{isa});

my %FILE;
unless ($opt{debug}) {
    for my $type (@types) {
	my $filename = $opt{"${type}out"};
	$FILE{$type} = new FileHandle("> $filename");
	binmode $FILE{$type}, ':encoding(euc-jp)';
    }
}

my %data;
for my $rep (keys %SYNDB) {
    print STDERR "★$rep\n" if $opt{debug};

    my $id; 
    if (defined $SYNDB{$rep}{elements}) {
	for my $element (@{$SYNDB{$rep}{elements}}) {
	    if ($element->{type} ne 'nouse') {
		# origtypeがdefinition
		my $type = $element->{origtype} eq 'definition' ? 'definition' : $element->{type};
		push @{$data{$type}{"$element->{word}:$element->{id}"}}, $element->{definition};
		# $FILE{$element->{type}}->print("$element->{word}:$element->{id} $element->{definition}\n");
		$id = $element->{id};
	    }
	}
    }

    # $idが空でambiguityがundefなら1:1/1:1とみなす
    if (!defined $id && !defined $SYNDB{$rep}{ambiguity}) {
	print "☆id -> 1/1:1/1\n";
	$id = '1/1:1/1';
    }

    my ($tyumidasi_num, $komidasi_num);

    if ($id) {
	if ($id =~ /\d\/(\d):\d\/(\d)/) {
	    ($tyumidasi_num, $komidasi_num) = ($1, $2);
	}
	else {
	    print "Error $id\n";
	}
    }
    if (defined $SYNDB{$rep}{add}) {
	foreach my $type (keys %{$SYNDB{$rep}{add}}) {
	    my $string = $SYNDB{$rep}{add}{$type};
	    # ユーザー名を取り除く
	    $string =~ s/\((?:kuro|kawahara|shinzato|shibata|nikaido|ishikawa)\)//g;

	    for my $word (split(/\s/, $string)) {
		print STDERR "Add:$type $word\n" if $opt{debug};

		my ($newword_komidashi_id, $newword_tyumidashi_id, $newword_id_all);
		if ($word =~ s/:(\d+):(\d+)$//) {
		    $newword_tyumidashi_id = $1;
		    $newword_komidashi_id = $2;
		}
		elsif ($word =~ s/:(\d+)$//) {
		    $newword_komidashi_id = $1;
		}
		elsif ($word =~ s/:(\d+)\/(\d+)$//) {
		    $newword_komidashi_id = $1;
		}

		# 多義語の扱い
		next if $komidasi_num > 5 || ($komidasi_num == 5 && $newword_komidashi_id > 1) || ($komidasi_num == 4 && $newword_komidashi_id > 2);

		if ($id eq '1/1:1/1') {
		    $newword_id_all = $id;
		}
		else {
		    if ($tyumidasi_num == 1) {
			if ($newword_komidashi_id && !$newword_tyumidashi_id) {
			    $newword_id_all = "1/1:$newword_komidashi_id/$komidasi_num";
			}
		    }
		    elsif ($tyumidasi_num > 1) {
			if ($newword_komidashi_id && $newword_tyumidashi_id) {
			    $newword_id_all = "$newword_tyumidashi_id/$tyumidasi_num:$newword_komidashi_id/$komidasi_num";
			}
		    }

		}

		if ($newword_id_all) {
		    print STDERR "☆Add $word to $rep:$newword_id_all\n" if $opt{debug};
		    push @{$data{$type}{"$rep:$newword_id_all"}}, $word;
		}
		else {
		    print STDERR "!! Can't Add\n" if $opt{debug};
		}
	    }
	}
    }
}

for my $type (@types) {
    my $filename = $opt{"${type}out"};
    for my $midasi (sort keys %{$data{$type}}) {
	my $out_string;
	if ($type eq 'isa') {
	    my $num = defined $hypernym{$data{$type}{$midasi}[0]} ? $hypernym{$data{$type}{$midasi}[0]} : 1;
	    $out_string = "$midasi $data{$type}{$midasi}[0] $num\n";
	}
	else {
	    $out_string = "$midasi " . join(' ' , @{$data{$type}{$midasi}}) . "\n";
	}
	if ($opt{debug}) {
	    print "$type: $out_string";
	}
	else {
	    $FILE{$type}->print($out_string); 
	}
    }
    $FILE{$type}->close unless $opt{debug};
}

sub read_isa {
    my ($file) = @_;

    open F, "<:encoding(euc-jp)", $file or die;
    while (<F>) {
	chomp;

	my ($hyponym, $hypernym, $num) = split;
	$hypernym{$hypernym} = $num;
    }
    close F;
}
