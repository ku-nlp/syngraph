#!/bin/zsh

# �������ǥ��쥯�ȥ�
SRC_DIR='.'

# Ʊ��ɽ���ǡ����ǥ��쥯�ȥ�
SIM_DIR_Dic=../dic/rsk_iwanami
SIM_DIR_Web=../dic/web_news
SIM_DIR_Wikipedia=../dic/wikipedia

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

wikipedia=0

while getopts wh OPT
do
  case $OPT in
      w)  wikipedia=1
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
for f in definition.txt synonym_dic.txt isa.txt isa_wikipedia.txt antonym.txt synonym_web_news.txt log_merge.txt; do
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
exe="perl -I$PERL_DIR -I$KAWAHARAPMDIR check_synonym_in_juman_dic.pl -jumandicdir $JUMANDICDIR < $SIM_DIR_Web/www.txt > $SIM_DIR_Web/www.txt.jumanremoved 2> $SIM_DIR_Web/www.txt.jumanremoved.log"
echo $exe
eval $exe

exe="cat $SIM_DIR_Web/nation.txt $SIM_DIR_Web/news.txt $SIM_DIR_Web/www.txt.jumanremoved > $SIM_DIR_Web/all.txt.jumanremoved"
echo $exe
eval $exe

# ���񤫤���μ���ФΥ�������CGI�ѡ�
exe="perl -I$PERL_DIR make_logdic.pl --synonym=$SIM_DIR_Dic/synonym.txt.filtered --definition=$SIM_DIR_Dic/definition.txt --isa=$SIM_DIR_Dic/isa.txt.filtered --antonym=$SIM_DIR_Dic/antonym.txt --syndbdir=$SYNDB_DIR"
echo $exe
eval $exe

# ���񤫤��Ʊ���ط�(synonym, same_difinition)���μ���Ϣ��
exe="perl -I../perl cat_synonym_same_def.pl --synonym_dic=$SIM_DIR_Dic/synonym.txt.filtered --same_definition=$SIM_DIR_Dic/same_definition.txt --synonym_filter_log=$SIM_DIR_Dic/synonym-filter.log > $SIM_M_DIR/synonym_dic.txt 2> $SIM_M_DIR/cat_synonym_same_def.log"
echo $exe
eval $exe

# ���񤫤���μ����������ʥޡ�����
exe="perl -I../perl check_synonym_merge.pl < $SIM_M_DIR/synonym_dic.txt > $SIM_M_DIR/synonym_dic.txt.merge 2>$SIM_C_DIR/synonym_dic.txt.merge.log"
echo $exe
eval $exe

exe="perl -I../perl check_antonym.pl < $SIM_DIR_Dic/antonym.txt > $SIM_M_DIR/antonym.txt.merge 2>$SIM_C_DIR/antonym.txt.merge.log"
echo $exe
eval $exe

# ���񤫤���μ�����������ۣ�����Τʤ����𤷤�Ʊ�����롼�פ�Ϣ���
exe="perl -I../perl check_synonym_add.pl --noambiguity_file=$SIM_DIR_Dic/noambiguity.txt < $SIM_M_DIR/synonym_dic.txt.merge > $SIM_M_DIR/synonym_dic.txt.merge.add 2>$SIM_C_DIR/synonym_dic.txt.merge.add.log"
echo $exe
eval $exe

# Web������μ�������
exe="perl -I$PERL_DIR -I$UTILS check_duplicate_entry.pl -merge -rnsame -editdistance < $SIM_DIR_Web/all.txt.jumanremoved > $SIM_M_DIR/synonym_web_news.txt 2> $SIM_C_DIR/synonym_web_news.txt.log"
echo $exe
eval $exe

# Web������μ����鼭�񤫤���μ��Ƚ�ʣ��������
# ����Ʊ�����롼�פ�Ϣ��򤷤ʤ�
exe="perl check_dic_web_news_duplicate.pl --dic=$SIM_M_DIR/synonym_dic.txt.merge.add --web=$SIM_M_DIR/synonym_web_news.txt --log_merge=$SIM_C_DIR/web_news.txt.log > $SIM_M_DIR/synonym_web_news.txt.dicremoved"
echo $exe
eval $exe

# ʬ������٤�Ȥäƥޡ���
exe="perl -I$UTILS -I$PERL_DIR check_duplicate_entry.pl -distributional_similarity -read_multiple_entries -merge < $SIM_M_DIR/synonym_web_news.txt.dicremoved > $SIM_C_DIR/synonym_web_news.txt 2> $SIM_M_DIR/synonym_web_news.txt.dicremoved.log"
echo $exe
eval $exe

# ���������(¿���Ǥʤ���ˡ�:1/1:1/1�פ���Ϳ���Ҥ餬�ʣ�ʸ���ʲ������Ⱦ�Ѥ����Ѥ�)
# ����Ʊ�����롼�פ�Ϣ��򤷤ʤ�
exe="perl -I$PERL_DIR change_dic.pl --synonym=$SIM_M_DIR/synonym_dic.txt.merge.add --definition=$SIM_DIR_Dic/definition.txt --isa=$SIM_DIR_Dic/isa.txt.filtered --antonym=$SIM_M_DIR/antonym.txt.merge --synonym_change=$SIM_C_DIR/synonym_dic.txt.merge.add.postprocess --isa_change=$SIM_C_DIR/isa.txt --antonym_change=$SIM_C_DIR/antonym.txt --definition_change=$SIM_C_DIR/definition.txt --komidasi_num=$SIM_DIR_Dic/komidasi_num.txt --log=$SIM_C_DIR/change.log"
echo $exe
eval $exe

# �Ҥ餬�ʤ�ۣ�������
exe="perl -I$PERL_DIR disambiguation_hiragana.pl < $SIM_C_DIR/synonym_dic.txt.merge.add.postprocess > $SIM_C_DIR/synonym_dic.txt 2> $SIM_C_DIR/synonym_dic.hiragana_disambiguation.log"
echo $exe
eval $exe

# Wikipedia��������줿���ɽ���Τ�������켭ŵ�������Ф�����Τ���
if [ $wikipedia -eq 1 ]; then
    exe="perl -I$PERL_DIR check_dic_wikipedia_duplicate.pl -dic $SIM_C_DIR/isa.txt -wikipedia $SIM_DIR_Wikipedia/isa.txt > $SIM_C_DIR/isa_wikipedia.txt 2> $SIM_C_DIR/isa_wikipedia.log"
    echo $exe
    eval $exe
fi

