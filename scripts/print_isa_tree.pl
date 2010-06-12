#!/usr/bin/env perl

# $Id$

use strict;
use encoding 'euc-jp';
use Getopt::Long;
use Juman;

my (%opt);
GetOptions(\%opt, 'max_child_num=i', 'category_sort');

my $isa_wikipedia_file = '../dic_change/isa_wikipedia.txt';

&read_wikipedia_isa;

my %data;
sub read_wikipedia_isa {
    open F, "<:encoding(euc-jp)", $isa_wikipedia_file or die;

    # µþÀ®ÄÅÅÄ¾Â±Ø ±Ø/¤¨¤­ 10921
    while (<F>) {
	chomp;

	my ($hyponym, $hypernym, $num) = split("\t", $_);
	push @{$data{$hypernym}{children}}, $hyponym;
	$data{$hyponym}{parent}{$hypernym} = 1;
    }
}

if ($opt{category_sort}) {
    my $juman = new Juman;
    for my $string (keys %data) {
	next if defined $data{$string}{parent};

	my $midasi = (split('/', $string))[0];
	my $result = $juman->analysis($midasi);

	my %category;
	my $last_mrph = ($result->mrph)[-1];

	&regist_category($last_mrph, \%category);

	# Æ±·Á
	for my $doukei ($last_mrph->doukei) {
	    &regist_category($doukei, \%category);
	}

	my $cat;
	if (scalar keys %category > 0) {
	    $cat = join(';', sort keys %category);
	} else {
	    $cat = 'Ìµ';
	}

	$data{$string}{category} = $cat;
    }
}

# »Ò¶¡¤Î¿ô¤òµ­Ï¿
for my $string (keys %data) {
    $data{$string}{child_num} = defined $data{$string}{children} ? scalar @{$data{$string}{children}} : 0;
}

my $pre_category;
for my $string (sort { $opt{category_sort} ? $data{$a}{category} cmp $data{$b}{category} || $data{$b}{child_num} <=> $data{$a}{child_num}
		       : $data{$b}{child_num} <=> $data{$a}{child_num} } keys %data) {
    next if defined $data{$string}{parent};

    print "¡ú $data{$string}{category}\n\n" if $data{$string}{category} ne $pre_category;
    &display($string, '');
    print "\n";
    $pre_category = $data{$string}{category};
}


sub display {
    my ($string, $mark) = @_;

    my @marks = split(//,$mark);

    my $lastm = pop(@marks);

    &print_mark(\@marks, $lastm);

    print $string;

    if (!defined $data{$string}{parent}) {
	print " [$data{$string}{child_num}]";
    }
    print "\n";
    if (defined $data{$string}{children}) {
	my @children = sort { $data{$b}{child_num} <=> $data{$a}{child_num} } @{$data{$string}{children}};
	my $last_child = $children[-1];

	my $print_child_num = 0;
	foreach my $child (@children) {
	    if ($child ne $last_child) {
		&display($child, $mark . '0'); 
		$print_child_num++;
	    }

	    if ($opt{max_child_num} && $print_child_num == $opt{max_child_num}) {
		&print_mark([split(//, $mark)], '1');
		print "...\n";
		return;
	    }
	}
	&display($last_child, $mark . '1') if (defined($last_child));
    }
}

sub print_mark {
    my ($marks, $lastm) = @_;

    foreach my $item (@$marks) {
	if ($item eq "1") {
	    print "¡¡¡¡";
	} else {
	    print "¨¢¡¡";
	}
    }
    if (defined($lastm)) {
	if ($lastm eq "1") {
	    print "¨¦¨¡";
	} else {
	    print "¨§¨¡";
	}
    }
}

# ¥«¥Æ¥´¥ê¾ðÊó¤òÅÐÏ¿
sub regist_category {
    my ($mrph, $category) = @_;

    if ($mrph->imis =~ /¥«¥Æ¥´¥ê:([^\"\s]+)/) {
	my $string = $1;
	for my $cat (split(/;/, $string)) {
	    $category->{$cat} = 1;
	}
    }
}
