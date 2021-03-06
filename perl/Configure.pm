package Configure;

# 定数をこのファイルで定義

use strict;
use utf8;
use File::Basename;

our $SynGraphBaseDir;

BEGIN {
    $SynGraphBaseDir = dirname($INC{'Configure.pm'}) . '/..';
}

our $JumanCommand = '/home/shibata/tool-dic-analyze/bin/juman';
our $JumanRcfile = '/home/shibata/tool-dic-analyze/etc/jumanrc';
our $KnpCommand = '/home/shibata/tool-x86_64/bin/knp';
our $KnpRcfile = '/home/shibata/.knprc';

our $JumanShareCommand = '/share/usr/bin/juman';
our $KnpShareCommand = '/share/usr/bin/knp';

# for CGI
our $RSK4CGIdb = $SynGraphBaseDir . '/ExtractSynfromDic/db/rsk4cgi.db';
our $Rep2Hinsidb = $SynGraphBaseDir . '/ExtractSynfromDic/db/rep2hinsi.db';
our $Wikipediadb = $SynGraphBaseDir . '/ExtractSynfromDic/db/wikipedia.db';

# 分布類似度計算用のデータベース
our $CalcsimMidbfile = '/home/shibata/work/CalcSimilarityByCF/db/all-mi';
our $CalcsimCNMidbfile = '/home/shibata/work/CalcSimilarityByCF/db_compound_2_100M_1_de/all-mi';
our $CalcsimVerbMidbfile = '/vine7/shibata/backup/db_compound_1_100M_1_de_verb/all-mi';

# for calc-similarity-synonym.pl
our $Oneformatted = '/home/shibata/work/CalcSimilarityByCF/one.formatted/080214.one.formatted';
our $Oneformatteddb = '/home/shibata/work/SynGraph/db/080214.one.formatted.db';

our $ContentWdic = '/home/shibata/download/juman/dic/ContentW.dic';

our $CN_DF_DB = '/home/shibata/cns.100M.cls.df1000.cdb';
our $DF_REP_DB = '/home/shibata/work/SynGraph/db/synonym_word2freq_all_50000.db';
our $SYNONYM_WORD2FREQ_DB = '/home/shibata/work/SynGraph/db/synonym_word2freq_all.db';

1;
