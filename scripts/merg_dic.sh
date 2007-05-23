#!/bin/zsh

# �������ǥ��쥯�ȥ�
SRC_DIR='.'

# Ʊ��ɽ���ǡ����ǥ��쥯�ȥ�
SIM_DIR_Dic=../dic/dic_rsk_iwanami
SIM_DIR_Web=../dic/dic_web

# Ʊ��ɽ���ǡ����ޡ�����Υǥ��쥯�ȥ�
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

# �ѥ�����
export PATH=$SRC_DIR:$PATH
export PERL5LIB=$SRC_DIR:$PERL5LIB


# �����������
for f in definition.txt, synonym_dic.txt, isa.txt, antonym.txt, synonym_web.txt, log_merge.txt; do
    if [ -e $SIM_C_DIR/$f ] ; then
	rm -v $SIM_C_DIR/$f
    fi
done

rm -v $SYNDB_DIR/log_dic.db
#rm -v $SIM_C_DIR/definition.txt $SIM_C_DIR/synonym_rsk.txt $SIM_C_DIR/isa.txt $SIM_C_DIR/antonym.txt $SIM_C_DIR/synonym_web.txt 
#rm -v $SIM_C_DIR/log_merge.txt

########################################################
echo "STEP1 start\t`date`"
########################################################
# ���񤫤���μ���ФΥ�������CGI�ѡ�
perl -I$PERL_DIR make_logdic.pl --synonym=$SIM_DIR_Dic/synonym.txt --definition=$SIM_DIR_Dic/definition.txt --isa=$SIM_DIR_Dic/isa.txt --antonym=$SIM_DIR_Dic/antonym.txt --syndbdir=$SYNDB_DIR

# ������Ѵ���¿�����ΰ�����
perl -I$PERL_DIR change_dic.pl --synonym=$SIM_DIR_Dic/synonym.txt --definition=$SIM_DIR_Dic/definition.txt --isa=$SIM_DIR_Dic/isa.txt --antonym=$SIM_DIR_Dic/antonym.txt --synonym_change=$SIM_C_DIR/synonym_dic.txt --isa_change=$SIM_C_DIR/isa.txt --antonym_change=$SIM_C_DIR/antonym.txt

cp $SIM_DIR_Dic/definition.txt $SIM_C_DIR/definition.txt

# Web����μ��������
# perl check_duplicate_entry.pl -rnsame < $SIM_DIR/synonym_web.txt > $SIM_C_DIR/synonym_web.txt
perl check_duplicate_entry.pl -rnsame --synonym_web=$SIM_DIR_Web/all.txt --log_merge=$SIM_C_DIR/log_merge.txt --change=$SIM_C_DIR/synonym_web.txt
