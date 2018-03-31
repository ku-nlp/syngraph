#!/usr/bin/env perl

use strict;
use Getopt::Long;
use utf8;
binmode STDIN, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';

my %opt; GetOptions(\%opt, 'out_dir=s');

my $head = 'syndb';
my $max_jmn_num = 10000;

my $fnum = 0;
my $jmn_num = 0;
    
open(F, ">:encoding(utf-8)", "$opt{out_dir}/$head-$fnum.jmn") or die;

while (<>) {
    print F $_;
    
    if ($_ =~ /EOS/) {
	$jmn_num++;
	if ($jmn_num == $max_jmn_num) {
	    $jmn_num = 0;
	    close F;

	    $fnum++;

	    open(F, ">:encoding(utf-8)", "$opt{out_dir}/$head-$fnum.jmn") or die;
	}
    }
}

close F;
