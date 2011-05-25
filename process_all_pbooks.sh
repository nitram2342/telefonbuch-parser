#!/bin/sh


MODE=$1
if [ -z $MODE ] ; then
    echo 'sh process_all_pbook.sh <mode>';
fi

rm .current_line*

#    1998_Herbst    \
#    1999_Fruehjahr \
#    1999_Herbst    \
#    2000_Fruehjahr \
#    2000_Herbst    \
#    2001_Fruehjahr \
#    2001_Herbst    \

for i in \
    2002_Fruehjahr \
    2002_Herbst    \
    2003_Fruehjahr \
    2003_Herbst    \
    2004_Fruehjahr \
    2004_Herbst    \
    2005_Fruehjahr \
    2005_Herbst    \
    2006_Fruehjahr \
    2006_Herbst    \
    2007_Fruehjahr \
; do perl tb_parser.pl $i $MODE; done