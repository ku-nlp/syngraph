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

# Juman����
JUMANDICDIR=/home/shibata/download/juman/dic

# kawahara-pm
KAWAHARAPMDIR=/home/shibata/work/kawahara-pm/perl

# Utilsdir
UTILS=/home/shibata/work/Utils/perl

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

# ξ����Juman�������Ͽ����Ƥ���Ʊ��ɽ���κ��
exe="perl -I$KAWAHARAPMDIR check_synonym_in_juman_dic.pl -jumandicdir $JUMANDICDIR < $SIM_DIR_Web/www.txt > $SIM_DIR_Web/www.txt.jumanremoved 2> $SIM_DIR_Web/www.txt.jumanremoved.log"
echo $exe
eval $exe

exe="cat $SIM_DIR_Web/nation.txt $SIM_DIR_Web/news.txt $SIM_DIR_Web/www.txt.jumanremoved > $SIM_DIR_Web/all.txt.jumanremoved"
echo $exe
eval $exe

# ���񤫤���μ���ФΥ�������CGI�ѡ�
exe="perl -I$PERL_DIR make_logdic.pl --synonym=$SIM_DIR_Dic/synonym.txt --definition=$SIM_DIR_Dic/definition.txt --isa=$SIM_DIR_Dic/isa.txt --antonym=$SIM_DIR_Dic/antonym.txt --syndbdir=$SYNDB_DIR"
echo $exe
eval $exe

# ���񤫤��Ʊ���ط�(synonym, same_difinition)���μ���Ϣ��
exe="perl cat_synonym_same_def.pl -synonym_dic=$SIM_DIR_Dic/synonym.txt -same_diff=$SIM_DIR_Dic/same_definition.txt > $SIM_M_DIR/synonym_dic.txt"
echo $exe
eval $exe

# ���񤫤���μ����������ʥޡ�����
exe="perl -I../perl check_synonym_merge.pl < $SIM_M_DIR/synonym_dic.txt > $SIM_M_DIR/synonym_dic.txt.merge 2>$SIM_C_DIR/synonym_dic.txt.merge.log"
echo $exe
eval $exe

exe="perl -I../perl check_antonym.pl < $SIM_DIR_Dic/antonym.txt > $SIM_M_DIR/antonym.txt.merge 2>$SIM_C_DIR/antonym.txt.merge.log"
echo $exe
eval $exe

# ���񤫤���μ�����������ۣ�����Τʤ����𤷤�Ϣ���
exe="perl -I../perl check_synonym_add.pl --ambiguity_files=$SIM_DIR_Dic/noambiguity.txt < $SIM_M_DIR/synonym_dic.txt.merge > $SIM_M_DIR/synonym_dic.txt.merge.add 2>$SIM_C_DIR/synonym_dic.txt.merge.add.log"
echo $exe
eval $exe

# Web������μ�������
exe="perl -I$UTILS check_duplicate_entry.pl -merge -rnsame -editdistance < $SIM_DIR_Web/all.txt.jumanremoved > $SIM_M_DIR/synonym_web_news.txt 2> $SIM_C_DIR/synonym_web_news.txt.log"
echo $exe
eval $exe

# Web������μ����鼭�񤫤���μ��Ƚ�ʣ��������
exe="perl check_dic_web_news_duplicate.pl --dic=$SIM_M_DIR/synonym_dic.txt.merge.add --web=$SIM_M_DIR/synonym_web_news.txt --log_merge=$SIM_C_DIR/web_news.txt.log > $SIM_C_DIR/synonym_web_news.txt"
echo $exe
eval $exe

# ������Ѵ���¿�����ΰ�����
exe="perl -I$PERL_DIR change_dic.pl --synonym=$SIM_M_DIR/synonym_dic.txt.merge.add --definition=$SIM_DIR_Dic/definition.txt --isa=$SIM_DIR_Dic/isa.txt --antonym=$SIM_M_DIR/antonym.txt.merge --synonym_change=$SIM_C_DIR/synonym_dic.txt --isa_change=$SIM_C_DIR/isa.txt --antonym_change=$SIM_C_DIR/antonym.txt"
echo $exe
eval $exe

exe="cp $SIM_DIR_Dic/definition.txt $SIM_C_DIR/definition.txt"
echo $exe
eval $exe
