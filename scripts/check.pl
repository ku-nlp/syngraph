#!/usr/bin/env perl

use strict;
use encoding 'euc-jp';
use SynGraph;
binmode STDERR, ':encoding(euc-jp)';
use Dumpvalue;

my %WORD2FREQ;
&SynGraph::tie_cdb('/home/shibata/work/SynGraph/db/synonym_word2freq_all.db', \%WORD2FREQ);

my $edit_db = '/avocado6/shibata/synonym/db/synonym_db_for_edit_keyrep.db';
my $edit_db_new = '/avocado6/shibata/synonym/db/synonym_db_for_edit_keyrep_new.db';

my (%SYNDB, %SYNDB_NEW);
&SynGraph::tie_mldbm($edit_db, \%SYNDB);

for my $key (keys %SYNDB) {
    $SYNDB_NEW{$key} = $SYNDB{$key};
}

while (<>) {
    chomp;

    my @words = split;

    if (scalar @words > 2) {
	# 相棒/あいぼう
	my $word = (split ':', $words[0])[0];

	my ($rank) = (split ':', $WORD2FREQ{$word})[0];

	# 相棒/あいぼう:1/1:1/1
	my $midasi = shift @words;
	if ($rank > 0 && $rank < 2000) {
	    print STDERR "SKIP: $midasi", ' ' , $rank, ' ', join(' ', @words) , "\n";
	}
	else {
#	    my $midasi = shift @words;
	    if (defined $SYNDB{$word}) {
	
		print STDERR "$rank: $midasi\n";
		print join(' ', @words), "\n";
		# 先頭は捨てる
		shift @words;
		my $add_id = (split(':', $midasi, 2))[1];
		Dumpvalue->new->dumpValue($SYNDB{$word});

		for my $add_word (@words) {
		    my %new_element = ( definition => $add_word, id => $add_id, origtype => 'synonym', type => 'synonym', word => $word );
		    push @{$SYNDB_NEW{$word}{elements}}, \%new_element;
		}
		Dumpvalue->new->dumpValue($SYNDB_NEW{$word});
	    }
	    else {
		print STDERR "★$word\n";
	    }
	}
    }
}

&SynGraph::store_mldbm($edit_db_new, \%SYNDB_NEW);
