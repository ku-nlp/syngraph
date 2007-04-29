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
$SynGraph->tie_forsyndbcheck("$syndbdir/syndb.db", "$syndbdir/synnumber.db", "$syndbdir/synchild.mldbm", 
			     "$syndbdir/log_isa.mldbm", "$syndbdir/log_antonym.mldbm");

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

# 上位、下位、反義グループを表示
my %Check_relation = ('synparent'=>'上位', 
		      'synchild'=>'下位',
		      'synantonym'=>'反義');
my %Log =  ('synparent'=>'log_isa', 
	    'synchild'=>'log_isa',
	    'synantonym'=>'log_antonym');
foreach my $rel (keys %Check_relation) {
    if (defined $SynGraph->{$rel}->{$synid}) {
	foreach my $rid (keys %{$SynGraph->{$rel}->{$synid}}) {
	    my $log;
	    my $key = ($rel eq 'synchild') ? "$rid-$synid" : "$synid-$rid";
	    foreach (keys %{$SynGraph->{$Log{$rel}}->{$key}}) {
		$log .= "<$_>";
	    }
	    print "$Check_relation{$rel}：$rid$log\n";
	}
    }
}

if ($opt{print_syngraph}) {
    # 同義グループに所属するSYNGRAPHを出力
    my %expression_cash;
    foreach my $expression (split(/\|/, $SynGraph->{syndb}->{$synid})) {
	$expression =~ s/<定義文>|<RSK>|<Web>//g;

	next if $expression_cash{$expression};

	print "########################################################\n";
	my $key = "$synid,$expression";
	print "$key\n";
	print @{$SynGraph->format_syngraph($SynGraph->{syndata}->{$key})};

	$expression_cash{$expression} = 1;
    }
    print "########################################################\n";
}    

