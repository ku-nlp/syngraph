#!/usr/bin/env perl

# $Id$

# syndb.convertを入力して表現をJUMANにかける（表現が代表表記であるときも対応できる）
# usage : perl word_into_juman.pl -C /home/harashima/usr/bin/juman -R /home/harashima/usr/etc/jumanrc

use strict;
use Getopt::Long;
use Dumpvalue;
use Juman;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'Command=s', 'Rcfile=s', 'test');
my %option;
$option{"-Command"} =  $opt{Command} if ($opt{Command}); 
$option{"-Rcfile"} = $opt{Rcfile} if ($opt{Rcfile});
#Dumpvalue->new->dumpValue(\%option);

my $juman = new Juman(%option);

# 「朝飯/あさはん」が入力
while (<>) { # 代表表記
    chomp;

    if ($_ =~ /^\#/) { # 「#」行はそのまま出す。
	print "$_\n";
    }
    else {
	my $word = $_;
	my $result;
	if ($word =~ /^(.+?)\/.+?$/) { # $wordが代表表記
	    $result = $juman->analysis("$1");
	    my $flag;
	    if ($opt{test}) {
		print $result->all();
		print "EOS\n";
	    }
	    else {
		foreach my $r_str (split(/\n/, $result->all())) {
		    if ($r_str =~ /代表表記:(.+?\/.+?)\"/) {
			if ($word eq $1) { # $wordにあたる解析行
			    $r_str =~ s/^@ //g;
			    print "$r_str\n";
			    $flag = 1;
			}
		    }
		}
		if ($flag) {
		    print "EOS\n";
		}
		else { # $wordにあたる解析行がなかった
		    print $result->all();
		    print "EOS\n";
		}
	    }
	}
	else { # 代表表記でない
	    $result = $juman->analysis("$word");
	    print $result->all();
	    print "EOS\n";
	}
    }
}