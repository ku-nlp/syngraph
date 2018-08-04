#!/usr/bin/env perl

# $Id$

# 曖昧性のあるひらがなの代表表記を含む文を抽出する

# usage: echo '蕎麦を食べた' | juman | perl extract_han_includes_disambiguate_hiragana.pl --db ../db/hiragana_disambiguate.cdb 

use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
binmode DB::OUT, ':encoding(utf-8)';
use Encode;
use Getopt::Long;
use CDB_File;
use Juman;

my (%opt);
GetOptions(\%opt, 'db=s', 'debug');

my %hiragana2han;
my $db =  tie %hiragana2han, 'CDB_File', "$opt{db}" or die;

my %han2hiragana;

foreach my $hiragana (keys %hiragana2han) {
    $hiragana = decode('utf8', $hiragana);
    foreach my $han (split('\?', decode('utf8', $hiragana2han{$hiragana}))) {
	$han2hiragana{$han} = $hiragana;
    }
}

while (<>) {
    $buf .= $_;

    if (/EOS/) {
	my $result = new Juman::Result($buf);
	my $sentence = &get_sentence($result);
	foreach my $mrph ($result->mrph) {
	    my $repname = $mrph->repname;

	    if ($repname && defined $han2hiragana{$repname}) {
		print "$han2hiragana{$repname} $repname $sentence\n";
	    }
	}
	$buf = '';
    }
}

sub get_sentence {
    my ($result) = @_;

    my $sentence;
    foreach my $mrph ($result->mrph) {
	$sentence .= $mrph->midasi;
    }
    return $sentence;
}

untie %hiragana2han;
