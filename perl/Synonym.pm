package Synonym;

use strict;
use utf8;
use JumanDevel;
use CDB_File;

sub new {
    my ($this, $opt) = @_;

    $this = {};

    bless $this;

    return $this;
}

sub DESTROY {
    my ($this) = @_;

    untie %{$this->{'synset'}} if defined $this->{'synset'};
}

# 同義語かどうか
sub IsSynonym {
    my ($this, $word1, $word2, $synonym_storable) = @_;

    my @word1 = split('\+', $word1);
    my @word2 = split('\+', $word2);

    my $word1_mrph_num = scalar @word1;
    my $word2_mrph_num = scalar @word2;

    return 0 if $word1_mrph_num ne $word2_mrph_num;

    for (my $i = 0; $i < $word1_mrph_num; $i++) {
	if ($word1[$i] eq $word2[$i] || $this->_IsSynonym($word1[$i], $word2[$i], $synonym_storable)) {
	    ;
	}
	else {
	    return 0;
	}
    }
    return 1;
}

sub _IsSynonym {
    my ($this, $word1, $word2, $synonym_storable) = @_;

    my $midasi1 = (split('\/', $word1))[0];
    my $midasi2 = (split('\/', $word2))[0];
    if (defined $this->{juman}{synonym} && ($this->{juman}{synonym}{$word1}{$word2} || $this->{juman}{synonym}{$word2}{$word1})) {
	return 1;
    }
    if ($synonym_storable && $this->CheckStorableData($synonym_storable, $midasi1, $midasi2)) {
	return 1;
    }

    if (defined $this->{synset}) {
	my $synsets1 = $this->{synset}{$midasi1};
	my $synsets2 = $this->{synset}{$midasi2};

	if (defined $synsets1 && defined $synsets2) {
	    for my $synset1 (split('\|', $synsets1)) {
		for my $synset2 (split('\|', $synsets2)) {
		    if ($synset1 eq $synset2) {
			return 1;
		    }
		}
	    }
	}
    }
    return 0;
}

# 反義語かどうか
sub IsAntonym {
    my ($this, $word1, $word2, $antonym_storable) = @_;

    my @word1 = split('\+', $word1);
    my @word2 = split('\+', $word2);

    my $word1_mrph_num = scalar @word1;
    my $word2_mrph_num = scalar @word2;

    return 0 if $word1_mrph_num ne $word2_mrph_num;

    my $antonym_num = 0;
    for (my $i = 0; $i < $word1_mrph_num; $i++) {
	if ($word1[$i] eq $word2[$i]) {
	    ;
	}
	elsif ($this->_IsAntonym($word1[$i], $word2[$i], $antonym_storable)) {
	    $antonym_num++;
	}
	else {
	    return 0;
	}
    }

    # 奇数個なら反義語
    if ($antonym_num % 2) {
	return 1;
    }
    else {
	return 0;
    }
}

sub _IsAntonym {
    my ($this, $word1, $word2, $antonym_storable) = @_;

    my $midasi1 = (split('\/', $word1))[0];
    my $midasi2 = (split('\/', $word2))[0];
    if (defined $this->{juman}{antonym}) {
	if ($this->{juman}{antonym}{$word1}{$word2} || $this->{juman}{antonym}{$word2}{$word1}) {
	    return 1;
	}
	if (defined $this->{'synset'}) {
	    if (defined $this->{juman}{antonym}{$word1}) {
		for my $word2_cand (keys %{$this->{juman}{antonym}{$word1}}) {
		    return 1 if $this->_IsSynonym($word2, $word2_cand);
		}
	    }
	    if (defined $this->{juman}{antonym}{$word2}) {
		for my $word1_cand (keys %{$this->{juman}{antonym}{$word2}}) {
		    return 1 if $this->_IsSynonym($word1, $word1_cand);
		}
	    }
	}
    }
    if ($antonym_storable && $this->CheckStorableData($antonym_storable, $midasi1, $midasi2)) {
	return 1;
    }
    # 平等 不平等
    if ($midasi1 eq '不' . $midasi2 || $midasi2 eq '不' . $midasi1) {
	return 1;
    }

    return 0;
}

sub CheckStorableData {
    my ($this, $storable, $midasi1, $midasi2, $manual_data, $option) = @_;

    my $flag = 0;
    if (defined $storable->{$midasi1} || defined $storable->{$midasi2}) {
	# どっちも意味が1つしかない場合にマッチ
	if ($option->{one_meaning}) {
	    return 0 if scalar @{$storable->{$midasi1}} != 1 || scalar @{$storable->{$midasi2}} != 1;
	}

	for my $midasi (@{$storable->{$midasi1}}) {
	    if ($midasi2 eq $midasi) {
		$flag = 1;
		last;
	    }
	}
	for my $midasi (@{$storable->{$midasi2}}) {
	    if ($midasi1 eq $midasi) {
		$flag = 1;
		last;
	    }
	}
    }

    if (defined $manual_data->{$midasi1}) {
	for my $midasi (@{$manual_data->{$midasi1}}) {
	    if ($midasi2 eq $midasi) {
		$flag = 1;
		last;
	    }
	}
    }

    return $flag;
}

sub ReadJumanDic {
    my ($this, $jumandic, $option) = @_;

    open DIC, "<:encoding(utf-8)", $jumandic || die;
    while (<DIC>) {
	my ($top_midashi_dic, $midashi_dic, $yomi_dic, $hinshi_dic, $hinshi_bunrui_dic, $conj_dic, $imis_dic) = read_juman_entry($_);
	next unless $imis_dic;

	my $repname;
	if ($imis_dic =~ /代表表記:([^\"\s]+)/) {
	    $repname = $1;
	}

	my $key = $option->{use_top_midashi} ? $top_midashi_dic : $repname;
	next if !$key;

	next if $option->{target_hinsi} && $option->{target_hinsi} ne $hinshi_dic;

	# 反義:動詞:着る/きる;動詞:被る/かぶる;動詞:履く/はく
	if ($imis_dic =~ / (同義|反義):([^\"\s]+)/) {
	    my $type = $1;
	    my $string = $2;
	    for my $str (split(';', $string)) { 
		# 着る/きる
		my $word = (split(':', $str))[-1];
		if ($type eq '同義') {
		    $this->{juman}{synonym}{$key}{$word} = 1;
		}
		else {
		    $this->{juman}{antonym}{$key}{$word} = 1;
		}
	    }
	}
    }
    close DIC;
}

sub IsAcronym {
    my ($this, $word1, $word2, $midasi1, $midasi2, $mrphnum1, $mrphnum2) = @_;

    #ＯｒａｃｌｅＡｐｉ/ＯｒａｃｌｅＡｐｉ ＯＡ/ＯＡ
    if ($mrphnum1 == 1 && $mrphnum2 == 1) {
	($midasi1, $midasi2) = &swap($midasi1, $midasi2) if length $midasi1 < length $midasi2;

	return 0 if $midasi2 !~ /^[Ａ-Ｚ]{2,}$/;

	my @chars2 = split('', $midasi2);
	my $regular_expression = join('[ａ-ｚ]+', @chars2) . '[ａ-ｚ]+';
	if ($midasi1 =~ /^$regular_expression$/) {
	    return 1;
	}
	else {
	    return 0;
	}
    }
    elsif ($mrphnum1 eq $mrphnum2) {
	return 0;
    }

    # midasi1の方が短くする
    if ($mrphnum1 > $mrphnum2) {
	($word1, $word2) = &swap($word1, $word2);
	($midasi1, $midasi2) = &swap($midasi1, $midasi2);
	($mrphnum1, $mrphnum2) = &swap($mrphnum1, $mrphnum2);
    }

    return 0 if $mrphnum1 ne 1;

    my $midasi1 = (split('/', $word1))[0];

    return 0 if $midasi1 !~ /^[Ａ-ｚ]+$/;

    my $word2_head_characters;
    for my $mrph2 (split('\+', $word2)) {
	$word2_head_characters .= substr($mrph2, 0, 1);
    }

    if ($midasi1 eq $word2_head_characters) {
	return 1;
    }
    else {
	return 0;
    }
}

# 末尾に共通の文字列を持つかどうか
sub HasTailCommonString {
    my ($this, $word1, $word2) = @_;

    my $midasi1 = &get_midasi($word1);
    my $midasi2 = &get_midasi($word2);

    my @reverse_chars1 = reverse split('', $midasi1);
    my @reverse_chars2 = reverse split('', $midasi2);

    my $common_string;
    for (my $i = 0; $i < scalar @reverse_chars1 && $i < scalar @reverse_chars2; $i++) {
	if ($reverse_chars1[$i] eq $reverse_chars2[$i]) {

	    $common_string = $reverse_chars1[$i] . $common_string;
	}
	else {
	    last;
	}
    }

    print "$word1 $word2 $common_string\n" if length $common_string > 4;
}

# 共通の文字列を持つかどうか
sub HasCommonString {
    my ($this, $word1, $word2, $midasi1, $midasi2) = @_;

    return 0 if $midasi2 =~ /$midasi1/;

    my @char1 = split(//, $midasi1);
    my $regular_expression = join('.*', @char1) . '.*';

    if ($midasi2 =~ /^$regular_expression$/) {
	return 1;
    }
    else {
	return 0;
    }
}

sub GetMrphNum {
    my ($this, $word) = @_;

    my @mrph = split('\+', $word);

    return scalar @mrph;
}

sub GetMidasi {
    my ($this, $word) = @_;

    my $midasi;

    for my $mrph (split('\+', $word)) {
	$midasi .= (split('/', $mrph))[0];
    }

    return $midasi;
}

sub TieCDB {
    my ($this, $db, $key) = @_;

    my $db = tie %{$this->{$key}}, 'CDB_File', $db or die;
}

sub swap {
    my ($val1, $val2) = @_;

    my $tmp = $val1;
    $val1 = $val2;
    $val2 = $tmp;

    return ($val1, $val2);
}

1;
