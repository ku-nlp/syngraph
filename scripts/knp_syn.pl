#!/usr/bin/env perl

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

my %opt; GetOptions(\%opt, 'sentence=s', 'orchid', 'debug', 'log', 'cgi', 'postprocess', 'no_case', 'relation', 'antonym', 'hypocut_attachnode=s');

my $option;
my $knp_option;
my $regnode_option;
$option->{debug} = 1 if $opt{debug};
$option->{orchid} = 1 if $opt{orchid};
$option->{log} = 1 if $opt{log};
$option->{cgi} = 1 if $opt{cgi};
$knp_option->{postprocess} = 1 if $opt{postprocess};
$knp_option->{no_case} = 1 if $opt{no_case};
$regnode_option->{relation} = 1 if $opt{relation};
$regnode_option->{antonym} = 1 if $opt{antonym};
$regnode_option->{cgi} = 1 if $opt{cgi};
$regnode_option->{log} = 1 if $opt{log};

# 下位語数が $regnode_option->{hypocut_attachnode} 以上なら、SYNノードをはりつけないオプション
$regnode_option->{hypocut_attachnode} = $opt{hypocut_attachnode} if $opt{hypocut_attachnode};

my $syndbdir;
if ($option->{orchid}) {
    $syndbdir = '../syndb/x86_64';
}
elsif ($option->{cgi}) {
    $syndbdir = '../syndb/cgi';
}
else {
    $syndbdir = '../syndb/i686';
}

my $sgh = new SynGraph($syndbdir, $knp_option, $option);

if ($opt{sentence}) {
    my $input = decode('euc-jp', $opt{sentence});
    my $result = $sgh->{knp}->parse($input);
    print $sgh->OutputSynFormat($result, $regnode_option, $option);
}
else {
    my ($sid, $knp_buf);
    while (<>) {
	$knp_buf .= $_;

	if (/^EOS$/) {
	    my $result = new KNP::Result($knp_buf);
	    $result->set_id($sid) if ($sid);
	    print $sgh->OutputSynFormat($result, $regnode_option, $option);
	    $knp_buf = "";
	}
	elsif (/\# S-ID:(.+) KNP:/) {
	    $sid = $1;
	    $sid =~ s/\s+/ /;
	    $sid =~ s/^\s//;
	    $sid =~ s/\s$//;
	}
    }
}

