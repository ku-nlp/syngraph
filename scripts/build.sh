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

# JUMANRC
JUMANRCFILE=
jumanrc=

# KNP Options
knpopts=()
k=1

log=0
noparse=0

while getopts ohlj:r:nd OPT
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

# 類義表現を変換
if [ $log -eq 1 ]; then
    exe="perl -I$PERL_DIR conv_syndb.pl --synonym_dic=$SIM_C_DIR/synonym_dic.txt --synonym_web_news=$SIM_C_DIR/synonym_web_news.txt --definition=$SIM_C_DIR/definition.txt --isa=$SIM_C_DIR/isa.txt --antonym=$SIM_C_DIR/antonym.txt --convert_file=$SYNDB_DIR/syndb.convert --syndbdir=$SYNDB_DIR --log_merge=$SIM_C_DIR/log_merge2.txt --option=log"
else
    exe="perl -I$PERL_DIR conv_syndb.pl --synonym_dic=$SIM_C_DIR/synonym_dic.txt --synonym_web_news=$SIM_C_DIR/synonym_web_news.txt --definition=$SIM_C_DIR/definition.txt --isa=$SIM_C_DIR/isa.txt --antonym=$SIM_C_DIR/antonym.txt --convert_file=$SYNDB_DIR/syndb.convert --syndbdir=$SYNDB_DIR"
fi
echo $exe
eval $exe

# Juman & KNP
SYNDBPARSE=../syndb/x86_64/syndb.parse
if [ $noparse -eq 1 -a -e $SYNDBPARSE ]; then
    exe="cp $SYNDBPARSE $SYNDB_DIR/"
else
    if [ $jumanrc -eq 1 ]; then
#	exe="$JUMAN -e2 -B -i '#' -r $JUMANRCFILE < $SYNDB_DIR/syndb.convert | knp $knpopts[*] > $SYNDB_DIR/syndb.parse"
	exe="perl word_into_juman.pl -C $JUMAN -R $JUMANRCFILE < $SYNDB_DIR/syndb.convert | knp $knpopts[*] > $SYNDB_DIR/syndb.parse"
    else
#	exe="$JUMAN -e2 -B -i '#' < $SYNDB_DIR/syndb.convert | knp $knpopts[*] > $SYNDB_DIR/syndb.parse"
	exe="perl word_into_juman.pl -C $JUMAN < $SYNDB_DIR/syndb.convert | knp $knpopts[*] > $SYNDB_DIR/syndb.parse"
    fi
fi
echo $exe
eval $exe

# コンパイル
if [ $log -eq 1 ]; then
    exe="perl -I$PERL_DIR compile.pl --knp_result=$SYNDB_DIR/syndb.parse --syndbdir=$SYNDB_DIR --option=log"
else
    exe="perl -I$PERL_DIR compile.pl --knp_result=$SYNDB_DIR/syndb.parse --syndbdir=$SYNDB_DIR"
fi
echo $exe
eval $exe

# synhead.mldbmのソート
exe="perl -I$PERL_DIR sort_synhead.pl --syndbdir=$SYNDB_DIR"
echo $exe
eval $exe

exe="mv $SYNDB_DIR/synhead_sort.cdb $SYNDB_DIR/synhead.cdb"
echo $exe
eval $exe

