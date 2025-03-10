
all: fonts/roboto/Roboto-IFT.woff2

fonts/roboto/Roboto-IFT.woff2: fonts/roboto/Roboto-IFT.ttf
	woff2_compress --in=fonts/roboto/Roboto-IFT.ttf --out=fonts/roboto/Roboto-IFT.woff2 --allow_transforms=false

fonts/roboto/Roboto-IFT.ttf: original_fonts//Roboto[wdth,wght].ttf build/roboto_config.txtpb
	mkdir -p fonts/roboto
	bazel run -c opt  @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/original_fonts//Roboto[wdth,wght].ttf \
		--config=$(CURDIR)/build/roboto_config.txtpb \
		--output_path=$(CURDIR)/fonts/roboto/ \
		--output_font="Roboto-IFT.ttf"

build/roboto_all_cps.txt: subsets/latin.txt subsets/cyrillic.txt subsets/vietnamese.txt subsets/greek.txt
	cat subsets/{latin,cyrillic,vietnamese,greek}.txt > build/roboto_all_cps.txt

build/roboto_config.txtpb: build/roboto_table_keyed_config.txtpb build/roboto_glyph_keyed_config.txtpb
	cat build/roboto_glyph_keyed_config.txtpb build/roboto_table_keyed_config.txtpb > build/roboto_config.txtpb

build/roboto_table_keyed_config.txtpb: subsets/latin.txt subsets/cyrillic.txt subsets/vietnamese.txt subsets/greek.txt
	bazel run -c opt @ift_encoder//util:generate_table_keyed_config -- \
		$(CURDIR)/subsets/{latin,cyrillic,vietnamese,greek}.txt > $(CURDIR)/build/roboto_table_keyed_config.txtpb

build/roboto_glyph_keyed_config.txtpb: original_fonts/Roboto[wdth,wght].ttf build/roboto_all_cps.txt
	bazel run -c opt @ift_encoder//util:closure_glyph_keyed_segmenter_util -- \
	      --input_font=$(CURDIR)/original_fonts/Roboto[wdth,wght].ttf \
	      --number_of_segments=412 --min_patch_size_bytes=4000 --max_patch_size_bytes=12000 \
	      --nooutput_segmentation_analysis \
	      --codepoints_file=$(CURDIR)/build/roboto_all_cps.txt --output_encoder_config > $(CURDIR)/build/roboto_glyph_keyed_config.txtpb

clean:
	rm build/*
	rm -rf fonts/*

