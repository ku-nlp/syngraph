#!/usr/local/bin/perl

use strict;
use Getopt::Long;
use SynGraph;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'index_file=s', 'db_type=s', 'db_name=s', 'db_table=s');
my $sgh = new SynGraph;
my %tf;
my %df;
my %doclen;
my $docid_prev;
my @sids_prev;
my $ref = {};
my %node2doc;

# dfをtie
&SynGraph::tie_db('df.db', \%df);

# 文書長をtie
&SynGraph::tie_db('doclen.db', \%doclen);

# DB情報
$sgh->db_set({type => $opt{db_type}, name => $opt{db_name}, table => $opt{db_table}});

# DBに接続
$sgh->db_connect;

# 文IDのリスト取得
my @sidlist = $sgh->db_sidlist;


# データベースからSYNGRAPHを取ってきて集計する
while (@sidlist > 0) {
    # 2000個ずつデータベースから取ってくる
    my @sids = splice(@sidlist, 0, 2000);
    print STDERR $sids[0], "\n";
    $sgh->db_retrieve($ref, \@sids);

    # 集計
    foreach my $sid (@sids) {
        my $docid = (split(/,/, $sid))[0];

        # 転置インデックスを作る
        if ($docid ne $docid_prev) {
            &indexing($docid_prev);
            $docid_prev = $docid;
        }

        # tf, 文書長をカウント
        foreach my $bp (@{$ref->{$sid}}) {
            foreach my $node (@$bp) {
                my $key = $node->{id};
                $tf{$key} += $node->{score} if ($key);
            }
        }

        push(@sids_prev, $sid);
    }
}

# 最後の文書について転置インデックスを作る
&indexing($docid_prev);

# df, 文書長をuntie
untie %df;
untie %doclen;


# DBを切断
$sgh->db_disconnect;


# 保存
foreach my $nodename (keys %node2doc) {
    my $docscore;
    foreach my $docid (sort {$node2doc{$nodename}{$b} <=> $node2doc{$nodename}{$a}} keys %{$node2doc{$nodename}}) {
        $docscore .= sprintf("$docid:%.4f|", $node2doc{$nodename}{$docid});
    }
    $node2doc{$nodename} = $docscore;
}

&SynGraph::store_db($opt{index_file}, \%node2doc);





################################################################################
#                                                                              #
#                                 サブルーチン                                 #
#                                                                              #
################################################################################

#
# 転置インデックスを作成
#
sub indexing {
    my ($docid) = @_;
    my %weight;

    # 重要度計算
    foreach my $key (keys %tf) {
        $weight{$key} =
            3.0 /
            ((0.5+1.5*$doclen{$docid}/$doclen{avg_doclen}) + $tf{$key}) *
            log(($doclen{num_doc}-$df{$key}+0.5) / ($df{$key}+0.5));
        $weight{$key} = 0 if ($weight{$key} < 0);
    }
    
    # 転置インデックスを作成
    foreach my $sidp (@sids_prev) {
        foreach my $bp (@{$ref->{$sidp}}) {
            foreach my $node (@$bp) {
                my $key = $node->{id};
                $node2doc{$key}{$docid} += $node->{score} * $weight{$key} if ($key and $node->{score} * $weight{$key} > 0);
            }
        }
        delete $ref->{$sidp};
    }
    undef %tf;
    undef @sids_prev;
}
