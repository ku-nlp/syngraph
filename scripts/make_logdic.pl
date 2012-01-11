#!/usr/local/bin/perl

use strict;
use Dumpvalue;
use Getopt::Long;
use SynGraph;
use utf8;
binmode STDIN, ':encoding(utf-8)';
binmode STDOUT, ':encoding(utf-8)';
binmode STDERR, ':encoding(utf-8)';
binmode DB::OUT, ':encoding(utf-8)';

my %opt; GetOptions(\%opt, 'synonym=s', 'definition=s', 'isa=s', 'antonym=s', 'syndbdir=s');

# log_dic.dbを置く場所
my $dir = $opt{syndbdir} ? $opt{syndbdir} : '../syndb/i686';

my %log_dic;

my @FILE_NAME = ('definition', 'synonym', 'isa', 'antonym');

foreach my $file (@FILE_NAME) {
    open (FILE, '<:encoding(utf-8)', $opt{$file}) || die;
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
