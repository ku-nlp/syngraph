#!/usr/bin/env perl

# $Id$

# formattedファイルにおいて、見出しからアドレスへのデータベースを作る

use strict;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
use CDB_File;
use Getopt::Long;

my (%opt);
GetOptions(\%opt, 'dbfile=s', 'quiet', 'help');
&usage if $opt{help};

open F, "<:encoding(euc-jp)", $ARGV[0] or die;

my $db;
if ($opt{dbfile}) {
    $db =  new CDB_File("$opt{dbfile}", "$opt{dbfile}.$$") or die $!;
}

my ($length, $V, %yomi2verb);

while (<F>) {
    if (/<見出し>(.+)/) {
	$V = $1;

	# オンエア/おんえあ:動:A
	if ($V !~ /(?:動|形|判):/) {
	    my ($midasi, $yomi, $type) = ($V =~/(.+?)\/(.+?):(.+?)$/);

	    print STDERR "$V $length\n" unless $opt{quiet};
	    $yomi2verb{$V} = $length;
	}
    }
    $length = tell F;
}

if ($opt{dbfile}) {
    foreach my $yomi (keys %yomi2verb) {
	$db->insert($yomi, $yomi2verb{$yomi});
    }
    $db->finish;
}
