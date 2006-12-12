#!/usr/local/bin/perl

use strict;
use Getopt::Long;
use SynGraph;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'text_data=s', 'db_type=s', 'db_name=s', 'db_table=s');
my $sgh = new SynGraph;


# 類義表現DBの読み込み
$sgh->retrieve_syndb;

# KNP結果ファイルを開く
$sgh->open_parsed_file($opt{text_data}) or die;

# DB情報
$sgh->db_set({type => $opt{db_type}, name => $opt{db_name}, table => $opt{db_table}});

# DBに接続
$sgh->db_connect(1);

# ひとつずつ読み込む
while (my $knp_result = $sgh->read_parsed_data) {
    my $sid = $knp_result->id;
    my $tree_ref = {};
    print STDERR $sid, "\n";

    # IREX用(95年8/23, 8/24日分は重複があるので除外)
    next if ($sid =~ /^95082(3|4)\d\d\d,\d+$/);

    # SYNGRAPHを作成
    $sgh->make_sg($knp_result, $tree_ref, $sid);

    # DBに保存
    if ($tree_ref->{$sid}) {
        $sgh->db_register($tree_ref, $sid);
    }
}

# DBを切断
$sgh->db_disconnect;
