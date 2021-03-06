#!/usr/bin/env perl

# $Id$

# syndb.convertを入力して表現をJUMANにかける（表現が代表表記であるときも対応できる）
# usage : perl word_into_juman.pl -C /home/harashima/usr/bin/juman -R /home/harashima/usr/etc/jumanrc

use strict;
use Getopt::Long;
use Encode;
use Dumpvalue;
use Juman;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
binmode DB::OUT, ':encoding(utf-8)';

my %opt; GetOptions(\%opt, 'Command=s', 'Rcfile=s', 'test');
my %option;
$option{"-Command"} =  $opt{Command} if ($opt{Command}); 
$option{"-Rcfile"} = $opt{Rcfile} if ($opt{Rcfile});
#Dumpvalue->new->dumpValue(\%option);

my $juman = new Juman(%option);

my $comment;
my $skip_flag = 0;

my $juman_version = &get_juman_version;

# 「朝飯/あさはん」が入力
while (<>) { # 代表表記
    chomp;

    if ($_ =~ /^\#/) { # 「#」行はそのまま出す。
	$comment = $_;
    }
    else {
	my $word = $_;
	my $result;
	if ($word =~ /^(.+?)\/.+?$/) { # $wordが代表表記
	    $result = $juman->analysis("$1");
	    my $flag;
	    if ($opt{test}) {
		&print_result_all($result->all());
	    }
	    else {
		foreach my $r_str (split(/\n/, $result->all())) {
		    if ($r_str =~ /代表表記:(.+?\/.+?)\"/) {
			if ($word eq $1) { # $wordにあたる解析行
			    $r_str =~ s/^@ //g;
			    print "$comment JUMAN:$juman_version\n";
			    print "$r_str\n";
			    $flag = 1;
			}
		    }
		}
		if ($flag) {
		    print "EOS\n";
		}
		else { # $wordにあたる解析行がなかった
		    &print_result_all($result->all());
		}
	    }
	}
	else { # 代表表記でない
	    $result = $juman->analysis("$word");
	    &print_result_all($result->all());
	}
    }
}

sub print_result_all {
    my ($all) = @_;

    print "$comment JUMAN:$juman_version\n";
    print $all;
}

sub get_juman_version {
    open (F, "juman -v 2>&1 |") or die;
    my $version;
    while (<F>) {
	chomp;
	# juman 6.0-20090202
	$version = (split(' ', $_))[1];
	last;
    }
    close F;

    return $version;
}
