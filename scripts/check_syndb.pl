#!/usr/bin/env perl

# DBチェックのテスト用プログラム

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

my %opt; GetOptions(\%opt, 'synid=s', 'number=s', 'print_syngraph', 'orchid');

# SynGraphをnew
my $knp_option;
my $syndbdir = !$opt{orchid} ? '../syndb/i686' : '../syndb/x86_64';
my $SynGraph = new SynGraph($syndbdir, $knp_option);

# syndb用DBをtie
$SynGraph->tie_forsyndbcheck("$syndbdir/syndb.db", "$syndbdir/synnumber.db");

my $synid;
if ($opt{synid}) {
    $synid = decode('euc-jp', $opt{synid});
}
elsif ($opt{number}) {
    $synid = $SynGraph->{synnumber}->{$opt{number}};
}

# 同義グループに所属する語を出力
print "# S-ID:$synid\n";
my $result = $SynGraph->{syndb}->{$synid};
$result =~ s/\|/  \|  /g;
print $result, "\n";
if (defined $SynGraph->{synparent}->{$synid}) {
    foreach my $pid (keys %{$SynGraph->{synparent}->{$synid}}) {
	print "上位：$pid\n";
    }
}
if (defined $SynGraph->{synantonym}->{$synid}) {
    foreach my $aid (keys %{$SynGraph->{synantonym}->{$synid}}) {
	print "反義：$aid\n";
    }
}

if ($opt{print_syngraph}) {
    # 同義グループに所属するSYNGRAPHを出力
    foreach my $expression (split(/\|/, $SynGraph->{syndb}->{$synid})) {
	print "########################################################\n";
	my $key = "$synid,$expression";
	print "$key\n";
	print @{$SynGraph->format_syngraph($SynGraph->{syndata}->{$key})};
    }
    print "########################################################\n";
}    

