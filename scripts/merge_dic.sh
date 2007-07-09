#!/bin/zsh

# �������ǥ��쥯�ȥ�
SRC_DIR='.'

# Ʊ��ɽ���ǡ����ǥ��쥯�ȥ�
SIM_DIR_Dic=../dic/rsk_iwanami
SIM_DIR_Web=../dic/web_news

# Ʊ��ɽ���ǡ����ޡ�������Υǥ��쥯�ȥ�
SIM_M_DIR=../dic_middle

# Ʊ��ɽ���ǡ����ޡ�����Υǥ��쥯�ȥ�
SIM_C_DIR=../dic_change

# Ʊ��ɽ���ǡ����١���
SYNDB_DIR=../syndb/cgi

while getopts h OPT
do
  case $OPT in
      h)  usage
          ;;
    esac
done
shift `expr $OPTIND - 1`

# Perl module
PERL_DIR=../perl

# �ѥ�����
export PATH=$SRC_DIR:$PATH
export PERL5LIB=$SRC_DIR:$PERL5LIB


# �����������
for f in definition.txt synonym_dic.txt isa.txt antonym.txt synonym_web_news.txt log_merge.txt; do
    if [ -e $SIM_C_DIR/$f ] ; then
	rm -v $SIM_C_DIR/$f
    fi
done

if [ -e $SYNDB_DIR/log_dic.cdb ] ; then
    rm -v $SYNDB_DIR/log_dic.cdb
fi


########################################################
echo "STEP1 start\t`date`"
########################################################
# ���񤫤���μ���ФΥ�������CGI�ѡ�
perl -I$PERL_DIR make_logdic.pl --synonym=$SIM_DIR_Dic/synonym.txt --definition=$SIM_DIR_Dic/definition.txt --isa=$SIM_DIR_Dic/isa.txt --antonym=$SIM_DIR_Dic/antonym.txt --syndbdir=$SYNDB_DIR

# ���񤫤��Ʊ���ط�(synonym, same_difinition)���μ���Ϣ��
perl cat_synonym_same_def.pl -synonym_dic=$SIM_DIR_Dic/synonym.txt -same_diff=$SIM_DIR_Dic/same_definition.txt -cat_file=$SIM_M_DIR/synonym_dic.txt

# ���񤫤���μ�������
perl check_synonym_dic.pl --synonym_dic=$SIM_M_DIR/synonym_dic.txt --log_merge=$SIM_C_DIR/log_merge_synonym_dic.txt --change=$SIM_M_DIR/synonym_dic2.txt
perl check_synonym_dic.pl --synonym_dic=$SIM_DIR_Dic/antonym.txt --log_merge=$SIM_C_DIR/log_merge_antonym_dic.txt --change=$SIM_M_DIR/antonym.txt

# Web������μ�������
#perl check_duplicate_entry.pl -rnsame --synonym_web_news=$SIM_DIR_Web/all.txt --log_merge=$SIM_C_DIR/log_merge_synonym_web_news.txt --change=$SIM_M_DIR/synonym_web_news.txt

# Web������μ����鼭�񤫤���μ��Ƚ�ʣ��������
perl check_dic_web_news_duplicate.pl --dic=$SIM_M_DIR/synonym_dic2.txt --web=$SIM_M_DIR/synonym_web_news.txt --log_merge=$SIM_C_DIR/log_delete_web_news.txt --change=$SIM_C_DIR/synonym_web_news.txt

# ������Ѵ���¿�����ΰ�����
perl -I$PERL_DIR change_dic.pl --synonym=$SIM_M_DIR/synonym_dic2.txt --definition=$SIM_DIR_Dic/definition.txt --isa=$SIM_DIR_Dic/isa.txt --antonym=$SIM_M_DIR/antonym.txt --synonym_change=$SIM_C_DIR/synonym_dic.txt --isa_change=$SIM_C_DIR/isa.txt --antonym_change=$SIM_C_DIR/antonym.txt

cp $SIM_DIR_Dic/definition.txt $SIM_C_DIR/definition.txt
