#!/usr/local/bin/perl

use strict;
use Dumpvalue;
use Getopt::Long;
use SynGraph;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

my %opt; GetOptions(\%opt, 'synonym=s', 'definition=s', 'isa=s', 'antonym=s', 'syndbdir=s');

# log_dic.dbを置く場所
my $dir = $opt{syndbdir} ? $opt{syndbdir} : '../syndb/i686';

my %log_dic;

my @FILE_NAME = ('definition', 'synonym', 'isa', 'antonym');

foreach my $file (@FILE_NAME) {
    open (FILE, '<:encoding(euc-jp)', $opt{$file}) || die;
    while (<FILE>) {
	chomp;
	my $sent = $_;
	$log_dic{(split (/\//, $sent))[0]} .= "<$file.txt:$_>\n";
    }
}
close(FILE);

#
# 辞書抽出のログ保存（CGI用）
#
&SynGraph::store_cdb("$dir/log_dic.cdb", \%log_dic);
