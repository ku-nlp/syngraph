#!/usr/bin/env perl

# $Id$

use strict;
use Getopt::Long;
use File::Basename;
use Getopt::Long;

my %opt;
GetOptions(\%opt, 'outdir=s');

unless (-d $opt{outdir}) {
    print STDERR "Can't find outdir ($opt{outdir})!\n";
    exit;
}

$opt{outdir} = '.' unless $opt{outdir};

my $base = basename($ARGV[0],'.txt');
my $fnum = 1;

open(F, "> $opt{outdir}/$base-$fnum.orig") or die;

my $line = 0;
while (<>) {
    if ($line && $line % 1000 == 0) {
	close(F);
	$fnum++;
	open(F, "> $opt{outdir}/$base-$fnum.orig") or die;
    }
    $line++;
    print F $_;
}

close(F);

