#!/usr/bin/env zsh

# ��ɬ�פʥ�����ץȡ��ǡ�������

# usage: cd scripts; ./arrange_SynGraph_project.sh

uname=x86_64
while getopts i OPT
do  
    case $OPT in
        i)  uname=i686
            ;;
        h)  usage
            ;;
    esac
done
shift `expr $OPTIND - 1`

rm -fr ../syndb/$uname
rm -fr ../syndb/cgi
rm -fr ../ExtractSynfromDic
rm -fr ../MakeDic
