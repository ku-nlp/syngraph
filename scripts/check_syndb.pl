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
my $sgh = new SynGraph($syndbdir, $knp_option);

# syndb用DBをtie
$sgh->tie_forsyndbcheck("$syndbdir/syndb.cdb", "$syndbdir/synnumber.cdb", "$syndbdir/synchild.cdb", 
			     "$syndbdir/log_isa.cdb", "$syndbdir/log_antonym.cdb");

my $synid;
if ($opt{synid}) {
    $synid = decode('euc-jp', $opt{synid});
}
elsif ($opt{number}) {
    $synid = $sgh->GetValue($sgh->{synnumber}{$opt{number}});
}

# 同義グループに所属する語を出力
print "# S-ID:$synid\n";
my $result = $sgh->GetValue($sgh->{syndb}{$synid});
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
    if (defined $sgh->{$rel}{$synid}) {
	foreach my $rid (split(/\|/, $sgh->GetValue($sgh->{$rel}{$synid}))) {
	    # 上位グループは下位語数つき
	    ($rid, my $num) = split(/,/, $rid);
	    my $rid_out = $num ? $rid . "<下位語数$num>" : $rid;

	    # {上位|下位|反義}グループの中身
	    my ($flag, $rid_list);
	    my $result = $sgh->GetValue($sgh->{syndb}{$rid});
	    foreach my $expression (split (/\|/, $result)) {
		$expression =~ s/<(定義文|RSK|Web)>$//;
		$rid_list .= $flag ? "|$expression" : $expression;
		$flag = 1;
	    }
	    
	    # {上位|下位|反義}のログ
	    my $log;
	    my $key = ($rel eq 'synchild') ? "$rid-$synid" : "$synid-$rid";
 	    foreach (split(/\|/, $sgh->GetValue($sgh->{$Log{$rel}}{$key}))) {
 		$log .= "<$_>";
 	    }
 	    print "$Check_relation{$rel}：$rid_out<$rid_list>[関係ログ]$log\n";
	}
    }
}

if ($opt{print_syngraph}) {
    # 同義グループに所属するSYNGRAPHを出力
    my %expression_cash;
    foreach my $expression (split(/\|/, $sgh->GetValue($sgh->{syndb}{$synid}))) {
	$expression =~ s/<定義文>|<RSK>|<Web>//g;

	next if $expression_cash{$expression};

#	print "########################################################\n";
	print "--------------------------------------------------------\n";
	my $key = "$synid,$expression";
	print "$key\n";
	print @{$sgh->format_syngraph($sgh->{syndata}{$key})};

	$expression_cash{$expression} = 1;
    }
#    print "########################################################\n";
    print "--------------------------------------------------------\n";
}    

