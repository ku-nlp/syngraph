#!/usr/bin/env perl

use encoding 'euc-jp';
use strict;

while (<>) {
    chomp;

    my @value = split;

    if (scalar @value == 2) {
	print "$_\n";;
    }
}
