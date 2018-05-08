#!/usr/local/bin/perl

use strict;
use Getopt::Long;
use SynGraph;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
binmode DB::OUT, ':encoding(utf-8)';

# 引数のチェック
die "Usage: merge_db.pl merge_db_file db_file+\n" if (@ARGV < 2);

# 変数
my $merge_db_file = shift @ARGV;
my %merge;


# マージする
foreach my $db_file (@ARGV) {
    my %index;
    &SynGraph::tie_db($db_file, \%index);
    while (my ($key, $value) = each(%index)) {
        $merge{$key} .= $value;
    }
    print STDERR $db_file, "\n";
}

# 保存
&SynGraph::store_db($merge_db_file, \%merge);
