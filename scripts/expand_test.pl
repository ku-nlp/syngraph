#!/usr/bin/env perl

# expansionのテスト用プログラム

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

my %opt; GetOptions(\%opt, 'synid=s', 'number=s', 'plural', 'orchid');

# SynGraphをnew
my $syndbdir = !$opt{orchid} ? '../syndb/i686' : '../syndb/x86_64';
my $sgh = new SynGraph(undef, undef);

# 入力のSYNID作成
my $synid;
if ($opt{synid}) {
    $synid = decode('euc-jp', $opt{synid});
}
elsif ($opt{number}) {
    &SynGraph::tie_cdb("$syndbdir/synnumber.cdb", $sgh->{synnumber});
    $synid = $sgh->GetValue($sgh->{synnumber}{$opt{number}});
}


# 同義グループに所属するSYNGRAPHを出力
my @result;

# DBをtie
&SynGraph::tie_mldbm("$syndbdir/syndata.mldbm", $sgh->{syndata});
&SynGraph::tie_cdb("$syndbdir/syndb.cdb", $sgh->{syndb});

my @syn_array = $sgh->expansion($synid);

foreach my $syngraph (@syn_array) {

    next if ($opt{plural} and @{$syngraph} == 1);

    print "---------------------------------------------------\n";
    Dumpvalue->new->dumpValue($syngraph);
    print "---------------------------------------------------\n";

}
