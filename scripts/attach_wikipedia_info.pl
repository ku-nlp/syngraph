#!/usr/bin/env perl

# $Id$

# echo 'パガニーニの主題による狂詩曲' | juman | perl -I/home/shibata/work/JICFS/perl attach_wikipedia_info.pl -dbname ../syndb/i686/wikipedia_entry_trie.db 

# # JICFS/perlが必要

use strict;
use encoding 'euc-jp';
use Juman;
use Trie;
use Getopt::Long;

my (%opt);
GetOptions(\%opt, 'dbname=s', 'usejuman', 'userepname', 'noskip');

unless ($opt{dbname}) {
    print STDERR "Please specify dbname!!\n";
    exit;
}

my $trie = new Trie(\%opt);
$trie->RetrieveDB($opt{dbname});

my $buf;
while (<>) {
    if (/\# S-ID/) {
	print;
	next;
    }

    $buf .= $_;

    if (/EOS/) {
	my $result = new Juman::Result($buf);
	my @mrphs = $result->mrph;
	print $trie->DetectString(\@mrphs, undef, { output_juman => 1 });
	print "EOS\n";
	undef $buf; 
    }
}
