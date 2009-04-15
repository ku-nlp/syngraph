#!/usr/bin/env perl

use strict;
use encoding 'euc-jp';
binmode STDERR, ':encoding(euc-jp)';

my %data;
#  237585 !! s776:染める/そめる,仕事を始める[定義文]
while (<STDIN>) {
    chomp;

    my ($count, undef, $string) = split;

    if ($string =~/(.+?),(.+?)\[定義文\]/) {
	my $synid = $1;
	my $phrase = $2;

	$data{$phrase} = $count;
    }
}

open(F, '<:encoding(euc-jp)', $ARGV[0]) or die;
while (<F>) {
    chomp;

    my ($string1, $string2) = split(' ', $_, 2);

    $string2 =~ s/。$//;
    $string2 =~ s/こと$//;
    $string2 =~ s/所$//;

    if (defined $data{$string2}) {
	print "$string1 $string2 $data{$string2}\n";
    }
    else {
	print STDERR "!: $string1 $string2\n";
    }
}
close F;
