#!/bin/zsh

# $Id$

# �������ǥ��쥯�ȥ�
SRC_DIR='.'

# Ʊ��ɽ���ǡ����ޡ�����ǥ��쥯�ȥ�
SIM_C_DIR=../dic_change

# Ʊ��ɽ���ǡ����١���
SYNDB_DIR=../syndb/i686

while getopts oh OPT
do
  case $OPT in
      o)  SYNDB_DIR=../syndb/x86_64
          ;;
      h)  usage
          ;;
    esac
done
shift `expr $OPTIND - 1`

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
rm -v $SYNDB_DIR/synparent.db $SYNDB_DIR/synantonym.db
rm -v $SYNDB_DIR/synnumber.db $SYNDB_DIR/syndb.db $SYNDB_DIR/synchild.db
rm -v $SYNDB_DIR/log_antonym.db $SYNDB_DIR/log_isa.db
rm -v $SYNDB_DIR/syndb.convert $SYNDB_DIR/syndb.parse
rm -v $SYNDB_DIR/synhead.db $SYNDB_DIR/syndata.mldbm
rm -v df.db doclen.db
rm -v $INDEX_FILE


########################################################
echo "STEP1 start\t`date`"
########################################################
# ���ɽ�����Ѵ�
perl -I$PERL_DIR conv_syndb.pl --synonym_rsk=$SIM_C_DIR/synonym_rsk.txt --synonym_web=$SIM_C_DIR/synonym_web.txt --definition=$SIM_C_DIR/definition.txt --isa=$SIM_C_DIR/isa.txt --antonym=$SIM_C_DIR/antonym.txt --convert_file=$SYNDB_DIR/syndb.convert --syndbdir=$SYNDB_DIR --log_merge=$SIM_C_DIR/log_merge.txt

# Juman & KNP
juman -e2 -B -i '#' < $SYNDB_DIR/syndb.convert | knp -dpnd -postprocess -tab > $SYNDB_DIR/syndb.parse
# ����ѥ���
perl -I$PERL_DIR compile.pl --knp_result=$SYNDB_DIR/syndb.parse --syndbdir=$SYNDB_DIR
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
