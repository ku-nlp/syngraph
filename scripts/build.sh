#!/bin/zsh

# $Id$

# �������ǥ��쥯�ȥ�
SRC_DIR='.'

# Ʊ��ɽ���ǡ����ǥ��쥯�ȥ�
SIM_DIR=../dic

# Ʊ��ɽ���ǡ����١���
SYNDB_DIR=../syndb

# Perl module
PERL_DIR=../perl

# mysql�ξ�� (ʸ��ñ�̤ξ���mysql�Ǥʤ��Ȥ����ʤ�)
#DB_TYPE='mysql'
#DB_NAME='test_search'
#DB_TABLE='test'

# MLDBM�ξ��
DB_TYPE='mldbm'
DB_NAME='test_sg.mldbm'

# �ƥ����ȥǡ���(KNP��̥ե�����)
# head -100 ~/irex/mainichi/9401.convert | juman -e2 -B -i '#' | knp -tab > test.parse
TEXT_DATA='test.parse'

# ����ǥå����ե�����̾
INDEX_FILE='test_index.db'

# �ѥ�����
export PATH=$SRC_DIR:$PATH
export PERL5LIB=$SRC_DIR:$PERL5LIB



# �����������
rm -v $SYNDB_DIR/synparent.mldbm $SYNDB_DIR/synantonym.mldbm syndb.convert
rm -v syndb.parse
rm -v $SYNDB_DIR/synhead.mldbm $SYNDB_DIR/syndata.mldbm
rm -v df.db doclen.db
rm -v $INDEX_FILE



########################################################
echo "STEP1 start\t`date`"
########################################################

# ���ɽ�����Ѵ�
perl -I$PERL_DIR conv_syndb.pl --synonym=$SIM_DIR/synonym.txt --definition=$SIM_DIR/definition.txt --relation=$SIM_DIR/relation.txt --antonym=$SIM_DIR/antonym.txt --convert_file=syndb.convert --syndbdir=$SYNDB_DIR

# Juman & KNP
juman -e2 -B -i '#' < syndb.convert | knp -tab > syndb.parse
# ����ѥ���
perl -I$PERL_DIR compile.pl --knp_result=syndb.parse --syndbdir=$SYNDB_DIR
# synhead.mldbm�Υ�����
# syndata��tie�Ǥ��ʤ�(odani0116)
#perl -I$PERL_DIR sort_synhead.pl --syndbdir=$SYNDB_DIR

#mv $SYNDB_DIR/synhead_sort.mldbm $SYNDB_DIR/synhead.mldbm
echo "STEP1 end\t`date`"

exit

########################################################
echo "STEP2 start\t`date`"
########################################################

# �ǡ����١�����mysql�ξ��
if [ $DB_TYPE = mysql ]
    then
    # �ǡ����١��������
    echo "CREATE DATABASE IF NOT EXISTS $DB_NAME;" | mysql -uroot
    # ���˥ơ��֥뤬������Ϻ������
    echo "DROP TABLE IF EXISTS $DB_TABLE;" | mysql -uroot $DB_NAME
    # �ơ��֥�����
    cat $SRC_DIR/syngraph.sql | sed "s/syngraph/$DB_TABLE/" | mysql -uroot $DB_NAME

# �ǡ����١�����mysql�ξ��
elif [ $DB_TYPE = mldbm ]
    then
    # �ǡ����١�����������
    rm -v $DB_NAME
fi

# SYNGRAPH��ǡ����١�������Ͽ
make_sg.pl --text_data=$TEXT_DATA --db_type=$DB_TYPE --db_name=$DB_NAME --db_table=$DB_TABLE
# df�׻�
cal_df.pl --db_type=$DB_TYPE --db_name=$DB_NAME --db_table=$DB_TABLE
# ����ǥå����ե��������
indexing.pl --index_file=$INDEX_FILE --db_type=$DB_TYPE --db_name=$DB_NAME --db_table=$DB_TABLE
echo "STEP2 end\t`date`"


# ����(�ƥ�����)
# sentence_file�Ϥʤ��Ƥ�OK
# perl -I. search.pl --db_type mysql --db_name test_search --db_table test --sentence_file ~/irex/sentence.db --index_file test_index.db
