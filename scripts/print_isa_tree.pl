#!/usr/bin/env perl

# $Id$

# usage: perl print_isa_tree.pl -max_child_num 5 -dic -category_sort -min_hypo_num 4 -category_child_max_num 5 -cndbfile ~shibata/cns.100M.cls.df1000.cdb
# usage: perl print_isa_tree.pl -dic -category_sort -cndbfile ~shibata/cns.100M.cls.df1000.cdb -print_coordinate

use strict;
use encoding 'euc-jp';
binmode STDERR, ':encoding(euc-jp)';
use Getopt::Long;
use Juman;

my (%opt);
GetOptions(\%opt, 'isa_dic_file=s', 'isa_wikipedia_file=s', 'max_child_num=i', 'min_hypo_num=i', 'category_child_max_num=i', 'category_sort', 'dic', 'cndbfile=s', 'dfth=i', 'print_frequency', 'print_coordinate');

$opt{isa_dic_file} = '../dic_change/isa.txt' unless $opt{isa_dic_file};
$opt{isa_wikipedia_file} = '../dic_change/isa_wikipedia.txt' unless $opt{isa_wikipedia_file};

$opt{dfth} = 1000000 unless $opt{dfth};

&read_dic_isa if $opt{dic};
&read_wikipedia_isa;

# 複合名詞データベース
my %cn2df;
if ($opt{cndbfile}) {
    require CDB_File;
    tie %cn2df, 'CDB_File', $opt{cndbfile} or die;
}

my %data;
sub read_dic_isa {
    open F, "<:encoding(euc-jp)", $opt{isa_dic_file} or die;

    while (<F>) {
	chomp;

	# あくどい/あくどい:1/1:1/2 感じがする 11
	my ($hyponym, $hypernym, $num) = split(' ', $_);
	$hyponym = (split(':', $hyponym))[0];
	$hypernym = (split(':', $hypernym))[0];
	next if $hypernym eq $hyponym;
	$data{$hypernym}{children}{$hyponym} = 1;
	$data{$hyponym}{parent}{$hypernym} = 1;
    }

    close F;
}

sub read_wikipedia_isa {
    open F, "<:encoding(euc-jp)", $opt{isa_wikipedia_file} or die;

    # 京成津田沼駅 駅/えき 10921
    while (<F>) {
	chomp;

	my ($hyponym, $hypernym, $num) = split("\t", $_);
	$data{$hypernym}{children}{$hyponym} = 1;
	$data{$hyponym}{parent}{$hypernym} = 1;
    }

    close F;
}

if ($opt{cndbfile}) {
    for my $string (keys %data) {
	my $midasi = $string =~ /\// ? (split('/', $string))[0] : $string;
	my $df = $cn2df{"$midasi@"};

	if ($df > $opt{dfth}) {
	    for my $child (keys %{$data{$string}{children}}) {
		delete $data{$child}{parent}{$string};
	    }

	    for my $parent (keys %{$data{$string}{parent}}) {
		delete $data{$parent}{children}{$string};
	    }
	    delete $data{$string};
	}
    }

    for my $string (keys %data) {
	# parentがいなくなったものはキーparentを削除
	if (defined $data{$string}{parent} && scalar keys %{$data{$string}{parent}} == 0) {
	    delete $data{$string}{parent};
	}

	# childrenも同様
	if (defined $data{$string}{children} && scalar keys %{$data{$string}{children}} == 0) {
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
    $data{$string}{child_num} = defined $data{$string}{children} ? scalar keys %{$data{$string}{children}} : 0;
}

if ($opt{print_coordinate}) {
    for my $string (sort { $opt{category_sort} ? $data{$a}{category} cmp $data{$b}{category} || $data{$b}{child_num} <=> $data{$a}{child_num}
			   : $data{$b}{child_num} <=> $data{$a}{child_num} } keys %data) {
	next if defined $data{$string}{parent} || $data{$string}{child_num} == 0;

	my @words = &get_words($string);
	my %words;
	for my $word (@words) {
	    $words{$word} = 1
	}
	for my $word (sort keys %words) {
	    next if $word eq $string; # 最上位の語

	    # 親を順に得る
	    my @parents = &get_parents($word, \%words);
	    # 子をすべて得る
	    my @children = &get_children($word, \%words);

	    my %ng_coordinate;
	    for my $w (@parents, @children) {
		$ng_coordinate{$w} = 1;
	    }
	    my @coordinate;
	    for my $w (@words) {
		next if $w eq $word;
		next if defined $ng_coordinate{$w};

		push @coordinate, $w;
	    }
	    print "$word ", join(',', @coordinate), "\n" if scalar @coordinate > 0;
	}
    }
}
else {
    my $pre_category;
    my %print_category_num;
    for my $string (sort { $opt{category_sort} ? $data{$a}{category} cmp $data{$b}{category} || $data{$b}{child_num} <=> $data{$a}{child_num}
			   : $data{$b}{child_num} <=> $data{$a}{child_num} } keys %data) {
	next if defined $data{$string}{parent} || $data{$string}{child_num} == 0;

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
	my @children = sort { $data{$b}{child_num} <=> $data{$a}{child_num} } keys %{$data{$string}{children}};
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

sub get_words {
    my ($string, $mark) = @_;

    my @marks = split(//,$mark);

    my $lastm = pop(@marks);

    my @words;
    push @words, $string;

    if (defined $data{$string}{children}) {
	my @children = sort { $data{$b}{child_num} <=> $data{$a}{child_num} } keys %{$data{$string}{children}};
	my $last_child = $children[-1];

	my $print_child_num = 0;
	foreach my $child (@children) {
	    if ($child ne $last_child) {
		push @words, &get_words($child, $mark . '0');
		$print_child_num++;
	    }

	    if ($opt{max_child_num} && $print_child_num == $opt{max_child_num}) {
		return;
	    }
	}
	push @words, &get_words($last_child, $mark . '1') if (defined($last_child));
    }

    return @words;
}

# 自分の親を得る
sub get_parents {
    my ($string, $all_words) = @_;

    my @parents;

    if (defined $data{$string}{parent}) {
	for my $parent (sort keys %{$data{$string}{parent}}) {

	    next if !defined $all_words->{$parent}; # 対象のツリー中の語でなければnext
	    push @parents, $parent;

	    my @parent_parents = &get_parents($parent, $all_words);
	    push @parents, @parent_parents if scalar @parent_parents > 0;
	}
    }
    
    return @parents;
}

# 自分の子供を得る
sub get_children {
    my ($string, $all_words) = @_;

    my @children;

    if (defined $data{$string}{children}) {
	for my $child (sort keys %{$data{$string}{children}}) {
	    next if !defined $all_words->{$child}; # 対象のツリー中の語でなければnext
	    push @children, $child;
	    my @child_children = &get_children($child, $all_words);
	    push @children, @child_children if scalar @child_children > 0;
	}
    }

    return @children
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
