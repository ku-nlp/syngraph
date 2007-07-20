#!/usr/bin/env perl

# 辞書からの同義表現リストをformatをそろえてつなげるスクリプト

use strict;
use Getopt::Long;
use Dumpvalue;
use KNP;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'synonym_dic=s', 'same_diff=s');

open(SYN, '<:encoding(euc-jp)', $opt{synonym_dic}) or die;
while (<SYN>) {
    print $_;
}
close(SYN);

open(SDIF, '<:encoding(euc-jp)', $opt{same_diff}) or die;
while (<SDIF>) {
    next if $_ eq "\n";
    next if $_ =~ /^★/;

    print $_;
}
close(SDIF);
