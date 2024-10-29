#!/bin/bash

# Using the files generated in step 1 and 2 generates the final IFT fonts and associated patches.
#
# ./step3-build-demo-fonts.sh <path to patch-subset-incxfer source directory>

IFT_CODE_DIR=$1
THIS_DIR=$(dirname $(realpath $0))
echo "Running in: $THIS_DIR"

cd $IFT_CODE_DIR

VF_FONTS="Playfair[opsz,wdth,wght].ttf"
SHARED_BROTLI_FONTS="Roboto-Regular.ttf Roboto-Thin.ttf"
IFTB_FONTS="NotoSansSC[wght]_1.ttf NotoSansSC[wght]_2.ttf NotoSerifSC[wght]_1.ttf NotoSerifSC[wght]_2.ttf"
BASE_SUBSET="latin.txt"

rm -rf $THIS_DIR/fonts/

for f in $SHARED_BROTLI_FONTS; do
  name=${f%.ttf}
  mkdir -p $THIS_DIR/fonts/$name
  echo ">> Converting $f to shared brotli IFT font."
  ls $THIS_DIR/subsets/{latin,cyrillic,vietnamese,greek}.txt | grep -v $BASE_SUBSET | xargs bazel run -c opt util:font2ift -- \
    --url_template="fonts/$name/\$2\$1.br" \
    --output_path=$THIS_DIR \
    --output_font=fonts/$name.ift.woff2 \
    --jump_ahead=2 \
    --optional_feature_tags="c2sc,smcp" \
    $THIS_DIR/$f $THIS_DIR/subsets/$BASE_SUBSET
done

for f in $VF_FONTS; do
  name=${f%.ttf}
  mkdir -p $THIS_DIR/fonts/$name
  echo ">> Converting $f to shared brotli IFT font with optional wdth axis."
  ls $THIS_DIR/subsets/{latin,cyrillic,vietnamese}.txt | grep -v $BASE_SUBSET | xargs bazel run -c opt util:font2ift -- \
    --url_template="fonts/$name/\$2\$1.br" \
    --output_path=$THIS_DIR \
    --output_font=fonts/$name.ift.woff2 \
    --jump_ahead=1 \
    --base_design_space="wdth=112.5,opsz=48" \
    --optional_design_space="wdth=87.5:112.5,opsz=48" \
    $THIS_DIR/$f $THIS_DIR/subsets/$BASE_SUBSET

done

for f in $IFTB_FONTS; do
  name=${f%.ttf}
  mkdir -p $THIS_DIR/fonts/$name

  weight=100
  if [[ "$f" == *"NotoSerif"* ]]; then
    weight=200
  fi

  in_template="$THIS_DIR/${name}_iftb/\$3/chunk\$3\$2\$1.br"
  if [[ "$f" == *"NotoSerif"*"_2"* ]]; then
    in_template="$THIS_DIR/${name}_iftb/\$4/\$3/chunk\$4\$3\$2\$1.br"
  fi
  
  echo ">> Converting IFTB $f to IFT font."
  count=$(find $THIS_DIR/${name}_iftb/ -iname "chunk*.br" | wc -l)
  count=$((count+1))
  echo " $count iftb patches found."
  bazel run -c opt util:font2ift -- \
    --input_iftb_patch_template="$in_template" \
    --url_template="fonts/$name/\$4\$3\$2\$1.br" \
    --base_design_space="wght=$weight" \
    --output_path=$THIS_DIR \
    --output_font=fonts/$name.ift.woff2 \
    --jump_ahead=2 \
    --input_iftb_patch_count=$count \
    --iftb_patch_groups=5 \
    --optional_design_space="wght=$weight:900" \
    --optional_design_space_url_template="fonts/$name/wght-\$4\$3\$2\$1.br" \
    $THIS_DIR/$f
done

