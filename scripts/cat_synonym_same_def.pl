#!/usr/bin/env perl

# 辞書からの同義表現リストをformatをそろえてつなげるスクリプトスクリプト

use strict;
use Getopt::Long;
use Dumpvalue;
use KNP;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'synonym_dic=s', 'same_diff=s', 'cat_file=s');

open(CAT, '>:encoding(euc-jp)', $opt{cat_file}) or die;
open(SYN, '<:encoding(euc-jp)', $opt{synonym_dic}) or die;
while (<SYN>) {
    print CAT $_;
}
close(SYN);

open(SDIF, '<:encoding(euc-jp)', $opt{same_diff}) or die;
while (<SDIF>) {
    next if $_ eq "\n";
    next if $_ =~ /^★/;

    print CAT $_;
}
close(SDIF);
close(CAT);
