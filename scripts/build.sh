#!/bin/zsh

# $Id$

# ソースディレクトリ
SRC_DIR='.'

# 同義表現データマージ後ディレクトリ
SIM_C_DIR=../dic_change

# 同義表現データベース
SYNDB_DIR=../syndb/i686

# JUMAN
JUMAN=juman

log=0

while getopts ohlj: OPT
do
  case $OPT in
      o)  SYNDB_DIR=../syndb/x86_64
          ;;
      l)  log=1
	  SYNDB_DIR=../syndb/cgi
          ;;
      j)  JUMAN=$OPTARG
          ;;
      h)  usage
          ;;
    esac
done
shift `expr $OPTIND - 1`

# Perl module
PERL_DIR=../perl

# mysqlの場合 (文書単位の場合はmysqlでないといけない)
#DB_TYPE='mysql'
#DB_NAME='test_search'
#DB_TABLE='test'

# MLDBMの場合
DB_TYPE='mldbm'
DB_NAME='test_sg.mldbm'

# テキストデータ(KNP結果ファイル)
# head -100 ~/irex/mainichi/9401.convert | juman -e2 -B -i '#' | knp -tab > test.parse
TEXT_DATA='test.parse'

# インデックスファイル名
INDEX_FILE='test_index.db'

# パス設定
export PATH=$SRC_DIR:$PATH
export PERL5LIB=$SRC_DIR:$PERL5LIB

# 全部削除する
for f in synparent.cdb synantonym.cdb synnumber.cdb syndb.cdb synchild.cdb log_antonym.cdb log_isa.cdb synhead.cdb syndb.convert syndb.parse syndata.mldbm; do
    if [ -e $SYNDB_DIR/$f ] ; then
	rm -v $SYNDB_DIR/$f
    fi
done

# 全部削除する
if [ $log -eq 1 ]; then
    rm -v $SIM_C_DIR/log_merge2.txt
fi
rm -v df.db doclen.db
rm -v $INDEX_FILE
rm -v df.db doclen.db
rm -v $INDEX_FILE


########################################################
echo "STEP1 start\t`date`"
########################################################
# 類義表現を変換
if [ $log -eq 1 ]; then
    perl -I$PERL_DIR conv_syndb.pl --synonym_dic=$SIM_C_DIR/synonym_dic.txt --synonym_web_news=$SIM_C_DIR/synonym_web_news.txt --definition=$SIM_C_DIR/definition.txt --isa=$SIM_C_DIR/isa.txt --antonym=$SIM_C_DIR/antonym.txt --convert_file=$SYNDB_DIR/syndb.convert --syndbdir=$SYNDB_DIR --log_merge=$SIM_C_DIR/log_merge2.txt --option=log
else
    perl -I$PERL_DIR conv_syndb.pl --synonym_dic=$SIM_C_DIR/synonym_dic.txt --synonym_web_news=$SIM_C_DIR/synonym_web_news.txt --definition=$SIM_C_DIR/definition.txt --isa=$SIM_C_DIR/isa.txt --antonym=$SIM_C_DIR/antonym.txt --convert_file=$SYNDB_DIR/syndb.convert --syndbdir=$SYNDB_DIR
fi

# Juman & KNP
$JUMAN -e2 -B -i '#' < $SYNDB_DIR/syndb.convert | knp -dpnd -postprocess -tab > $SYNDB_DIR/syndb.parse

# コンパイル
if [ $log -eq 1 ]; then
    perl -I$PERL_DIR compile.pl --knp_result=$SYNDB_DIR/syndb.parse --syndbdir=$SYNDB_DIR --option=log
else
    perl -I$PERL_DIR compile.pl --knp_result=$SYNDB_DIR/syndb.parse --syndbdir=$SYNDB_DIR
fi

# synhead.mldbmのソート
perl -I$PERL_DIR sort_synhead.pl --syndbdir=$SYNDB_DIR

mv $SYNDB_DIR/synhead_sort.cdb $SYNDB_DIR/synhead.cdb
echo "STEP1 end\t`date`"

exit

########################################################
echo "STEP2 start\t`date`"
########################################################

# データベースがmysqlの場合
if [ $DB_TYPE = mysql ]
    then
    # データベースを作成
    echo "CREATE DATABASE IF NOT EXISTS $DB_NAME;" | mysql -uroot
    # 既にテーブルがある場合は削除する
    echo "DROP TABLE IF EXISTS $DB_TABLE;" | mysql -uroot $DB_NAME
    # テーブルを作成
    cat $SRC_DIR/syngraph.sql | sed "s/syngraph/$DB_TABLE/" | mysql -uroot $DB_NAME

# データベースがmysqlの場合
elif [ $DB_TYPE = mldbm ]
    then
    # データベースを削除する
    rm -v $DB_NAME
fi

# SYNGRAPHをデータベースに登録
make_sg.pl --text_data=$TEXT_DATA --db_type=$DB_TYPE --db_name=$DB_NAME --db_table=$DB_TABLE
# df計算
cal_df.pl --db_type=$DB_TYPE --db_name=$DB_NAME --db_table=$DB_TABLE
# インデックスファイル作成
indexing.pl --index_file=$INDEX_FILE --db_type=$DB_TYPE --db_name=$DB_NAME --db_table=$DB_TABLE
echo "STEP2 end\t`date`"


# 検索(テスト用)
# sentence_fileはなくてもOK
# perl -I. search.pl --db_type mysql --db_name test_search --db_table test --sentence_file ~/irex/sentence.db --index_file test_index.db
