#!/usr/local/bin/perl

# $Id$

use strict;
use Getopt::Long;
use SynGraph;
use CDB_File;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
binmode DB::OUT, ':encoding(utf-8)';

print STDERR scalar(localtime), "SYNGRAPH化開始\n";
my %opt; GetOptions(\%opt, 'knp_result=s', 'syndbdir=s', 'syndb_inputdir=s', 'option=s');
my $sgh = new SynGraph( undef, undef);

# synparent.mldbm、synantonym.mldbmがある場所(そこに出来た類義表現DBも出力する)
my $dir = $opt{syndbdir} ? $opt{syndbdir} : '.';
my $inputdir = $opt{syndb_inputdir} ? $opt{syndb_inputdir} : $opt{syndbdir} ? $opt{syndbdir} : '.';

# オプション
my $option ={};
$option->{$opt{option}}=1 if (defined $opt{option});

# 上位・下位関係の読み込み
&SynGraph::retrieve_cdb("$inputdir/synparent.cdb", $sgh->{synparent});

# 反義関係の読み込み
&SynGraph::retrieve_cdb("$inputdir/synantonym.cdb", $sgh->{synantonym});

# KNP結果ファイルを開く
$sgh->open_parsed_file($opt{knp_result}) or die;

# ひとつずつ読み込む
$sgh->{mode} = 'compile';
while (my $knp_result = $sgh->read_parsed_data) {
    my $sid = $knp_result->id;

    # s31516:晴れ上がる/はれあがる,晴れ上がる/はれあがる:1/1:1/1[DIC] JUMAN:6.0-20080519 KNP:3.0-20090617 DATE:2009/07/28 SCORE:-6.40612
    # からスペース以下を除く
    $sid = (split(' ', $sid))[0];

    # 文字化け対策
    next if $sid =~ /\?/;

    # 木を作る
    $sgh->make_tree($knp_result, $sgh->{syndata}, $option);

    # 文末BPのノードから文IDへのテーブル
    if ($sgh->{syndata}->{$sid}) {
        foreach my $node (@{$sgh->{syndata}->{$sid}->[(@{$sgh->{syndata}->{$sid}}-1)]{nodes}}) {
            if ($node->{id}) {
		# 文末の基本句の子供数の最小値を得る
		my $child_num_min = &SynGraph::get_child_num_min($sgh->{syndata}->{$sid});
		unless (grep($sid eq $_->{mid}, @{$sgh->{synhead}{$node->{id}}{$child_num_min}})) {
		    my $synid = (split(/,/, $sid))[0];
		    push @{$sgh->{synhead}{$node->{id}}{$child_num_min}}, { mid => $sid, synid => $synid };
		}
	    }
        }
    }
}

# 類義表現DB内のマッチング→IDの付与の繰り返し
$sgh->{mode} = 'repeat';
while (keys %{$sgh->{syndata}}) {
    print STDERR scalar(localtime), "SYNノード付与開始\n";

    foreach my $sid (sort keys %{$sgh->{syndata}}) {

	next if $sid =~ /Wikipedia/;
        # SYNノードがこれ以上追加されなくなると終了
        goto COMPILE_END if ($sgh->{regnode} eq $sid);

        # 1キーワードのものはコンパイルする必要なし
        if (@{$sgh->{syndata}{$sid}} > 1) {
            for (my $bp_num = 0; $bp_num < @{$sgh->{syndata}{$sid}}; $bp_num++) {
		# 上位ID、反義語は張り付けない
                $sgh->make_bp($sgh->{syndata}, $sid, $bp_num, undef, $option);
            }
        }
    }
}

# コンパイルした類義表現DBの保存
COMPILE_END:
{
    &SynGraph::store_cdb("$dir/synhead.cdb", $sgh->{synhead}, 'synhead');
    &SynGraph::store_mldbm("$dir/syndata.mldbm", $sgh->{syndata});
}

