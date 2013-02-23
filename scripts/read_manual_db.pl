#!/usr/bin/env perl

# $Id$

# usage: perl -I../perl read_manual_db.pl
# perl -I../perl read_manual_db.pl -isa ../dic/rsk_iwanami/isa.txt.filtered -debug -synonym ../dic/rsk_iwanami/synonym.txt.filtered -isa ../dic/rsk_iwanami/isa.txt.filtered -antonym ../dic/rsk_iwanami/antonym.txt -definition ../dic/rsk_iwanami/definition.txt

use strict;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
binmode DB::OUT, ':encoding(utf-8)';
use Encode;
use FileHandle;
use SynGraph;
use Getopt::Long;
use Configure;

my (%opt);
GetOptions(\%opt, 'synonymout=s', 'isaout=s', 'antonymout=s', 'definitionout=s', 'isa=s', 'synonym=s', 'antonym=s', 'definition=s', 'debug');

my $edit_db = $Configure::SynGraphDevelBaseDir . '/db/synonym_db_for_edit_keyrep_new.db';

my @types = ('synonym', 'isa', 'antonym', 'definition');

my (%SYNDB, %SYNDB_NEW, %FREQ);

&SynGraph::tie_mldbm($edit_db, \%SYNDB);

my (%data_before, %hypernym);
&read_synonym($opt{synonym});
&read_isa($opt{isa});
&read_antonym($opt{antonym});
&read_definition($opt{definition});

my %FILE;
unless ($opt{debug}) {
    for my $type (@types) {
	my $filename = $opt{"${type}out"};
	$FILE{$type} = new FileHandle("> $filename");
	binmode $FILE{$type}, ':encoding(utf-8)';
    }
}

my %data;
my %manual_editted;
for my $rep (keys %SYNDB) {
    # 編集されていないものはパス
    next if !defined $SYNDB{$rep}{username};

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
	print STDERR "☆id -> 1/1:1/1\n" if $opt{debug};
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

    $manual_editted{$rep} = 1;
}

for my $type (@types) {
    my $filename = $opt{"${type}out"};

    my %out;
    for my $midasi (sort keys %{$data{$type}}) {
	my $out_string;
	# 上位語の場合は下位語数を付与
	if ($type eq 'isa') {
	    my $num = defined $hypernym{$data{$type}{$midasi}[0]} ? $hypernym{$data{$type}{$midasi}[0]} : 1;
	    $out_string = "$midasi $data{$type}{$midasi}[0] $num\n";
	}
	elsif ($type eq 'antonym') {
	    for my $string (@{$data{$type}{$midasi}}) {
		push @{$out_string}, "$midasi $string\n";
	    }
	}
	else {
	    $out_string = "$midasi " . join(' ' , @{$data{$type}{$midasi}}) . "\n";
	}
	if ($opt{debug}) {
	    print "$type: $out_string";
	}
	else {
	    $out{$midasi} = $out_string;
	}
    }

    # 人手で修正されていないもの
    for my $entry (keys %{$data_before{$type}}) {
	# コップ/こっぷ:1/1:1/1
	my ($rep, $id) = split(':', $entry, 2);

	if (!defined $manual_editted{$rep}) {
	    my $out_string;
	    if ($type eq 'synonym') {
		$out_string = $entry . ' ' . join (' ', @{$data_before{$type}{$entry}}) . "\n";
	    }
	    elsif ($type eq 'isa') {
		if (!defined $hypernym{$data_before{$type}{$entry}}) {
		    print STDERR "Can't find the hypernym $data_before{$type}{$entry}\n";
		}
		$out_string = "$entry $data_before{$type}{$entry} $hypernym{$data_before{$type}{$entry}}\n";
	    }
	    elsif ($type eq 'antonym') {
		for my $string (@{$data_before{$type}{$entry}}) {
		    push @{$out_string}, "$entry $string\n";
		}
	    }
	    else {
		$out_string = "$entry $data_before{$type}{$entry}\n";
	    }

	    if ($opt{debug}) {
		print "$type: $out_string";
	    }
	    else {
		$out{$entry} = $out_string;
	    }
	}
    }

    # sortして出力
    unless ($opt{debug}) {
	for my $midasi (sort keys %out) {
	    # 反義語だけ特別処理
	    if ($type eq 'antonym') {
		for my $string (@{$out{$midasi}}) {
		    $FILE{$type}->print($string);
		}
	    }
	    else {
		$FILE{$type}->print($out{$midasi});
	    }
	}
	$FILE{$type}->close;
    }
}

sub read_synonym {
    my ($file) = @_;

    open F, "<:encoding(utf-8)", $file or die;
    while (<F>) {
	chomp;

	# 愛する/あいする:1/1:2/3 好きだ/すきだ 好む/このむ
	my ($entry, @synonyms) = split;

	$data_before{synonym}{$entry} = \@synonyms;
    }
    close F;
}

sub read_isa {
    my ($file) = @_;

    open F, "<:encoding(utf-8)", $file or die;
    while (<F>) {
	chomp;

	my ($hyponym, $hypernym, $num) = split;
	$data_before{isa}{$hyponym} = $hypernym;
	$hypernym{$hypernym} = $num;
    }
    close F;
}

sub read_antonym {
    my ($file) = @_;

    open F, "<:encoding(utf-8)", $file or die;
    while (<F>) {
	chomp;

	my ($entry, $antonym) = split;
	push @{$data_before{antonym}{$entry}}, $antonym;
    }
    close F;
}

sub read_definition {
    my ($file) = @_;

    open F, "<:encoding(utf-8)", $file or die;
    while (<F>) {
	chomp;

	my ($entry, $def) = split;
	$data_before{definition}{$entry} = $def;
    }
    close F;
}

