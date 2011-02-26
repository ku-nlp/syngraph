#!/usr/bin/env zsh

# 不必要なスクリプト、データを削除

# usage: cd scripts; ./arrange_SynGraph_project.sh

uname=i686
delete_uname=x86_64
while getopts i OPT
do  
    case $OPT in
        i)  uname=x86_64
	    delete_uname=i686
            ;;
        h)  usage
            ;;
    esac
done
shift `expr $OPTIND - 1`

rm -fr ../syndb/$delete_uname
if [ -e ../syndb/$uname/syndb.jmn ]; then
    rm -f ../syndb/$uname/syndb.jmn
fi
if [ -e ../syndb/$uname/syndb.parse ]; then
    rm -f ../syndb/$uname/syndb.parse
fi

rm -fr ../syndb/cgi
rm -fr ../ExtractSynfromDic
rm -fr ../MakeDic
rm -fr ../dic
rm -fr ../dic_middle
rm -fr ../dic_change
