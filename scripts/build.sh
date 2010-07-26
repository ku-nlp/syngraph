#!/bin/zsh

# $Id$

# �������ǥ��쥯�ȥ�
SRC_DIR='.'

# Ʊ��ɽ���ǡ����ޡ�����ǥ��쥯�ȥ�
SIM_C_DIR=../dic_change

# Ʊ��ɽ���ǡ����١���
SYNDB_DIR=../syndb/i686

# JUMAN
JUMAN=juman

# JUMANRC
JUMANRCFILE=
jumanrc=

# KNP Options
knpopts=()
k=1

conv_syndb_args=

# WWW2sf
WWW2sfdir=$HOME/work/WWW2sf

log=0
noparse=0
wikipedia=0

while getopts ohlj:r:ndwi: OPT
do
  case $OPT in
      o)  SYNDB_DIR=../syndb/x86_64
          ;;
      l)  log=1
	  SYNDB_DIR=../syndb/cgi
          ;;
      j)  JUMAN=$OPTARG
          ;;
      r)  JUMANRCFILE=$OPTARG
	  jumanrc=1
          ;;
      n)  noparse=1
	  ;;
      d)  knpopts[k]="-dpnd"
	  k=`expr $k + 1`
	  ;;
      w)  wikipedia=1
          ;;
      i)  conv_syndb_args="$conv_syndb_args -isa_max_num $OPTARG"
          ;;
      h)  usage
          ;;
    esac
done
shift `expr $OPTIND - 1`

# KNP default options
knpopts[k]="-postprocess -tab"
k=`expr $k + 1`

# Perl module
PERL_DIR=../perl

# �ѥ�����
export PATH=$SRC_DIR:$PATH
export PERL5LIB=$SRC_DIR:$PERL5LIB

# �����������
for f in synparent.cdb synantonym.cdb synnumber.cdb syndb.cdb synchild.cdb log_antonym.cdb log_isa.cdb synhead.cdb syndb.convert syndb.parse syndata.mldbm syndb.jmn; do
    if [ -e $SYNDB_DIR/$f ] ; then
	rm -vf $SYNDB_DIR/$f
    fi
done

# �����������
if [ $log -eq 1 ]; then
    rm -vf $SIM_C_DIR/log_merge2.txt
fi

# ���ɽ�����Ѵ�
if [ $wikipedia -eq 1 ]; then
    if [ $log -eq 1 ]; then
	exe="perl -I$PERL_DIR conv_syndb.pl --synonym_dic=$SIM_C_DIR/synonym_dic.txt --synonym_web_news=$SIM_C_DIR/synonym_web_news_aimai.txt --definition=$SIM_C_DIR/definition.txt --isa=$SIM_C_DIR/isa.txt --isa_wikipedia=$SIM_C_DIR/isa_wikipedia.txt --antonym=$SIM_C_DIR/antonym.txt --convert_file=$SYNDB_DIR/syndb.convert --syndbdir=$SYNDB_DIR --log_merge=$SIM_C_DIR/log_merge2.txt --option=log -wikipedia ${=conv_syndb_args}"
    else
	exe="perl -I$PERL_DIR conv_syndb.pl --synonym_dic=$SIM_C_DIR/synonym_dic.txt --synonym_web_news=$SIM_C_DIR/synonym_web_news_aimai.txt --definition=$SIM_C_DIR/definition.txt --isa=$SIM_C_DIR/isa.txt --isa_wikipedia=$SIM_C_DIR/isa_wikipedia.txt --antonym=$SIM_C_DIR/antonym.txt --convert_file=$SYNDB_DIR/syndb.convert --syndbdir=$SYNDB_DIR -wikipedia -similar_phrase ../dic/rsk_iwanami/automatic_similar_phrase.txt ${=conv_syndb_args}"
    fi
else
    if [ $log -eq 1 ]; then
	exe="perl -I$PERL_DIR conv_syndb.pl --synonym_dic=$SIM_C_DIR/synonym_dic.txt --synonym_web_news=$SIM_C_DIR/synonym_web_news.txt --definition=$SIM_C_DIR/definition.txt --isa=$SIM_C_DIR/isa.txt --antonym=$SIM_C_DIR/antonym.txt --convert_file=$SYNDB_DIR/syndb.convert --syndbdir=$SYNDB_DIR --log_merge=$SIM_C_DIR/log_merge2.txt --option=log ${=conv_syndb_args}"
    else
	exe="perl -I$PERL_DIR conv_syndb.pl --synonym_dic=$SIM_C_DIR/synonym_dic.txt --synonym_web_news=$SIM_C_DIR/synonym_web_news.txt --definition=$SIM_C_DIR/definition.txt --isa=$SIM_C_DIR/isa.txt --antonym=$SIM_C_DIR/antonym.txt --convert_file=$SYNDB_DIR/syndb.convert --syndbdir=$SYNDB_DIR ${=conv_syndb_args}"
    fi
fi
echo $exe
eval $exe

# Juman & KNP
SYNDBPARSE=../syndb/x86_64/syndb.parse
if [ $noparse -eq 1 -a -e $SYNDBPARSE ]; then
    exe="cp $SYNDBPARSE $SYNDB_DIR/"
else
    if [ $jumanrc -eq 1 ]; then
	exe="perl word_into_juman.pl -C $JUMAN -R $JUMANRCFILE < $SYNDB_DIR/syndb.convert > $SYNDB_DIR/syndb.jmn"
    else
	exe="perl word_into_juman.pl -C $JUMAN < $SYNDB_DIR/syndb.convert > $SYNDB_DIR/syndb.jmn"
    fi
    echo $exe
    eval $exe

    exe="$WWW2sfdir/tool/scripts/parse-comp.sh -k \"$knpopts[*]\" $SYNDB_DIR/syndb.jmn && mv $SYNDB_DIR/syndb.knp $SYNDB_DIR/syndb.parse"
fi

echo $exe
eval $exe

# ����ѥ���
if [ $log -eq 1 ]; then
    exe="perl -I$PERL_DIR compile.pl --knp_result=$SYNDB_DIR/syndb.parse --syndbdir=$SYNDB_DIR --option=log"
else
    exe="perl -I$PERL_DIR compile.pl --knp_result=$SYNDB_DIR/syndb.parse --syndbdir=$SYNDB_DIR"
fi
echo $exe
eval $exe

# synhead.mldbm�Υ�����
exe="perl -I$PERL_DIR sort_synhead.pl --syndbdir=$SYNDB_DIR"
echo $exe
eval $exe

rm -f $SYNDB_DIR/synhead.cdb

exe="mv $SYNDB_DIR/synhead_sort.cdb $SYNDB_DIR/synhead.cdb"
echo $exe
eval $exe

if [ $noparse -eq 1 ]; then
    rm -f syndb.parse
fi

