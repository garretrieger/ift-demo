#!/bin/bash

# Creates subsetted versions of the original fonts that will serve as the base for producing IFT fonts.
# Notably this splits the CJK families each into two distinct subsets.
#
# ./step1-build-base-fonts.sh <path to harfbuzz build directory>

HB_CODE_DIR=$1
THIS_DIR=$(dirname $(realpath $0))
echo "Running in: $THIS_DIR"

SUBSET_1=$(mktemp)
cat $THIS_DIR/subsets/simplified-chinese_split1.txt | awk '{print substr($1, 3)}' > $SUBSET_1

SUBSET_2=$(mktemp)
cat $THIS_DIR/subsets/simplified-chinese_split2.txt | awk '{print substr($1, 3)}' > $SUBSET_2

$HB_CODE_DIR/util/hb-subset --unicodes-file=$SUBSET_1 NotoSerifSC[wght].ttf -o NotoSerifSC[wght]_1.ttf
$HB_CODE_DIR/util/hb-subset --unicodes-file=$SUBSET_2 NotoSerifSC[wght].ttf -o NotoSerifSC[wght]_2.ttf
$HB_CODE_DIR/util/hb-subset --unicodes-file=$SUBSET_1 NotoSansSC[wght].ttf -o NotoSansSC[wght]_1.ttf
$HB_CODE_DIR/util/hb-subset --unicodes-file=$SUBSET_2 NotoSansSC[wght].ttf -o NotoSansSC[wght]_2.ttf

rm $SUBSET_1
rm $SUBSET_2
