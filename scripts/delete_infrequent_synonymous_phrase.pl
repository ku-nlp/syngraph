#!/usr/bin/env perl

# $Id$

# usage: cat ../dic/rsk_iwanami/definition.txt | perl count_synonym_phrase.pl ../dic/rsk_iwanami/definition_count.txt
# usage: cat ../dic/rsk_iwanami/definition.txt | perl delete_infrequent_synonymous_phrase.pl -th 0 -print_count ../dic/rsk_iwanami/definition_count.txt  | sort -k 3 -nr

use strict;
use encoding 'euc-jp';
binmode STDERR, ':encoding(euc-jp)';
use Getopt::Long;

my %opt;
GetOptions(\%opt, 'th=i', 'print_count', 'debug');

$opt{th} = 100 unless $opt{th};

my %data;

#  237585 !! s776:染める/そめる,仕事を始める[定義文]
open(F, '<:encoding(euc-jp)', $ARGV[0]) or die;
while (<F>) {
    chomp;

    my ($count, undef, $string) = split;

    if ($string =~/(.+?),(.+?)\[定義文\]/) {
	my $synid = $1;
	my $phrase = $2;

	$data{$phrase} = $count;
    }
}
close F;

while (<STDIN>) {
    chomp;

    my $line = $_;

    my ($string1, $string2) = split(' ', $line, 2);

    $string2 =~ s/。$//;
    $string2 =~ s/こと$//;
    $string2 =~ s/所$//;

    if (defined $data{$string2}) {
	next if $data{$string2} < $opt{th};
	if ($opt{print_count}) {
	    print "$string1 $string2 $data{$string2}\n";
	}
	else {
	    print "$line\n";
	}
    }
    else {
	print STDERR "!: $string1 $string2\n" if $opt{debug};
    }
}


