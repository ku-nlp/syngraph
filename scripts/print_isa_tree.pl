#!/usr/bin/env perl

# $Id$

use strict;
use encoding 'euc-jp';
use Getopt::Long;
use Juman;

my (%opt);
GetOptions(\%opt, 'max_child_num=i', 'min_hypo_num=i', 'category_child_max_num=i', 'category_sort', 'dic', 'cndbfile=s', 'dfth=i', 'print_frequency');

my $isa_file = '../dic_change/isa.txt';
my $isa_wikipedia_file = '../dic_change/isa_wikipedia.txt';

$opt{dfth} = 1000000 unless $opt{dfth};

&read_isa if $opt{dic};
&read_wikipedia_isa;

# 複合名詞データベース
my %cn2df;
if ($opt{cndbfile}) {
    require CDB_File;
    tie %cn2df, 'CDB_File', $opt{cndbfile} or die;
}

my %data;
sub read_isa {
    open F, "<:encoding(euc-jp)", $isa_file or die;

    while (<F>) {
	chomp;

	# あくどい/あくどい:1/1:1/2 感じがする 11
	my ($hyponym, $hypernym, $num) = split(' ', $_);
	$hyponym = (split(':', $hyponym))[0];
	$hypernym = (split(':', $hypernym))[0];
	next if $hypernym eq $hyponym;
	push @{$data{$hypernym}{children}}, $hyponym if ! grep $_ eq $hyponym, @{$data{$hypernym}{children}}; 
	$data{$hyponym}{parent}{$hypernym} = 1;
    }
}

sub read_wikipedia_isa {
    open F, "<:encoding(euc-jp)", $isa_wikipedia_file or die;

    # 京成津田沼駅 駅/えき 10921
    while (<F>) {
	chomp;

	my ($hyponym, $hypernym, $num) = split("\t", $_);
	push @{$data{$hypernym}{children}}, $hyponym;
	$data{$hyponym}{parent}{$hypernym} = 1;
    }
}

if ($opt{cndbfile}) {
    for my $string (keys %data) {
	next if defined $data{$string}{parent};

	my $midasi = $string =~ /\// ? (split('/', $string))[0] : $string;
	my $df = $cn2df{"$midasi@"};

	if ($df > $opt{dfth}) {
	    for my $child ($data{$string}{children}) {
		delete $data{$child}{parent}{$string};
	    }
	    delete $data{$string}{children};
	}
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

	# 同形
	for my $doukei ($last_mrph->doukei) {
	    &regist_category($doukei, \%category);
	}

	my $cat;
	if (scalar keys %category > 0) {
	    $cat = join(';', sort keys %category);
	} else {
	    $cat = '無';
	}

	$data{$string}{category} = $cat;
    }
}

# 子供の数を記録
for my $string (keys %data) {
    $data{$string}{child_num} = defined $data{$string}{children} ? scalar @{$data{$string}{children}} : 0;
}

my $pre_category;
my %print_category_num;
for my $string (sort { $opt{category_sort} ? $data{$a}{category} cmp $data{$b}{category} || $data{$b}{child_num} <=> $data{$a}{child_num}
		       : $data{$b}{child_num} <=> $data{$a}{child_num} } keys %data) {
    next if defined $data{$string}{parent};

    print "★ $data{$string}{category}\n\n" if $data{$string}{category} ne $pre_category;

    # 最上位
    if (!defined $data{$string}{parent} && $opt{min_hypo_num} && $data{$string}{child_num} < $opt{min_hypo_num}) {
	next;
    }

    if ($opt{category_child_max_num} && $print_category_num{$data{$string}{category}} == $opt{category_child_max_num}) {
	next;
    }

    &display($string, '');
    print "\n";
    $print_category_num{$data{$string}{category}}++;

    $pre_category = $data{$string}{category};
}

if ($opt{cndbfile}) {
    untie %cn2df;
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
    if ($opt{cndbfile}) {
	my $midasi = $string =~ /\// ? (split('/', $string))[0] : $string;
	my $df = $cn2df{"$midasi@"};

	if ($opt{print_frequency}) {
	    print ' (';
	    print defined $df ? $df : 0;
	    print ')';
	}
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
	    print "　　";
	} else {
	    print "│　";
	}
    }
    if (defined($lastm)) {
	if ($lastm eq "1") {
	    print "└─";
	} else {
	    print "├─";
	}
    }
}

# カテゴリ情報を登録
sub regist_category {
    my ($mrph, $category) = @_;

    if ($mrph->imis =~ /カテゴリ:([^\"\s]+)/) {
	my $string = $1;
	for my $cat (split(/;/, $string)) {
	    $category->{$cat} = 1;
	}
    }
}
