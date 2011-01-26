package MergeTxt;

# $Id$

use strict;
use Dumpvalue;
use KNP;
use utf8;
use SynGraph;

#
# コンストラクタ
#
sub new {
    my ($this) = @_;

    my $knp_option;
    $knp_option->{no_case} = 1;
    $knp_option->{knpcommand} = $Configure::KnpCommand;
    $knp_option->{knprc} = $Configure::KnpRcfile;
    $knp_option->{jumancommand} = $Configure::JumanCommand;
    $knp_option->{jumanrc} = $Configure::JumanRcfile;

    $this = {
	log_merge      => {},
	rep_cache       => {},
	indexkey_cache  => {},
	noambiguity_file => {},
	sgh            => new SynGraph(undef, $knp_option, undef),
    };
    
    bless $this;

    return $this;
}

# 単語列Aを含む単語列Bがあるか？
sub merge_check {
    
    my ($this, $group_A, $word_index) = @_;
    my %gr_check; # Bの候補
    
    foreach my $word (@{$group_A}) {

	my $w = (split(/:/, $word))[0]; # IDを取る
	if (scalar(keys %gr_check) == 0) { # 一番目の語($w)が含まれているグループを調べる
	    %gr_check = $this->find_group($w, $word_index);
	    last unless (defined %gr_check); # 語が属しているグループが存在しない
	}
	else{ # 一番目の語が含まれているグループに二番目以降の語($w)が含まれているか？
	    
	    # $wが含まれているグループ
	    my %gr_check_dash = $this->find_group($w, $word_index);
	    
	    foreach my $gr_number (keys %gr_check) {
		# $gr_checkのうち$wが含まれていないグループを削除
		unless (grep ($gr_number == $_, (keys %gr_check_dash))) {
		    delete $gr_check{$gr_number};
		    
		    # $gr_checkがなくなればBの候補がなくなる
		    if (scalar(keys %gr_check) == 0) {
			last;
		    }
		}
	    }
	}
	
	# $gr_checkがなくなればBの候補がなくなる
	if (scalar(keys %gr_check) == 0) {
	    last;
	}
    }
    
    if (scalar(keys %gr_check) == 0) { # 重複していない
	return;
    }
    else { # 重複している
	return \%gr_check;
    }
}

# 単語列Aに連結できる単語列Bがあるか？
sub add_check {
    
    my ($this, $group_A, $word_index) = @_;
    my %gr_check; # Bの候補
    
    foreach my $word (@{$group_A}) {
	
	# $wordにword_idがふられているとき$wordが含まれているグループを調べる
	if ((split(/:/, $word, 2))[1]){
	    if (scalar(keys %{$word_index->{$word}})) {
		foreach my $gr_number (keys %{$word_index->{$word}}) {
		    $gr_check{$gr_number} = 1 unless $gr_check{$gr_number};
		}
	    }
	}
    }
    
    if (scalar(keys %gr_check) == 0) { # 重複していない
	return;
    }
    else { # 重複している
	return \%gr_check;
    }
}

# $wが含まれているグループをさがす。
sub find_group {
    
    my ($this, $w, $word_index) = @_;
    my %result;
    
    # $wが代表表記
    if ($w =~ /^(.+?)\/(.+?)[va]?$/) {
	my ($kanji, $kana) = ($1,$2);
	
	# $wが含まれているグループ
	# $kanjiが含まれているグループ(代表表記の漢字が$kanjiであるものと区別)
	# $kanaが含まれているグループ(代表表記のふりがなが$kanaであるものと区別)
	foreach my $key ("$w","$kanji", "$kana") {
	    if (scalar(keys %{$word_index->{$key}}) > 0) {
		foreach my $gr_number (keys %{ $word_index->{$key}}) {
		    $result{$gr_number} = 1 unless $result{$gr_number};
		}
	    }
	}
    }
    # $wが代表表記でない
    else {
	my $rep_w_str = $this->GetRepname($w);
	
	# $wが含まれているグループ
	# 代表表記の漢字が$w、ふりがなが$wなものが含まれているグループ
	# $wの代表表記が含まれているグループ(曖昧性は可能性を全て考慮)
	foreach my $key ("$w","$w/", "/$w", split(/\?/, $rep_w_str)) {
	    if (scalar(keys %{$word_index->{$key}}) > 0) {
		foreach my $gr_number (keys %{ $word_index->{$key}}) {
		    $result{$gr_number} = 1 unless $result{$gr_number};
		}
	    }
	}
    }

    return %result;
}

# 単語列Aを単語列Bにマージ
sub merge_group {

    my ($this, $gr_check, $list, $group, $word_index) = @_;
    my @log;

    # マージ
    foreach my $merge_g_number (keys %{$gr_check}) {

	my @group_orig;
	foreach (@{$group->{$merge_g_number}}) {
	    push (@group_orig, $_);
	}

	# idやふり仮名をマージ
	my @group_merge;
	my %check_merge;
	my $flag; # 実はマージできない
	foreach my $word_delete (@{$list}) {
	    my $word_merge;
	    foreach my $word_orig (@group_orig) {
		next if ($check_merge{$word_orig});
		if ($this->merge_words($word_delete, $word_orig)) {
		    $word_merge = $this->merge_words($word_delete, $word_orig);
		    $check_merge{$word_orig} = 1;
		    last;
		}
	    }

	    if ($word_merge) { # w_deleteはw_origにマージできた
		push @group_merge, $word_merge;
	    }
	    else { # IDの違いでw_deleteはマージできなかった
		$flag = 1;
		last;
	    }	    
	}
	next if ($flag); # 実はマージできない

	# マージできた
	# group_origの残りを加える
	foreach my $word_orig (@group_orig) {
	    if ($check_merge{$word_orig}) {
		next; # マージしたものが加わっている
	    }
	    else {
		push @group_merge, $word_orig;
	    }
	}

	# groupの更新, word_indexの更新
	delete $group->{$merge_g_number};
	$this->delete_word_index(\@group_orig, $merge_g_number, $word_index);
	$this->regist_list4merge(\@group_merge, $merge_g_number, $group, $word_index);
	
	# ログ
	my $delete_str;
	foreach (@{$list}) {
	    $delete_str .= " " if ($delete_str);
	    $delete_str .= $_;
	}
	my $orig_str;
	foreach (@group_orig) {
	    $orig_str .= " " if ($orig_str);
	    $orig_str .= $_;
	}
	my $merge_str;
	foreach (@group_merge) {
	    $merge_str .= " " if ($merge_str);
	    $merge_str .= $_;
	}
		
	push @log, {'delete1' => $orig_str, 'delete2' => $delete_str, 'merge' => $merge_str};
    }
    return \@log;
}

# 単語列Aに単語列Bを連結し、登録
sub add_group {
    
    my ($this, $list_A, $list_B) = @_;
    my @result;
    
    my %check_merge;
    foreach my $word_A (@{$list_A}) {
	# 同じ単語はマージ
	# idやふり仮名をマージ
	my $word_merge;
	foreach my $word_B (@{$list_B}) {	
	    next if ($check_merge{$word_B});
	    if ($this->merge_words($word_A, $word_B)) {
		    $word_merge = $this->merge_words($word_A, $word_B);
		    $check_merge{$word_B} = 1;
		    last;
		}
	}

	if ($word_merge) { # word_Aはgroup_Bの一語とにマージできた
	    push @result, $word_merge;
	}
	else { # word_Aはマージできなかった
	    push @result, $word_A;
	}
    }

    # group_origの残りを加える
    foreach my $word_B (@{$list_B}) {
	if ($check_merge{$word_B}) {
	    next; # マージしたものが加わっている
	}
	else {
	    push @result, $word_B;
	}
    }

    return @result;
}

# 単語列Aに単語列Bを連結
sub add_group_old {

    my ($this, $gr_check, $list, $group, $word_index) = @_;
    my @log;

    # listを連結する
    foreach my $add_g_number (keys %{$gr_check}) {

	my @group_orig;
	foreach (@{$group->{$add_g_number}}) {
	    push (@group_orig, $_);
	}

	# 同じ単語はマージ
	# idやふり仮名をマージ
	my @group_add;
	my %check_merge;
	foreach my $word_delete (@{$list}) {
	    my $word_merge;
	    foreach my $word_orig (@group_orig) {
		next if ($check_merge{$word_orig});
		if ($this->merge_words($word_delete, $word_orig)) {
		    $word_merge = $this->merge_words($word_delete, $word_orig);
		    $check_merge{$word_orig} = 1;
		    last;
		}
	    }

	    if ($word_merge) { # w_deleteはw_origにマージできた
		push @group_add, $word_merge;
	    }
	    else { # w_deleteはマージできなかった
		push @group_add, $word_delete;
	    }	    
	}

	# group_origの残りを加える
	foreach my $word_orig (@group_orig) {
	    if ($check_merge{$word_orig}) {
		next; # マージしたものが加わっている
	    }
	    else {
		push @group_add, $word_orig;
	    }
	}

	# groupの更新, word_indexの更新
	delete $group->{$add_g_number};
	$this->delete_word_index(\@group_orig, $add_g_number, $word_index);
	$this->regist_list4add(\@group_add, $add_g_number, $group, $word_index);
	
	# ログ
	my $delete_str;
	foreach (@{$list}) {
	    $delete_str .= " " if ($delete_str);
	    $delete_str .= $_;
	}
	my $orig_str;
	foreach (@group_orig) {
	    $orig_str .= " " if ($orig_str);
	    $orig_str .= $_;
	}
	my $add_str;
	foreach (@group_add) {
	    $add_str .= " " if ($add_str);
	    $add_str .= $_;
	}
		
	push @log, {'delete1' => $orig_str, 'delete2' => $delete_str, 'add' => $add_str};
    }
    
    if (scalar(keys %{$gr_check}) > 1) {
	my $new_number = (keys %{$gr_check})[0];
	my @new_list = @{$group->{$new_number}};
	delete $gr_check->{$new_number};
	
# 	if (join(" ", @new_list) eq '総体/そうたい:1/1:1/1 全般/ぜんぱん:1/1:1/1'){
# 	    print "$new_number\n";
# 	    Dumpvalue->new->dumpValue($gr_check);
# 	    foreach (keys %{$gr_check}) {
# 		print join(" ", @{$group->{$_}}), "\n";
# 	    }
# 	    print "-----\n";
# 	}
	
	# new_numberを他のものに連結する
	my $new_log_list = $this->add_group($gr_check, \@new_list, $group, $word_index);

	# groupの更新, word_indexの更新
	delete $group->{$new_number};
	$this->delete_word_index(\@new_list, $new_number, $word_index);

	push @log, @{$new_log_list};
    }
    
    return \@log;
}

# 単語のマージ
sub merge_words {
    
    my ($this, $word_delete, $word_orig) = @_;
    my $word_merge;

    my ($w_delete, $id_delete) = split(/:/, $word_delete, 2); # ID取る
    my ($w_orig, $id_orig) = split(/:/, $word_orig, 2); # ID取る

    if ($w_delete eq $w_orig) { # w_deleteとw_origが一致
	# if id_orig ne id_delete 実はマージできない
	if ($id_orig and $id_delete and $id_orig ne $id_delete) {
	    return; # マージできない
	}
	else { # 単語をマージ
	    $word_merge = $w_orig;
	    if ($id_orig) {
		$word_merge .= ":$id_orig";
	    }
	    elsif ($id_delete) {
		$word_merge .= ":$id_delete";
	    }
	    return $word_merge; # マージした
	}
    }
    else {
	my ($kanji_delete, $kana_delete) = split(/\//, $w_delete);
	$kana_delete =~ s/v$//;
	my ($kanji_orig, $kana_orig) = split(/\//, $w_orig);
	$kana_orig =~ s/v$//;
	if (($w_delete eq $kana_orig) or ($w_delete eq $kanji_orig)) { # 漢字か読みとマッチ
	    # if id_orig ne id_delete 実はマージできない
	    if ($id_orig and $id_delete and $id_orig ne $id_delete) {
		return; # マージできない
	    }
	    $word_merge = $w_orig;
	    if ($id_orig) {
		$word_merge .= ":$id_orig";
	    }
	    elsif ($id_delete) {
		$word_merge .= ":$id_delete";
	    }
	    return $word_merge; # マージした
	}
	elsif (($w_orig eq $kana_delete) or ($w_orig eq $kanji_delete)) { # 漢字か読みとマッチ
	    # if id_orig ne id_delete 実はマージできない
	    if ($id_orig and $id_delete and $id_orig ne $id_delete) {
		return; # マージできない
	    }
	    $word_merge = $w_delete;
	    if ($id_orig) {
		$word_merge .= ":$id_orig";
	    }
	    elsif ($id_delete) {
		$word_merge .= ":$id_delete";
	    }
	    return $word_merge; # マージした
	}
	else { # 代表表記化に注意してマージできる可能性チェック(「あたい」＝「値」)
	    # 代表表記があれば獲得
	    my $rep_w_orig_str = $this->GetRepname($w_orig);
	    my $rep_w_delete_str = $this->GetRepname($w_delete);
	    
	    foreach my $rep_w_orig (split/\?/, $rep_w_orig_str) {
		if (grep($rep_w_orig eq $_, (split(/\?/, $rep_w_delete_str)))) {
		    
		    # if id_orig ne id_delete 実はマージできない
		    if ($id_orig and $id_delete and $id_orig ne $id_delete) {
			return; # マージできない
		    }
		    else {
			# 単語をマージ
			if ($w_orig =~ /^.+\/.+$/) { # もともと代表表記である方を採用(「銘々/めいめい:1/1:1/1」＝「めいめい」)
			    $word_merge = $w_orig;
			}
			elsif ($w_delete =~ /^.+\/.+$/) { # もともと代表表記である方を採用(「さいきん」＝「最近/さいきん:1/1:1/1」)
			    $word_merge = $w_delete;
			}
			elsif (split(/\?/, $rep_w_orig_str) < split(/\?/, $rep_w_delete_str)) { # 曖昧性の少ない方を採用(「まよなか」＝「ま夜中」)
			    $word_merge = $w_orig;
			}
			elsif (split(/\?/, $rep_w_orig_str) > split(/\?/, $rep_w_delete_str)) { # 曖昧性の少ない方を採用
			    $word_merge = $w_delete;
			}
			else { # 文字列の長さが短い方を採用(「値」＝「あたい」)
			    if (length($w_orig) < length($w_delete)) {
				$word_merge = $w_orig;
			    }
			    else {
				$word_merge = $w_delete;				
			    }
			}

			# ID付ける
			if ($id_orig) {
			    $word_merge .= ":$id_orig";
			}
			elsif ($id_delete) {
			    $word_merge .= ":$id_delete";
			}
			return $word_merge; # マージした				
		    }
		}
	    }	
	    return; # マージできない
	}
    }
}

# 単語列を登録(merge用)
sub regist_list4merge {
    
    my ($this, $list, $number, $group, $word_index) = @_;
    foreach my $word (@{$list}) {
	# 単語列登録
	push @{$group->{$number}}, $word;

	# 単語のindex作成
	my $w = (split(/:/, $word))[0]; # ID取る
	# $wが代表表記
	if ($w =~ /^(.+?)\/(.+?)[va]?$/) {

	    # 漢字、ふりがながあれば獲得
	    my ($kanji, $kana) = ($1,$2);
	    # $wが含まれている
	    # 代表表記の漢字が$kanjiであるものが含まれている(ただの$kanjiと区別)
	    # 代表表記のふりがなが$kanaであるものが含まれている(ただの$kanaと区別)
	    foreach my $key ("$w","$kanji/", "/$kana") {
#		push @{$word_index->{$key}}, $number unless (grep($number == $_, @{$word_index->{$key}}));
		$word_index->{$key}{$number} = 1 unless ($word_index->{$key}{$number});
		$this->{indexkey_cache}{$word}{$key} = 1 unless($this->{indexkey_cache}{$word}{$key});
	    }
	}
	# $wが代表表記でない
	else {

	    # 代表表記があれば獲得
	    my $rep_w_str = $this->GetRepname($w);

	    # $wが含まれている
	    # 曖昧性は可能性を全て考慮
	    foreach my $key ("$w", split(/\?/, $rep_w_str)) {
#		push @{$word_index->{$key}}, $number unless (grep($number == $_, @{$word_index->{$key}}));
		$word_index->{$key}{$number} = 1 unless ($word_index->{$key}{$number});
		$this->{indexkey_cache}{$word}{$key} = 1 unless($this->{indexkey_cache}{$word}{$key});
	    }
	}
    }
}

# 単語列を登録(add用)
sub regist_list4add {
    
    my ($this, $list, $number, $group, $word_index) = @_;
    foreach my $word (@{$list}) {
	# 単語列登録
	push @{$group->{$number}}, $word;

	# 単語のindex作成
	# word_id(1/1:1/1)がついている語を含んでいるグループを登録
	if ((split(/:/, $word, 2))[1]) {
#	    push @{$word_index->{$word}}, $number unless (grep($number == $_, @{$word_index->{$word}}));
	    $word_index->{$word}{$number} = 1 unless ($word_index->{$word}{$number});
	    $this->{indexkey_cache}{$word}{$word} = 1 unless($this->{indexkey_cache}{$word}{$word});
	}
    }
}

# 代表表記を得る
sub GetRepname {
    my ($this, $word) = @_;

    if ($word =~ /^.+\/.+$/) { # 代表表記
	return $word;
    }
    elsif ($this->{rep_cache}{$word}) {
	return $this->{rep_cache}{$word};
    }
    else {
	my $result = $this->{sgh}{knp}->parse($word);
	
	if (scalar ($result->bnst) == 1) {
	    my $repname = ($result->bnst)[0]->repname;

	    # 否定表現の場合、代表表記に変換すると、否定を含まない表現とマッチしてしまうので、代表表記にしない
	    # 例: 必要でない
 	    if (($result->bnst)[0]->fstring =~ /<否定表現>/) {
 		$this->{rep_cache}{$word} = $word;
 		return $word;
 	    }

	    $this->{rep_cache}{$word} = $repname;
	    return $repname;
	}
	else { # ２文節になっているのは解析誤りの可能性
	    $this->{rep_cache}{$word} = $word;
	    return $word;
	}
    }
}

# word_indexを消す
sub delete_word_index {

    my ($this, $list, $delete_number, $word_index) = @_;
    
    foreach my $word (@{$list}) {
	if ($this->{indexkey_cache}{$word}) {
	    foreach my $key (keys %{$this->{indexkey_cache}{$word}}) {
		delete $word_index->{$key}{$delete_number};
	    }
	}
    }
}

# ログ
sub make_log {

    my ($this, $type, $log_list) = @_;
    my $log_str;

    foreach my $log (@{$log_list}) {
	foreach my $key (('delete1', 'delete2', $type)) {
	    $log_str .= ($key eq $type) ? "☆$key <$log->{$key}>\n" : "★$key <$log->{$key}>\n";
	}
	$log_str .= "\n";
    }

    return $log_str;
}

# 構成単語が多い順にグループを並び替える
sub sort_group {

    my ($this, $group_list) = @_;
    my @sort_group_list;
    my %number;

    # 要素数の数を調べる
    foreach (@$group_list) {
	my @list = split;
	push @{$number{@list}}, $_;
    }

    # 要素数の多い順に同義グループを並び替える
    foreach my $num_of_word (sort {$b <=> $a} keys %number) {
	foreach my $group (@{$number{$num_of_word}}) {
	    push @sort_group_list, $group;
	}
    }

    return @sort_group_list;
}

1;
