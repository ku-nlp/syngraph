#!/usr/local/bin/perl

# $Id$

use strict;
use Getopt::Long;
use SynGraph;
use CDB_File;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'knp_result=s', 'syndbdir=s', 'dbtype=s');
my $sgh = new SynGraph( undef, undef);

my $dbext = $opt{dbtype} eq 'cdb' ? 'cdb' : 'db';

my $db_option;
$db_option = { 'dbtype' => 'cdb' } if $opt{dbtype} eq 'cdb';

# synparent.mldbm、synantonym.mldbmがある場所(そこに出来た類義表現DBも出力する)
my $dir = $opt{syndbdir} ? $opt{syndbdir} : '.';

# 上位・下位関係の読み込み
# &SynGraph::retrieve_mldbm("$dir/synparent.mldbm", $sgh->{synparent});
&SynGraph::retrieve_db("$dir/synparent.$dbext", $sgh->{synparent}, $db_option);

# 反義関係の読み込み
# &SynGraph::retrieve_mldbm("$dir/synantonym.mldbm", $sgh->{synantonym});
&SynGraph::retrieve_db("$dir/synantonym.$dbext", $sgh->{synantonym}, $db_option);

# KNP結果ファイルを開く
$sgh->open_parsed_file($opt{knp_result}) or die;

# ひとつずつ読み込む
$sgh->{mode} = 'compile';
while (my $knp_result = $sgh->read_parsed_data) {
    my $sid = $knp_result->id;

    # 木を作る
    $sgh->make_tree($knp_result, $sgh->{syndata});

    # 文末BPのノードから文IDへのテーブル
    if ($sgh->{syndata}->{$sid}) {
        foreach my $node (@{$sgh->{syndata}->{$sid}->[(@{$sgh->{syndata}->{$sid}}-1)]}) {
            if ($node->{id}) {
# 		unless ($sgh->{synhead}->{$node->{id}} and
# 			grep($sid eq $_, @{$sgh->{synhead}->{$node->{id}}})) {
# 		    push(@{$sgh->{synhead}->{$node->{id}}}, $sid);
		$sgh->{synhead}{$node->{id}} .= $sgh->{synhead}{$node->{id}} ? "|$sid" : $sid unless ($sgh->{synhead}{$node->{id}} =~ /$sid/);
            }
        }
    }
}

# 類義表現DB内のマッチング→IDの付与の繰り返し
$sgh->{mode} = 'repeat';
while (keys %{$sgh->{syndata}}) {
    print STDERR scalar(localtime), "\n";

    foreach my $sid (sort keys %{$sgh->{syndata}}) {
        # SYNノードがこれ以上追加されなくなると終了
        goto COMPILE_END if ($sgh->{regnode} eq $sid);

        # 1キーワードのものはコンパイルする必要なし
        if (@{$sgh->{syndata}->{$sid}} > 1) {
            for (my $bp_num = 0; $bp_num < @{$sgh->{syndata}->{$sid}}; $bp_num++) {
		# 上位ID、反義語は張り付けない
                $sgh->make_bp($sgh->{syndata}, $sid, $bp_num);
            }
        }
    }
}

# コンパイルした類義表現DBの保存
COMPILE_END:
{
    &SynGraph::store_db("$dir/synhead.$dbext", $sgh->{synhead}, $db_option);
    &SynGraph::store_mldbm("$dir/syndata.mldbm", $sgh->{syndata});
}
