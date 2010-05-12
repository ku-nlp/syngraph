#!/usr/bin/env perl

use strict;
use File::Basename;
use Getopt::Long;

my (%opt);
GetOptions(\%opt, 'isa', 'synonym', 'exedate=i', 'help');
&usage if $opt{help};

my $type = $opt{isa} ? 'isa' : 'synonym';
my $glob_pat = "/home/shibata/work/SynGraph/dic/calcsim/div/$type-*";
my $script = '/home/shibata/work/SynGraph/scripts/calc-similarity-synonym.sh';

foreach my $file (glob $glob_pat) {
    my $base = basename($file,'.orig');

    print "$base $script ";
    print '-i ' if $opt{isa};
    print "-e $opt{exedate}" if $opt{exedate};
    print "$file\n";
}
