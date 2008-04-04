package Constant;

# $Id$

# 定数をこのファイルで定義

use strict;
use utf8;

our $SynGraphBaseDir = '/home/shibata/work/SynGraph';

our $JumanCommand = '/home/harashima/usr/bin/juman';
our $JumanRcfile = '/home/harashima/usr/etc/jumanrc';
our $KnpCommand = '/home/shibata/tool/bin/knp';
our $KnpRcfile = '/home/shibata/.knprc';

our $JumanShareCommand = '/share/usr/bin/juman';
our $KnpShareCommand = '/share/usr/bin/knp';

# for CGI
our $RSK4CGIdb = $SynGraphBaseDir . '/ExtractSynfromDic/db/rsk4cgi.db';

# 分布類似度計算用のデータベース
our $CalcsimMidbfile = '/home/shibata/work/CalcSimilarityByCF/db/all-mi';
our $CalcsimCNMidbfile = '/home/shibata/work/CalcSimilarityByCF/db_compound_2/all-mi';

# for calc-similarity-synonym.pl
our $Oneformatted = '/home/shibata/work/CalcSimilarityByCF/one.formatted/080214.one.formatted';
our $Oneformatteddb = $SynGraphBaseDir . '/db/080214.one.formatted.db';

our $ContentWdic = '/home/shibata/download/juman/dic/ContentW.dic';

1;
