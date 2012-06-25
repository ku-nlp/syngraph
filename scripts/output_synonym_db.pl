#!/usr/bin/env perl

use strict;
use encoding 'euc-jp';
use SynGraph;
use Encode;

my %datatype = ( 'definition' => 'Ʊ����', 'antonym' => 'ȿ����', 'isa' => '��̸�', 'synonym' => 'Ʊ����', 'nouse' => '�Ȥ�ʤ�', 'question' => '��' );

my $syndb = '/home/shibata/work/SynGraph/db/synonym_db_for_edit_keyrep_new_backup.db';
my (%SYNDB, %FREQ);
&SynGraph::tie_mldbm($syndb, \%SYNDB);
&SynGraph::tie_cdb('/home/shibata/work/SynGraph/db/synonym_freq_all_50000.db', \%FREQ);

my @data;
# ��̤ǥ����ȡʾ����
foreach my $rank (sort {$a <=> $b} keys %FREQ) {
    my ($word, $freq) = split (':', decode('utf8', $FREQ{$rank}));
    next unless ($word =~ /\//);
    my $syndata = $SYNDB{$word};
    if ($syndata && defined $syndata->{username}) {
	print $word, "\n";

	next unless defined $syndata->{elements};
	for (sort {$a->{id} cmp $b->{id}} @{$syndata->{elements}}) {
	    print " $_->{id} [$datatype{$_->{type}}] $_->{definition}\n";
# 	    for my $key ('origtype', 'type', 'word', 'id', 'definition') {
# 		print " $key: $_->{$key}\n";
# 	    }
	}
    }
}
