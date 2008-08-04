#!/usr/bin/env perl

# sort ../dic/web_news/all.txt.jumanremoved | uniq | perl create_db_for_edit_web.pl

use strict;
use encoding 'euc-jp';
use BerkeleyDB;
use Storable qw(freeze thaw);
use MLDBM qw(BerkeleyDB::Hash Storable);
use Encode;

my $syndb = '../db/synonym_web.db';

my %SYNDB;
my $db = tie %SYNDB, 'MLDBM', -Flags => DB_CREATE, -Filename => $syndb or die "Cannot tie '$syndb'";

$db->filter_fetch_key(sub{$_ = &decode('euc-jp', $_)});
$db->filter_store_key(sub{$_ = &encode('euc-jp', $_)});
$db->filter_fetch_value(sub{});
$db->filter_store_value(sub{});

my %data;
while (<>) {
    chomp;

    my $string = $_;
    my ($word1, $word2) = split;

    push @{$data{$word1}}, $word2;
}

for my $word (sort {scalar(@{$data{$b}}) <=> scalar(@{$data{$a}})} keys %data) {
    $SYNDB{$word} = $data{$word};
}

untie %SYNDB;
