#!/usr/bin/env perl

# usage: perl -I../perl test-synonym-antonym.pl -synset /somewhere/synset.cdb -contentwdic /somewhere/juman/dic/ContentW.dic 洗浄/せんじょう 洗う/あらう

use strict;
use utf8;
binmode STDIN, ':encoding(utf8)';
binmode STDOUT, ':encoding(utf8)';
binmode STDERR, ':encoding(utf8)';
use Synonym;
use Getopt::Long;
use Encode;
use Storable qw(retrieve);

my (%opt);
GetOptions(\%opt, 'debug', 'contentwdic=s', 'synonym_storable=s', 'antonym_storable=s', 'synset_cdb=s');

my $synonym_pm = new Synonym;

my $antonym_storable;
if ($opt{antonym_storable}) {
    $antonym_storable = retrieve($opt{antonym_storable});
}

my $synonym_storable;
if ($opt{synonym_storable}) {
    $synonym_storable = retrieve($opt{synonym_storable});
}

if ($opt{contentwdic}) {
    $synonym_pm->ReadJumanDic($opt{contentwdic}); 
}

if ($opt{synset_cdb}) {
    $synonym_pm->TieCDB($opt{synset_cdb}, 'synset');
}

my $word0 = decode('utf-8', $ARGV[0]);
my $word1 = decode('utf-8', $ARGV[1]);
print "$word0 $word1\n" if $opt{debug};
 
my $is_synonym = $synonym_pm->IsSynonym($word0, $word1, $synonym_storable);
print "synonym: $is_synonym\n";

my $is_antonym = $synonym_pm->IsAntonym($word0, $word1, $antonym_storable);
print "antonym: $is_antonym\n";

my $midasi0 = $synonym_pm->GetMidasi($word0);
my $midasi1 = $synonym_pm->GetMidasi($word1);
my $mrphnum0 = $synonym_pm->GetMrphNum($word0);
my $mrphnum1 = $synonym_pm->GetMrphNum($word1);
my $is_acronym = $synonym_pm->IsAcronym($word0, $word1, $midasi0, $midasi1, $mrphnum0, $mrphnum1);
print "acronym: $is_acronym\n";
