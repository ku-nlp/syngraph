#!/usr/bin/env perl

# $Id$

# 同義表現リストから重複エントリを除くスクリプト

use strict;
use Getopt::Long;
use KNP;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'rnsame', 'debug', 'synonym_web=s', 'log_merge=s', 'change');

my $knp = new KNP(-Option => '-tab -dpnd');

my (%data, %allword);

my $same_counter = 0;
my $dup_counter = 0;
my $rnsame_counter = 0;

open(SYN, '<:encoding(euc-jp)', $opt{synonym_web}) or die;
open(LM, '>:encoding(euc-jp)', $opt{log_merge}) or die;    
while (<SYN>) {
    chomp;
    my ($word1, $word2) = split;

    if ($word1 eq $word2) {
	print LM "★same entry synonym_web: $word1, $word2\n";
	$same_counter++;
	next;
    }

    if ($word1 gt $word2) {
	my $tmp = $word1;
	$word1 = $word2;
	$word2 = $tmp;
    }

    if (defined $data{$word1}{$word2}) {
	print STDERR "★duplicate entry synonym_web: $word1, $word2\n";
	$dup_counter++;
    }
    else {
	$data{$word1}{$word2} = 1;

	# 代表表記が同じ
	if ($opt{rnsame} && &GetRepname($word1) && &GetRepname($word1) eq &GetRepname($word2)) {
	    print STDERR "☆REPNAME SAME synonym_web: $word1, $word2\n";
	    $rnsame_counter++;
	    next;
	}

	print "$word1\t$word2\n";
    }
}
print LM "same entry:\t$same_counter\n" if $same_counter;
print LM "duplicate entry:\t$dup_counter\n" if $dup_counter;
print LM "rnsame entry:\t$rnsame_counter\n" if $rnsame_counter;
close(LM);
close(SYN);

# 代表表記を得る
sub GetRepname {
    my ($word) = @_;

    my $result = $knp->parse($word);

    if (scalar ($result->bnst) == 1) {
	return ($result->bnst)[0]->repname;
    }
    else {
	return '';
    }
}

