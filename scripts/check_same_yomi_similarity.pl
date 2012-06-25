#!/usr/bin/env perl

use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';

while (<>) {
    my $line = $_;

    my ($word1, $word2, $freq1, $freq2, $sim) = split;

    my $yomi1 = (split('/', $word1))[1];
    my $yomi2 = (split('/', $word2))[1];

    my $head1 = substr($yomi1, 0, 1);
    my $head2 = substr($yomi2, 0, 1);

    print $line if $head1 eq $head2;
#    print "$word1 $word2 $head1 $head2\n";
}
