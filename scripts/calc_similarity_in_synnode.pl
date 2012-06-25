#!/usr/bin/env perl

use strict;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
use Getopt::Long;
use CalcSimilarityByCF;
use SynGraph;

my (%opt);
GetOptions(\%opt, 'syndb=s');

my $cscf = new CalcSimilarityByCF( { skip_th => 1 });

$cscf->TieMIDBfile($Configure::CalcsimCNMidbfile);

my %syndb;
&SynGraph::retrieve_cdb($opt{syndb}, \%syndb);

for my $synid (keys %syndb) {
    next if $synid !~ /^s/;

    my @data;
    # s1150:踏ん切り/ふんぎり
    # 踏ん切り/ふんぎり:1/1:1/1[DIC]|決心/けっしん:1/1:1/1[DIC]|考えを決める[定義文]|決意/けつい:1/1:1/1[DIC]
    for my $orig (split('\|', $syndb{$synid})) {
	push @data, { orig => $orig };
    }

    next if scalar @data == 1;
    print 'SYNID:', $synid, "\n";
    print $syndb{$synid}, "\n";

    # 整形
    for my $data (@data) {
	if ($data->{orig} =~ /(.+?)([:\d\/]+)?\[(.+?)\]/) {
	    $data->{string} = $1;
	    $data->{id} = $2 if $2;
	    $data->{type} = $3;
	}
    }
    for (my $i = 0; $i < @data; $i++) {
	for (my $j = $i + 1; $j < @data; $j++) {
	    my $sim = $cscf->CalcSimilarity($data[$i]{string}, $data[$j]{string}, { method => 'SimpsonJaccard', mifilter => 1, only_one_bnst => 1});

	    print "$data[$i]{string} $data[$j]{string} $sim\n";
	}
    }
}
