#!/usr/local/bin/perl

use strict;
use Getopt::Long;
use Search;
use SynGraph;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'db_type=s', 'db_name=s', 'db_table=s', 'sentence_file=s', 'index_file=s@');
my $search = new Search({type => $opt{db_type}, name => $opt{db_name}, table => $opt{db_table}}, $opt{index_file});
my %sentence;


# 文データをtie
&SynGraph::tie_db($opt{sentence_file}, \%sentence) if ($opt{sentence_file});

# クエリを読み込む
while (my $query = <STDIN>) {
    chomp($query);

    if ($query) {
        # クエリのいらないものをとる
        $query =~ s/(\?|？|\!|！|．|。)$//;
        $query = &SynGraph::h2z($query);
        next unless ($query);
        
        # 検索
        my @result = $search->search($query, 100, 0.00001);
        for (my $num = 0; $num < @result; $num++) {
            print
                $num+1, "\t",
                $result[$num]->{sid}, "\t",
                $sentence{$result[$num]->{sid}}, "\t",
                $result[$num]->{score}, "\n";
            
            while (my ($key, $value) = each %{$result[$num]->{matchbp}}) {
                print $key, "\t=\t", $value, "\n" if ($key ne $value);
            }
            while (my ($key, $value) = each %{$result[$num]->{origbp}}) {
                print $key, "\t-\t", $value, "\n";
            }
        }
    }
}

# 文データをuntie
untie %sentence;
