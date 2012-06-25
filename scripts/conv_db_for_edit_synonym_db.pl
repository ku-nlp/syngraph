#!/usr/bin/env perl

use strict;
use encoding 'euc-jp';
use Encode;
use lib qw(/home/shibata/work/SynGraph/perl);

use SynGraph;
use Configure;
use BerkeleyDB;
use Juman;
use Getopt::Long;
use Dumpvalue;

my (%opt);
GetOptions(\%opt, 'keyrep');
&usage if $opt{help};

my %LOG;

if ($opt{keyrep}) {
    my $edit_db = '/avocado6/shibata/synonym/db/synonym_db_for_edit.db';
    my $edit_db_new = '/avocado6/shibata/synonym/db/synonym_db_for_edit_keyrep.db';

    my (%SYNDB, %SYNDB_NEW, %FREQ);

    &SynGraph::tie_mldbm($edit_db, \%SYNDB);
    &SynGraph::tie_cdb('/home/shibata/work/SynGraph/db/synonym_freq_all.db', \%FREQ);

    # 'ambiguity' => 1
#     'elements' => ARRAY(0x9805140)
#    0  HASH(0x9805110)
#       'definition' => '同じでなくする'
#       'id' => '1/1:1/3'
#       'origtype' => 'synonym'
#       'type' => 'synonym'
#       'word' => '違える/ちがえる'
#    1  HASH(0x9825054)
#       'definition' => '間違える/まちがえる'
#       'id' => '1/1:2/3'
#       'origtype' => 'synonym'
#       'type' => 'synonym'
#       'word' => '違える/ちがえる'
#    2  HASH(0x9867c54)
#       'definition' => '外す/はずす'
#       'id' => '1/1:3/3'
#       'origtype' => 'synonym'
#       'type' => 'synonym'
#       'word' => '違える/ちがえる'

    for my $key (keys %SYNDB) {
#	print $key, "\n";

	my $new_key;
	for my $e (@{$SYNDB{$key}{elements}}) {
	    if (defined $e->{word}) {
		$new_key = $e->{word};
		last;
	    }
	}

	unless ($new_key) {

	    # 代表表記のものを探す
	    my $flag = 0;
	    foreach my $rank (sort {$a <=> $b} keys %FREQ) {
		my ($word, $freq) = split (':', decode('utf8', $FREQ{$rank}));
		if ($word =~ /\//) {
		    my $midasi = (split('/', $word))[0];

		    if ($midasi eq $key) {
			$new_key = $word; 
			$flag = 1;
			last;
		    }
		}
	    }
	    unless ($flag) {
		print "!!$key\n";
	    }
	}

	$SYNDB_NEW{$new_key} = $SYNDB{$key};
#	print "★$new_key\n";
#	Dumpvalue->new->dumpValue($SYNDB{$key});
    }

    &SynGraph::store_mldbm($edit_db_new, \%SYNDB_NEW);
}
else {
    my $log_dic_db = '/home/shibata/work/SynGraph/syndb/cgi/log_dic.cdb';
    my $edit_db = '/home/shibata/work/SynGraph/db/synonym_db_for_edit.db';

    &SynGraph::tie_cdb($log_dic_db, \%LOG);

    my %data;
    foreach my $key (keys %LOG) {
	$key = decode('utf8', $key);
	my $string = decode('utf8', $LOG{$key});

	my $ambiguity = 0;

	for my $line (split ("\n", $string)) {
	    $line =~ s/^<//;
	    $line =~ s/>$//;
	    my ($word, $definition) = split (' ', $line);

	    # definition.txt:薫る/かおる:1/1:1/1
	    my ($type, $w, $id) = split(':', $word, 3);
	    $type =~ s/\.txt$//;

#	push @{$data{$key}{elements}}, { type => $type, word => $w, id => $id, definition => $definition };
	    push @{$data{$key}{elements}}, { type => $type, origtype => $type, word => $w, id => $id, definition => $definition };

	    $ambiguity = 1 if $id ne '1/1:1/1';
	}

	$data{$key}{ambiguity} = $ambiguity;
    }

#    &SynGraph::store_mldbm($edit_db, \%data);
}
