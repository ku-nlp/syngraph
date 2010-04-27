#!/usr/bin/env perl

# $Id$

# KNPへのSYNGRAPH導入のテスト用プログラム

use strict;
use Dumpvalue;
use utf8;
use Encode;
use lib qw(../perl);
use SynGraph;
use Getopt::Long;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'sentence=s', 'orchid', 'debug', 'detail', 'log', 'cgi', 'postprocess', 'no_case', 'relation', 'antonym', 'hypocut_attachnode=s', 'fstring', 'use_make_ss', 'regist_exclude_semi_contentword', 'db_on_memory', 'dbdir=s', 'print_hypernym', 'no_regist_adjective_stem', 'print_mid', 'no_attach_synnode_in_wikipedia_entry', 'attach_wikipedia_info', 'wikipedia_entry_db=s');

my $option;
my $knp_option;
my $regnode_option;
$option->{debug} = 1 if $opt{debug};
$option->{detail} = 1 if $opt{detail};
$option->{orchid} = 1 if $opt{orchid};
$option->{log} = 1 if $opt{log};
$option->{cgi} = 1 if $opt{cgi};
$option->{store_fstring} = 1 if $opt{fstring};
$option->{use_make_ss} = 1 if $opt{use_make_ss};
$option->{db_on_memory} = 1 if $opt{db_on_memory};
$option->{print_mid} = 1 if $opt{print_mid};
$knp_option->{postprocess} = 1 if $opt{postprocess};
$knp_option->{no_case} = 1 if $opt{no_case};
$regnode_option->{relation} = 1 if $opt{relation};
$regnode_option->{antonym} = 1 if $opt{antonym};
$regnode_option->{cgi} = 1 if $opt{cgi};
$regnode_option->{log} = 1 if $opt{log};
$regnode_option->{no_attach_synnode_in_wikipedia_entry} = 1 if $opt{no_attach_synnode_in_wikipedia_entry};

$option->{regist_exclude_semi_contentword} = 1 if $opt{regist_exclude_semi_contentword};
$option->{no_regist_adjective_stem} = 1 if $opt{no_regist_adjective_stem};
$option->{attach_wikipedia_info} = 1 if $opt{attach_wikipedia_info};
$option->{wikipedia_entry_db} = $opt{wikipedia_entry_db} if $opt{wikipedia_entry_db};

# 下位語数が $regnode_option->{hypocut_attachnode} より大きければ、SYNノードをはりつけないオプション
$regnode_option->{hypocut_attachnode} = $opt{hypocut_attachnode} if $opt{hypocut_attachnode};

my $syndbdir;
if ($opt{dbdir}) {
    $syndbdir = $opt{dbdir};
}
elsif ($option->{cgi}) {
    $syndbdir = '../syndb/cgi';
}
else {
    # i686 or x86_64
    my $uname = `uname -m`;
    chomp $uname;
    $syndbdir = "../syndb/$uname";
}

my $sgh = new SynGraph($syndbdir, $knp_option, $option);

if ($opt{sentence}) {
    my $input = decode('euc-jp', $opt{sentence});
    my $result = $sgh->{knp}->parse($input);

    # 上位語を出力 (舞浜駅 -> 駅)
    if ($opt{print_hypernym}) {
	my $hypernym = $sgh->GetHypernym($result, $regnode_option, $option);
	print $hypernym, "\n" if $hypernym;
    }
    else {
	print $sgh->OutputSynFormat($result, $regnode_option, $option);
    }
}
else {
    my ($sid, $knp_buf);
    while (<>) {
	$knp_buf .= $_;

	if (/^EOS$/) {
	    my $result = new KNP::Result($knp_buf);
	    $result->set_id($sid) if (defined $sid);
	    if ($opt{print_hypernym}) {
		print $sgh->GetHypernym($result, $regnode_option, $option), "\n";
	    }
	    else {
		print $sgh->OutputSynFormat($result, $regnode_option, $option);
	    }
	    $knp_buf = "";
	}
	elsif (/\# S-ID:([^\s]+) /) {
	    $sid = $1;
	    $sid =~ s/\s+/ /;
	    $sid =~ s/^\s//;
	    $sid =~ s/\s$//;
	}
    }
}

