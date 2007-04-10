#!/usr/bin/env perl

# KNPへのSYNGRAPH導入のテスト用プログラム

use strict;
use Dumpvalue;
use utf8;
use Encode;
use lib qw(../perl);
use CalcSimWithSynGraph;
use Getopt::Long;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'sentence=s', 'debug', 'log_sg', 'postprocess', 'no_case', 'relation', 'antonym');

my $syndbdir = '../syndb/i686';
my $option;
my $knp_option;
my $regnode_option;
$option->{debug} = 1 if $opt{debug};
$option->{log_sg} = 1 if $opt{log_sg};
$knp_option->{postprocess} = 1 if $opt{postprocess};
$knp_option->{no_case} = 1 if $opt{no_case};
$regnode_option->{relation} = 1 if $opt{relation};
$regnode_option->{antonym} = 1 if $opt{antonym};

my $SynGraph = new SynGraph($syndbdir, $knp_option);

if ($opt{sentence}) {
    my $input = decode('euc-jp', $opt{sentence});
    my $result = $SynGraph->{knp}->parse($input);
    print $SynGraph->OutputSynFormat($result, $regnode_option, $option);
}
else {
    my ($sid, $knp_buf);
    while (<>) {
	$knp_buf .= $_;

	if (/^EOS$/) {
	    my $result = new KNP::Result($knp_buf);
	    $result->set_id($sid) if ($sid);
	    print $SynGraph->OutputSynFormat($result, $regnode_option, $option);
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

