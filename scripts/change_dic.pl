#!/usr/local/bin/perl

use strict;
use Dumpvalue;
use Getopt::Long;
use encoding 'euc-jp'; # ���������������ʸ�����euc�ե饰����Ϳ���롣��������euc�ǽ񤯤��ȡ�����C-x Return f��
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %wordid;

my %opt; GetOptions(\%opt, 'synonym=s', 'definition=s', 'isa=s', 'antonym=s', 'synonym_change=s', 'isa_change=s', 'antonym_change=s');

open (FILE, '<:encoding(euc-jp)', $opt{definition}) || die; #  PerlIO�쥤�����ꤹ�롣�����������쥤��ϻ��Ѥ���ʤ���
while (<FILE>) {

    my $sent = $_;
    my @words = split (/\s/, $sent);
    
    foreach my $word (@words) {
	if ($word =~ /:/) {
	    my $flag;
	    foreach (@{$wordid{(split(/:/, $word))[0]}}) {
		if ($_ eq $word) {
		    $flag = 1;
		    last;
		}
	    }
	    next if ($flag);
	    push(@{$wordid{(split(/:/, $word))[0]}}, $word);

	    # ���겾̾�Ĥ��Ƥʤ���
	    foreach (@{$wordid{(split(/\//, $word))[0]}}) {
		if ($_ eq $word) {
		    $flag = 1;
		    last;
		}
	    }
	    next if ($flag);
	    push(@{$wordid{(split(/\//, $word))[0]}}, $word);
	}
    }
}
close(FILE);

open (FILE, '<:encoding(euc-jp)', $opt{synonym}) || die; #  PerlIO�쥤�����ꤹ�롣�����������쥤��ϻ��Ѥ���ʤ���
while (<FILE>) {

    my $sent = $_;
    my @words = split (/\s/, $sent);
    
    foreach my $word (@words) {
	if ($word =~ /:/) {
	    my $flag;
	    foreach (@{$wordid{(split(/:/, $word))[0]}}) {
		if ($_ eq $word) {
		    $flag = 1;
		    last;
		}
	    }
	    next if ($flag);
	    push(@{$wordid{(split(/:/, $word))[0]}}, $word);

	    # ���겾̾�Ĥ��Ƥʤ���
	    foreach (@{$wordid{(split(/\//, $word))[0]}}) {
		if ($_ eq $word) {
		    $flag = 1;
		    last;
		}
	    }
	    next if ($flag);
	    push(@{$wordid{(split(/\//, $word))[0]}}, $word);
	}
    }
}
close(FILE);

open (FILE, '<:encoding(euc-jp)', $opt{isa}) || die; #  PerlIO�쥤�����ꤹ�롣�����������쥤��ϻ��Ѥ���ʤ���
while (<FILE>) {

    my $sent = $_;
    my @words = split (/\s/, $sent);
    
    foreach my $word (@words) {
	if ($word =~ /:/) {
	    my $flag;
	    foreach (@{$wordid{(split(/:/, $word))[0]}}) {
		if ($_ eq $word) {
		    $flag = 1;
		    last;
		}
	    }
	    next if ($flag);	    
	    push(@{$wordid{(split(/:/, $word))[0]}}, $word);

	    # ���겾̾�Ĥ��Ƥʤ���
	    foreach (@{$wordid{(split(/\//, $word))[0]}}) {
		if ($_ eq $word) {
		    $flag = 1;
		    last;
		}
	    }
	    next if ($flag);	    
	    push(@{$wordid{(split(/\//, $word))[0]}}, $word);
	}
    }
}
close(FILE);

open (FILE, '<:encoding(euc-jp)', $opt{antonym}) || die; #  PerlIO�쥤�����ꤹ�롣�����������쥤��ϻ��Ѥ���ʤ���
while (<FILE>) {

    my $sent = $_;
    my @words = split (/\s/, $sent);
    
    foreach my $word (@words) {
	if ($word =~ /:/) {
	    my $flag;
	    foreach (@{$wordid{(split(/:/, $word))[0]}}) {
		if ($_ eq $word) {
		    $flag = 1;
		    last;
		}
	    }
	    next if ($flag);	    
	    push(@{$wordid{(split(/:/, $word))[0]}}, $word);

	    # ���겾̾�Ĥ��Ƥʤ���
	    foreach (@{$wordid{(split(/\//, $word))[0]}}) {
		if ($_ eq $word) {
		    $flag = 1;
		    last;
		}
	    }
	    next if ($flag);	    
	    push(@{$wordid{(split(/\//, $word))[0]}}, $word);
	}
    }
}
close(FILE);

# �����å���
# Dumpvalue->new->dumpValue(\%wordid);

open (FILE, '<:encoding(euc-jp)', $opt{synonym}) || die; #  PerlIO�쥤�����ꤹ�롣�����������쥤��ϻ��Ѥ���ʤ���
open(CHANGE, '>:encoding(euc-jp)', $opt{synonym_change}) or die;
while (<FILE>) {

    my $sent = $_;
    my @words = split (/\s/, $sent);
    
    foreach my $word (@words) {
	if ($word !=~ /:/) {
	    if ($wordid{$word}) {
		foreach (@{$wordid{$word}}) {
		    print CHANGE "$_ ";			
		}
	    }
	    else {
		print CHANGE "$word ";			
	    }
	}
	else{
	    print CHANGE "$word ";	
	}
    }
    print CHANGE "\n";
}
close(FILE);
close(CHANGE);

open (FILE, '<:encoding(euc-jp)', $opt{isa}) || die; #  PerlIO�쥤�����ꤹ�롣�����������쥤��ϻ��Ѥ���ʤ���
open(CHANGE, '>:encoding(euc-jp)', $opt{isa_change}) or die;
while (<FILE>) {

    my $sent = $_;
    my @words = split (/\s/, $sent);
    my @word0_list;
    my @word1_list;
    
    if ($words[0] !=~ /:/) {
	if ($wordid{$words[0]}) {
	    foreach (@{$wordid{$words[0]}}) {
		push @word0_list, $_;
		}
	}
	else {
	    push @word0_list, $words[0];
	    }
    }
    else{
	push @word0_list, $words[0];
    }

    if ($words[1] !=~ /:/) {
	if ($wordid{$words[1]}) {
	    foreach (@{$wordid{$words[1]}}) {
		push @word1_list, $_;
		}
	}
	else {
	    push @word1_list, $words[1];
	    }
    }
    else{
	push @word1_list, $words[1];
    }

    foreach my $wordid0 (@word0_list) {
	foreach my $wordid1 (@word1_list) {
	    print CHANGE "$wordid0 $wordid1\n";
	}
    }
}
close(FILE);
close(CHANGE);

open (FILE, '<:encoding(euc-jp)', $opt{antonym}) || die; #  PerlIO�쥤�����ꤹ�롣�����������쥤��ϻ��Ѥ���ʤ���
open(CHANGE, '>:encoding(euc-jp)', $opt{antonym_change}) or die;
while (<FILE>) {

    my $sent = $_;
    my @words = split (/\s/, $sent);
    my @word0_list;
    my @word1_list;

    if ($words[0] !=~ /:/) {
	if ($wordid{$words[0]}) {
	    foreach (@{$wordid{$words[0]}}) {
		push @word0_list, $_;
		}
	}
	else {
	    push @word0_list, $words[0];
	    }
    }
    else{
	push @word0_list, $words[0];
    }

    if ($words[1] !=~ /:/) {
	if ($wordid{$words[1]}) {
	    foreach (@{$wordid{$words[1]}}) {
		push @word1_list, $_;
		}
	}
	else {
	    push @word1_list, $words[1];
	    }
    }
    else{
	push @word1_list, $words[1];
    }

    foreach my $wordid0 (@word0_list) {
	foreach my $wordid1 (@word1_list) {
	    print CHANGE "$wordid0 $wordid1\n";
	}
    }
}
close(FILE);
close(CHANGE);
