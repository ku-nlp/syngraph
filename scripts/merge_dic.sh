#!/bin/zsh

# ソースディレクトリ
SRC_DIR='.'

# 同義表現データディレクトリ
SIM_DIR_Dic=../dic/rsk_iwanami
SIM_DIR_Web=../dic/web_news

# 同義表現データマージ途中のディレクトリ
SIM_M_DIR=../dic_middle

# 同義表現データマージ後のディレクトリ
SIM_C_DIR=../dic_change

# 同義表現データベース
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

# パス設定
export PATH=$SRC_DIR:$PATH
export PERL5LIB=$SRC_DIR:$PERL5LIB


# 全部削除する
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
# 辞書からの知識抽出のログ作成（CGI用）
perl -I$PERL_DIR make_logdic.pl --synonym=$SIM_DIR_Dic/synonym.txt --definition=$SIM_DIR_Dic/definition.txt --isa=$SIM_DIR_Dic/isa.txt --antonym=$SIM_DIR_Dic/antonym.txt --syndbdir=$SYNDB_DIR

# 辞書からの同義関係(synonym, same_difinition)の知識の連結
perl cat_synonym_same_def.pl -synonym_dic=$SIM_DIR_Dic/synonym.txt -same_diff=$SIM_DIR_Dic/same_definition.txt -cat_file=$SIM_M_DIR/synonym_dic.txt

# 辞書からの知識の整理
perl check_synonym_dic.pl --synonym_dic=$SIM_M_DIR/synonym_dic.txt --log_merge=$SIM_C_DIR/log_merge_synonym_dic.txt --change=$SIM_M_DIR/synonym_dic2.txt
perl check_synonym_dic.pl --synonym_dic=$SIM_DIR_Dic/antonym.txt --log_merge=$SIM_C_DIR/log_merge_antonym_dic.txt --change=$SIM_M_DIR/antonym.txt

# Webからの知識の整理
#perl check_duplicate_entry.pl -rnsame --synonym_web_news=$SIM_DIR_Web/all.txt --log_merge=$SIM_C_DIR/log_merge_synonym_web_news.txt --change=$SIM_M_DIR/synonym_web_news.txt

# Webからの知識から辞書からの知識と重複を削除する
perl check_dic_web_news_duplicate.pl --dic=$SIM_M_DIR/synonym_dic2.txt --web=$SIM_M_DIR/synonym_web_news.txt --log_merge=$SIM_C_DIR/log_delete_web_news.txt --change=$SIM_C_DIR/synonym_web_news.txt

# 辞書を変換（多義性の扱い）
perl -I$PERL_DIR change_dic.pl --synonym=$SIM_M_DIR/synonym_dic2.txt --definition=$SIM_DIR_Dic/definition.txt --isa=$SIM_DIR_Dic/isa.txt --antonym=$SIM_M_DIR/antonym.txt --synonym_change=$SIM_C_DIR/synonym_dic.txt --isa_change=$SIM_C_DIR/isa.txt --antonym_change=$SIM_C_DIR/antonym.txt

cp $SIM_DIR_Dic/definition.txt $SIM_C_DIR/definition.txt
