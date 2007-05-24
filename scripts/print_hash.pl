#!/usr/bin/env perl

# $Id$

use strict;
use Encode;
use Dumpvalue;
use SynGraph;
use utf8;
binmode STDIN, ':encoding(euc-jp)';
binmode STDOUT, ':encoding(euc-jp)';
binmode STDERR, ':encoding(euc-jp)';
binmode DB::OUT, ':encoding(euc-jp)';

die "Usage: print_hash.pl db_name key\n" if (@ARGV < 1);

map {$_ = &decode('euc-jp', $_)} @ARGV;
my $db_name = shift @ARGV;
my @key = @ARGV;
my %db;

# CDBの場合
if ($db_name =~ /cdb$/) {
    &SynGraph::tie_cdb($db_name, \%db);
    if (@key) {
        foreach my $k (@key) {
            print $k, "\n";
            Dumpvalue->new->dumpValue(decode('utf8', $db{$k}));
        }
    }
    else {
        while (my ($k, $v) = each %db) {
	    print decode('utf8', $k), "\n";
	    print ' ', decode('utf8', $v), "\n";
        }
    }
    untie %db;
}
# BerkeleyDBの場合
elsif ($db_name =~ /db$/) {
    &SynGraph::tie_db($db_name, \%db);
    if (@key) {
        foreach my $k (@key) {
            print $k, "\n";
            print $db{$k}, "\n";
        }
    }
    else {
        print Dumpvalue->new->dumpValue(\%db);
    }
    untie %db;
}
# MLDBMの場合
elsif ($db_name =~ /mldbm$/) {
    &SynGraph::tie_mldbm($db_name, \%db);
    if (@key) {
        foreach my $k (@key) {
            print $k, "\n";
            Dumpvalue->new->dumpValue($db{$k});
        }
    }
    else {
        while (my ($k, $v) = each %db) {
            print $k, "\n";
            Dumpvalue->new->dumpValue($v);
        }
    }
    untie %db;
}
# mysqlの場合
elsif ($db_name =~ /:/) {
    my ($database, $table) = split(/:/, $db_name);
    my $sgh = new SynGraph;
    my $ref = {};

    $sgh->db_set({type => 'mysql', name => $database, table => $table});
    $sgh->db_connect;
    $sgh->db_retrieve($ref, \@key);

    Dumpvalue->new->dumpValue($ref);
}
# それ以外
else {
    my $sgh = new SynGraph;

    # 類義表現DBの読み込み
    $sgh->tie_syndb;

    # SYNGRAPHを作成
    my $ref = {};
    my $key = $db_name;
    $sgh->make_sg($key, $ref, $key);
    Dumpvalue->new->dumpValue($ref);
}
