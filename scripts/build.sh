#!/bin/zsh

# $Id$

# ソースディレクトリ
SRC_DIR='.'

# 同義表現データディレクトリ
SIM_DIR=../dic

# 同義表現データベース
SYNDB_DIR=../syndb

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
rm -v $SYNDB_DIR/synparent.mldbm $SYNDB_DIR/synantonym.mldbm syndb.convert
rm -v syndb.parse
rm -v $SYNDB_DIR/synhead.mldbm $SYNDB_DIR/syndata.mldbm
rm -v df.db doclen.db
rm -v $INDEX_FILE



########################################################
echo "STEP1 start\t`date`"
########################################################

# 類義表現を変換
perl -I$PERL_DIR conv_syndb.pl --synonym=$SIM_DIR/synonym.txt --definition=$SIM_DIR/definition.txt --relation=$SIM_DIR/relation.txt --antonym=$SIM_DIR/antonym.txt --convert_file=syndb.convert --syndbdir=$SYNDB_DIR

# Juman & KNP
juman -e2 -B -i '#' < syndb.convert | knp -tab > syndb.parse
# コンパイル
perl -I$PERL_DIR compile.pl --knp_result=syndb.parse --syndbdir=$SYNDB_DIR
# synhead.mldbmのソート
# syndataをtieできない(odani0116)
#perl -I$PERL_DIR sort_synhead.pl --syndbdir=$SYNDB_DIR

#mv $SYNDB_DIR/synhead_sort.mldbm $SYNDB_DIR/synhead.mldbm
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
