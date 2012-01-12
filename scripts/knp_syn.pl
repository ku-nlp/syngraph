#!/usr/bin/env perl

# $Id$

# KNPへのSYNGRAPH導入のテスト用プログラム

use strict;
use Dumpvalue;
use utf8;
use Encode;
use POSIX;
use lib qw(../perl);
use SynGraph;
use Getopt::Long;

my %opt; GetOptions(\%opt, 'sentence=s', 'debug', 'detail', 'log', 'cgi', 'postprocess', 'no_case', 'relation', 'antonym', 'hypocut_attachnode=s', 'fstring', 'use_make_ss', 'regist_exclude_semi_contentword', 'db_on_memory', 'dbdir=s', 'print_hypernym', 'no_regist_adjective_stem', 'print_mid', 'no_attach_synnode_in_wikipedia_entry', 'attach_wikipedia_info', 'wikipedia_entry_db=s', 'relation_recursive', 'force_match=s', 'word_basic_unit', 'imi_list_db=s', 'encoding=s', 'crlf', 'wsd', 'wsd_data_dir=s');

my $encoding = $opt{encoding} ? ":encoding($opt{encoding})" : ':encoding(utf-8)'; # default encoding is utf-8
$encoding .= ':crlf' if $opt{crlf};
binmode STDIN, $encoding;
binmode STDOUT, $encoding;
binmode STDERR, $encoding;
binmode DB::OUT, $encoding;

my $option;
my $knp_option;
my $regnode_option;
$option->{debug} = 1 if $opt{debug};
$option->{detail} = 1 if $opt{detail};
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
$regnode_option->{relation_recursive} = 1 if $opt{relation_recursive};

$option->{regist_exclude_semi_contentword} = 1 if $opt{regist_exclude_semi_contentword};
$option->{no_regist_adjective_stem} = 1 if $opt{no_regist_adjective_stem};
$option->{attach_wikipedia_info} = 1 if $opt{attach_wikipedia_info};
$option->{wikipedia_entry_db} = $opt{wikipedia_entry_db} if $opt{wikipedia_entry_db};
$option->{imi_list_db} = $opt{imi_list_db} if $opt{imi_list_db};
$option->{force_match}{$opt{force_match}} = 1 if $opt{force_match};
$option->{get_content_word_ids} = 1 if $opt{word_basic_unit};
$option->{word_basic_unit} = 1 if $opt{word_basic_unit};

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
    my $uname = (POSIX::uname())[4];
    $syndbdir = "../syndb/$uname";
}

my ($WSD, %wsd_opt);
if ($opt{wsd}) {
    $opt{wsd_data_dir} = '../data' unless $opt{wsd_data_dir};

    $wsd_opt{window_size}         = 20;
    $wsd_opt{tagigo_db_file}      = "$opt{wsd_data_dir}/tagigo.db";
    $wsd_opt{basic_word_file}     = "$opt{wsd_data_dir}/basic_words_10000";
    $wsd_opt{stop_word_list}      = "$opt{wsd_data_dir}/stword/stop_words"; 
    $wsd_opt{cooc_file}           = "$opt{wsd_data_dir}/coocdb.bin";
    $wsd_opt{gogi_prob_file}      = "$opt{wsd_data_dir}/data_wiki/word-prob-list.txt";
    $wsd_opt{weight_of_gogi_prob} = 0.3;

    require WSD2;
    $WSD = new WSD2(\%wsd_opt);
}

my $sgh = new SynGraph($syndbdir, $knp_option, $option);

if ($opt{sentence}) {
    my $input = decode('utf-8', $opt{sentence});
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
    my ($sid, $pre_aid, $aid, $knp_buf, @results);
    while (<>) {
	$knp_buf .= $_;

	if (/^EOS$/) {
	    my $result = new KNP::Result($knp_buf);
	    $result->set_id($sid) if (defined $sid);
	    if ($opt{wsd}) {
		# 記事IDが変わったら多義性解消をする
		if ($pre_aid && $aid ne $pre_aid) {
		    $WSD->run(\@results, \%wsd_opt);
		    for my $result (@results) {
			print $sgh->OutputSynFormat($result, $regnode_option, $option);
		    }
		    @results = ();
		}
		push @results, $result;
		$pre_aid = $aid;
	    }
	    elsif ($opt{print_hypernym}) {
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
	    if ($sid =~ /^(.+)-\d+$/) {
		$aid = $1;
	    }
	}
    }

    if ($opt{wsd}) {
	$WSD->run(\@results, \%wsd_opt);
	for my $result (@results) {
	    print $sgh->OutputSynFormat($result, $regnode_option, $option);
	}
    }
}

