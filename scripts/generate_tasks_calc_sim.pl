#!/usr/bin/env perl

# $Id$

use strict;
use File::Basename;
use Getopt::Long;
use Cwd;

my (%opt);
GetOptions(\%opt, 'isa', 'synonym', 'exedate=i', 'syngraphdir=s', 'help');
&usage if $opt{help};

my $cwd = getcwd;

my $type = $opt{isa} ? 'isa' : 'synonym';
my $glob_pat = $cwd . "/../dic/calcsim/div/$type-*";
my $script = $cwd . '/calc-similarity-synonym.sh';

foreach my $file (glob $glob_pat) {
    my $base = basename($file,'.orig');

    print "$base $script";
    print ' -i' if $opt{isa};
    print " -e $opt{exedate}" if $opt{exedate};
    print " -s $opt{syngraphdir}" if $opt{syngraphdir};
    print " $file\n";
}
