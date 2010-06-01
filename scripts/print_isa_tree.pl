#!/usr/bin/env perl

# $Id$

use strict;
use encoding 'euc-jp';

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

for my $string (keys %data) {
    next if defined $data{$string}{parent};

    &display($string, '');
}

sub display {
    my ($string, $mark) = @_;

    my @marks = split(//,$mark);

    my $lastm = pop(@marks);

    foreach my $item (@marks) {
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

    print $string, "\n";
    my $last_child = $data{$string}{children}[-1];
    foreach my $child (@{$data{$string}{children}}) {
	&display($child, $mark . '0') if $child ne $last_child;
    }
    &display($last_child, $mark . '1') if (defined($last_child));
}
