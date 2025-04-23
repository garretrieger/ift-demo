
all: html/rust-client/pkg/rust_client.js html/cc-client/brotli.js fonts

fonts: html/fonts/roboto/Roboto-IFT.woff2 html/fonts/notoserif/NotoSerifcSC-HighFreq-IFT.woff2

always:

html/rust-client/pkg/rust_client.js: always
	cd rust-client; wasm-pack build --release --target web
	cp rust-client/pkg/* html/rust-client/pkg/

html/cc-client/brotli.js: always
	bazel build cc-client:brotli-wasm
	mkdir -p html/cc-client/
	cat bazel-bin/cc-client/brotli-wasm/brotli-wasm.js > html/cc-client/brotli.js

html/fonts/roboto/Roboto-IFT.woff2: html/fonts/roboto/Roboto-IFT.ttf
	woff2_compress --in=html/fonts/roboto/Roboto-IFT.ttf --out=html/fonts/roboto/Roboto-IFT.woff2 --allow_transforms=false

html/fonts/roboto/Roboto-IFT.ttf: build/Roboto-Preprocessed.ttf build/roboto_config.txtpb
	mkdir -p html/fonts/roboto
	bazel run -c opt  @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/build/Roboto-Preprocessed.ttf \
		--config=$(CURDIR)/build/roboto_config.txtpb \
		--output_path=$(CURDIR)/html/fonts/roboto/ \
		--output_font="Roboto-IFT.ttf"

build/Roboto-Preprocessed.ttf: original_fonts/Roboto[wdth,wght].ttf
	bazel run @harfbuzz//:hb-subset -- $(CURDIR)/original_fonts/Roboto[wdth,wght].ttf \
		--keep-everything \
		--no-hinting \
		-o $(CURDIR)/build/Roboto-Preprocessed.ttf

build/roboto_all_cps.txt: subsets/latin.txt subsets/cyrillic.txt subsets/vietnamese.txt subsets/greek.txt
	cat subsets/{latin,cyrillic,vietnamese,greek}.txt > build/roboto_all_cps.txt

build/roboto_config.txtpb: build/roboto_table_keyed_config.txtpb build/roboto_glyph_keyed_config.txtpb
	cat build/roboto_glyph_keyed_config.txtpb build/roboto_table_keyed_config.txtpb > build/roboto_config.txtpb

build/roboto_table_keyed_config.txtpb: subsets/latin.txt subsets/cyrillic.txt subsets/vietnamese.txt subsets/greek.txt original_fonts/roboto_additional_config.txtpb
	bazel run -c opt @ift_encoder//util:generate_table_keyed_config -- \
		$(CURDIR)/subsets/{latin,cyrillic,vietnamese,greek}.txt > $(CURDIR)/build/roboto_table_keyed_config.txtpb
	cat $(CURDIR)/original_fonts/roboto_additional_config.txtpb >> $(CURDIR)/build/roboto_table_keyed_config.txtpb

build/roboto_glyph_keyed_config.txtpb: original_fonts/Roboto[wdth,wght].ttf build/roboto_all_cps.txt
	bazel run -c opt @ift_encoder//util:closure_glyph_keyed_segmenter_util -- \
	      --input_font=$(CURDIR)/original_fonts/Roboto[wdth,wght].ttf \
	      --number_of_segments=412 --min_patch_size_bytes=4000 --max_patch_size_bytes=12000 \
	      --nooutput_segmentation_analysis \
	      --noinclude_initial_codepoints_in_config \
	      --initial_codepoints_file=$(CURDIR)/subsets/latin.txt \
	      --codepoints_file=$(CURDIR)/build/roboto_all_cps.txt \
	      --output_encoder_config > $(CURDIR)/build/roboto_glyph_keyed_config.txtpb

build/NotoSerifSC-HighFreq.otf: original_fonts/NotoSerifSC-VF.otf build/simplified-chinese_split1_unicodes.txt
	bazel run @harfbuzz//:hb-subset -- $(CURDIR)/original_fonts/NotoSerifSC-VF.otf \
		--unicodes-file=$(CURDIR)/build/simplified-chinese_split1_unicodes.txt \
		--no-hinting \
		-o $(CURDIR)/build/NotoSerifSC-HighFreq.otf

html/fonts/notoserif/NotoSerifcSC-HighFreq-IFT.otf: build/NotoSerifSC-HighFreq.otf build/noto_serif_high_freq_config.txtpb
	mkdir -p html/fonts/notoserif
	bazel run -c opt  @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/build/NotoSerifSC-HighFreq.otf \
		--config=$(CURDIR)/build/noto_serif_high_freq_config.txtpb \
		--output_path=$(CURDIR)/html/fonts/notoserif/ \
		--output_font="NotoSerifcSC-HighFreq-IFT.otf"

html/fonts/notoserif/NotoSerifcSC-HighFreq-IFT.woff2: html/fonts/notoserif/NotoSerifcSC-HighFreq-IFT.otf
	woff2_compress --in=html/fonts/notoserif/NotoSerifcSC-HighFreq-IFT.otf --out=html/fonts/notoserif/NotoSerifcSC-HighFreq-IFT.woff2 --allow_transforms=false

build/simplified-chinese_split1_unicodes.txt: subsets/simplified-chinese_split1.txt
	cat $(CURDIR)/subsets/simplified-chinese_split1.txt | awk '{print substr($$1, 3)}' > build/simplified-chinese_split1_unicodes.txt

build/noto_serif_high_freq_config.txtpb: build/noto_serif_high_freq_glyph_keyed_config.txtpb build/noto_serif_high_freq_table_keyed_config.txtpb
	cat build/noto_serif_high_freq_glyph_keyed_config.txtpb build/noto_serif_high_freq_table_keyed_config.txtpb > build/noto_serif_high_freq_config.txtpb

build/noto_serif_high_freq_glyph_keyed_config.txtpb: build/NotoSerifSC-HighFreq.otf subsets/simplified-chinese-ordered.txt
	bazel run -c opt @ift_encoder//util:closure_glyph_keyed_segmenter_util -- \
	      --input_font=$(CURDIR)/build/NotoSerifSC-HighFreq.otf \
	      --number_of_segments=17792 --min_patch_size_bytes=3000 --max_patch_size_bytes=12000 \
	      --nooutput_segmentation_analysis \
	      --noinclude_initial_codepoints_in_config \
	      --initial_codepoints_file=$(CURDIR)/subsets/empty.txt \
	      --codepoints_file=$(CURDIR)/subsets/simplified-chinese-ordered.txt \
	      --output_encoder_config > $(CURDIR)/build/noto_serif_high_freq_glyph_keyed_config.txtpb

build/noto_serif_high_freq_table_keyed_config.txtpb: subsets/empty.txt subsets/simplified-chinese_split1.txt original_fonts/noto_serif_additional_config.txtpb
	bazel run -c opt @ift_encoder//util:generate_table_keyed_config -- \
		$(CURDIR)/subsets/{empty,simplified-chinese_split1}.txt > $(CURDIR)/build/noto_serif_high_freq_table_keyed_config.txtpb
	cat $(CURDIR)/original_fonts/noto_serif_additional_config.txtpb >> $(CURDIR)/build/noto_serif_high_freq_table_keyed_config.txtpb

clean: clean_rust
	rm -f build/*
	rm -rf html/fonts/* html/rust-client/pkg/*

clean_rust:
	cd rust-client/; cargo clean
	rm -rf rust-client/pkg/*
	rm rust-client/Cargo.lock

