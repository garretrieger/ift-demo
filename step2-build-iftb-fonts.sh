#!/bin/bash

# Generates binned IFT versions of the CJK fonts. The binning strategy produced by binned IFT is used as an
# input to generate the IFT fonts.
#
# ./step2-build-iftb-fonts.sh <path to iftb build directory>

IFTB_CODE_DIR=$1
THIS_DIR=$(dirname $(realpath $0))
echo "Running in: $THIS_DIR"

cd $IFTB_CODE_DIR

IFTB_FONTS="NotoSansSC[wght]_1.ttf NotoSansSC[wght]_2.ttf NotoSerifSC[wght]_1.ttf NotoSerifSC[wght]_2.ttf"

rm -rf $THIS_DIR/NotoSansSC[wght]_1_iftb/
rm -rf $THIS_DIR/NotoSansSC[wght]_2_iftb/
rm -rf $THIS_DIR/NotoSerifSC[wght]_1_iftb/
rm -rf $THIS_DIR/NotoSerifSC[wght]_2_iftb/
rm -f $THIS_DIR/NotoSansSC[wght]_1_iftb.*
rm -f $THIS_DIR/NotoSansSC[wght]_2_iftb.*
rm -f $THIS_DIR/NotoSerifSC[wght]_1_iftb.*
rm -f $THIS_DIR/NotoSerifSC[wght]_2_iftb.*

for f in $IFTB_FONTS; do
  ./iftb -VV -c $THIS_DIR/config_sc.yaml process $THIS_DIR/$f
done
