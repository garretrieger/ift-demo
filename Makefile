
all: docs/rust-client/pkg/rust_client.js docs/cc-client/brotli.js fonts

fonts: docs/fonts/roboto/Roboto-IFT.woff2 docs/fonts/notoserifhigh/NotoSerifSC-HighFreq-IFT.woff2 docs/fonts/notosanshigh/NotoSansSC-HighFreq-IFT.woff2 docs/fonts/notoseriflow/NotoSerifSC-LowFreq-IFT.woff2 docs/fonts/notosanslow/NotoSansSC-LowFreq-IFT.woff2

always:

docs/rust-client/pkg/rust_client.js: always
	cd rust-client; wasm-pack build --release --target web
	cp rust-client/pkg/* docs/rust-client/pkg/

docs/cc-client/brotli.js: always
	bazel build cc-client:brotli-wasm
	mkdir -p docs/cc-client/
	cat bazel-bin/cc-client/brotli-wasm/brotli-wasm.js > docs/cc-client/brotli.js

docs/fonts/roboto/Roboto-IFT.woff2: docs/fonts/roboto/Roboto-IFT.ttf
	woff2_compress --in=docs/fonts/roboto/Roboto-IFT.ttf --out=docs/fonts/roboto/Roboto-IFT.woff2 --allow_transforms=false

docs/fonts/roboto/Roboto-IFT.ttf: build/Roboto-Preprocessed.ttf build/roboto_config.txtpb
	mkdir -p docs/fonts/roboto
	bazel run -c opt  @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/build/Roboto-Preprocessed.ttf \
		--config=$(CURDIR)/build/roboto_config.txtpb \
		--output_path=$(CURDIR)/docs/fonts/roboto/ \
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
	bazel run -c opt @ift_encoder//util:closure_glyph_keyed_segmenter_util \
	      --copt="-DABSL_MIN_LOG_LEVEL=absl::LogSeverity::kWarning" -- \
	      --input_font=$(CURDIR)/original_fonts/Roboto[wdth,wght].ttf \
	      --number_of_segments=412 --min_patch_size_bytes=4000 --max_patch_size_bytes=12000 \
	      --nooutput_segmentation_analysis \
	      --noinclude_initial_codepoints_in_config \
	      --initial_codepoints_file=$(CURDIR)/subsets/latin.txt \
	      --codepoints_file=$(CURDIR)/build/roboto_all_cps.txt \
	      --output_encoder_config > $(CURDIR)/build/roboto_glyph_keyed_config.txtpb

##### Noto Serif High Freq Build Rules #####

build/NotoSerifSC-HighFreq.otf: original_fonts/NotoSerifSC-VF.otf build/simplified-chinese_split1_unicodes.txt
	bazel run @harfbuzz//:hb-subset -- $(CURDIR)/original_fonts/NotoSerifSC-VF.otf \
		--unicodes-file=$(CURDIR)/build/simplified-chinese_split1_unicodes.txt \
		--no-hinting \
		--instance="wght=900" \
		-o $(CURDIR)/build/NotoSerifSC-HighFreq.otf

docs/fonts/notoserifhigh/NotoSerifSC-HighFreq-IFT.otf: build/NotoSerifSC-HighFreq.otf build/noto_serif_high_freq_config.txtpb
	mkdir -p docs/fonts/notoserifhigh
	bazel run -c opt  @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/build/NotoSerifSC-HighFreq.otf \
		--config=$(CURDIR)/build/noto_serif_high_freq_config.txtpb \
		--output_path=$(CURDIR)/docs/fonts/notoserifhigh/ \
		--output_font="NotoSerifSC-HighFreq-IFT.otf"

docs/fonts/notoserifhigh/NotoSerifSC-HighFreq-IFT.woff2: docs/fonts/notoserifhigh/NotoSerifSC-HighFreq-IFT.otf
	woff2_compress --in=docs/fonts/notoserifhigh/NotoSerifSC-HighFreq-IFT.otf --out=docs/fonts/notoserifhigh/NotoSerifSC-HighFreq-IFT.woff2 --allow_transforms=false

build/noto_serif_high_freq_config.txtpb: build/noto_serif_high_freq_glyph_keyed_config.txtpb build/noto_serif_high_freq_table_keyed_config.txtpb
	cat build/noto_serif_high_freq_glyph_keyed_config.txtpb build/noto_serif_high_freq_table_keyed_config.txtpb > build/noto_serif_high_freq_config.txtpb

build/noto_serif_high_freq_glyph_keyed_config.txtpb: build/NotoSerifSC-HighFreq.otf subsets/simplified-chinese-ordered.txt
	bazel run -c opt @ift_encoder//util:closure_glyph_keyed_segmenter_util \
	      --copt="-DABSL_MIN_LOG_LEVEL=absl::LogSeverity::kWarning" -- \
	      --input_font=$(CURDIR)/build/NotoSerifSC-HighFreq.otf \
	      --number_of_segments=17792 --min_patch_size_bytes=2000 --max_patch_size_bytes=12000 \
	      --nooutput_segmentation_analysis \
	      --noinclude_initial_codepoints_in_config \
	      --initial_codepoints_file=$(CURDIR)/subsets/empty.txt \
	      --codepoints_file=$(CURDIR)/subsets/simplified-chinese-ordered.txt \
	      --output_encoder_config > $(CURDIR)/build/noto_serif_high_freq_glyph_keyed_config.txtpb

build/noto_serif_high_freq_table_keyed_config.txtpb: subsets/empty.txt subsets/simplified-chinese_split1.txt original_fonts/noto_serif_additional_config.txtpb
	bazel run -c opt @ift_encoder//util:generate_table_keyed_config -- \
		$(CURDIR)/subsets/{empty,simplified-chinese_split1}.txt > $(CURDIR)/build/noto_serif_high_freq_table_keyed_config.txtpb
	cat $(CURDIR)/original_fonts/noto_serif_additional_config.txtpb >> $(CURDIR)/build/noto_serif_high_freq_table_keyed_config.txtpb

##### Noto Serif Low Freq Build Rules #####

build/NotoSerifSC-LowFreq.otf: original_fonts/NotoSerifSC-VF.otf build/simplified-chinese_split1_unicodes.txt
	bazel run @harfbuzz//:hb-subset -- $(CURDIR)/original_fonts/NotoSerifSC-VF.otf \
		--unicodes=* \
		--unicodes-=`paste -sd, build/simplified-chinese_split1_unicodes.txt` \
		--no-hinting \
		--instance="wght=900" \
		-o $(CURDIR)/build/NotoSerifSC-LowFreq.otf

docs/fonts/notoseriflow/NotoSerifSC-LowFreq-IFT.otf: build/NotoSerifSC-LowFreq.otf build/noto_serif_low_freq_config.txtpb
	mkdir -p docs/fonts/notoseriflow/
	bazel run -c opt  @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/build/NotoSerifSC-LowFreq.otf \
		--config=$(CURDIR)/build/noto_serif_low_freq_config.txtpb \
		--output_path=$(CURDIR)/docs/fonts/notoseriflow/ \
		--output_font="NotoSerifSC-LowFreq-IFT.otf"

docs/fonts/notoseriflow/NotoSerifSC-LowFreq-IFT.woff2: docs/fonts/notoseriflow/NotoSerifSC-LowFreq-IFT.otf
	woff2_compress --in=docs/fonts/notoseriflow/NotoSerifSC-LowFreq-IFT.otf --out=docs/fonts/notoseriflow/NotoSerifSC-LowFreq-IFT.woff2 --allow_transforms=false

build/noto_serif_low_freq_config.txtpb: build/noto_serif_low_freq_glyph_keyed_config.txtpb build/noto_serif_low_freq_table_keyed_config.txtpb
	cat build/noto_serif_low_freq_glyph_keyed_config.txtpb build/noto_serif_low_freq_table_keyed_config.txtpb > build/noto_serif_low_freq_config.txtpb

build/noto_serif_low_freq_glyph_keyed_config.txtpb: build/NotoSerifSC-LowFreq.otf
	bazel run -c opt @ift_encoder//util:closure_glyph_keyed_segmenter_util \
	      --copt="-DABSL_MIN_LOG_LEVEL=absl::LogSeverity::kWarning" -- \
	      --input_font=$(CURDIR)/build/NotoSerifSC-LowFreq.otf \
	      --number_of_segments=3500 --min_patch_size_bytes=5000 --max_patch_size_bytes=12000 \
	      --nooutput_segmentation_analysis \
	      --noinclude_initial_codepoints_in_config \
	      --initial_codepoints_file=$(CURDIR)/subsets/empty.txt \
	      --output_encoder_config > $(CURDIR)/build/noto_serif_low_freq_glyph_keyed_config.txtpb

build/noto_serif_low_freq_table_keyed_config.txtpb: subsets/empty.txt original_fonts/noto_serif_additional_config.txtpb build/NotoSerifSC-LowFreq.otf
	bazel run -c opt @ift_encoder//util:generate_table_keyed_config -- \
		--font=$(CURDIR)/build/NotoSerifSC-LowFreq.otf \
		$(CURDIR)/subsets/empty.txt > $(CURDIR)/build/noto_serif_low_freq_table_keyed_config.txtpb
	cat $(CURDIR)/original_fonts/noto_serif_additional_config.txtpb >> $(CURDIR)/build/noto_serif_low_freq_table_keyed_config.txtpb

##### Noto Sans High Freq Build Rules #####

build/NotoSansSC-HighFreq.ttf: original_fonts/NotoSansSC-VF.ttf build/simplified-chinese_split1_unicodes.txt
	bazel run @harfbuzz//:hb-subset -- $(CURDIR)/original_fonts/NotoSansSC-VF.ttf \
		--unicodes-file=$(CURDIR)/build/simplified-chinese_split1_unicodes.txt \
		--no-hinting \
		-o $(CURDIR)/build/NotoSansSC-HighFreq.ttf

docs/fonts/notosanshigh/NotoSansSC-HighFreq-IFT.ttf: build/NotoSansSC-HighFreq.ttf build/noto_sans_high_freq_config.txtpb
	mkdir -p docs/fonts/notosanshigh/
	bazel run -c opt  @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/build/NotoSansSC-HighFreq.ttf \
		--config=$(CURDIR)/build/noto_sans_high_freq_config.txtpb \
		--output_path=$(CURDIR)/docs/fonts/notosanshigh/ \
		--output_font="NotoSansSC-HighFreq-IFT.ttf"

docs/fonts/notosanshigh/NotoSansSC-HighFreq-IFT.woff2: docs/fonts/notosanshigh/NotoSansSC-HighFreq-IFT.ttf
	woff2_compress --in=docs/fonts/notosanshigh/NotoSansSC-HighFreq-IFT.ttf --out=docs/fonts/notosanshigh/NotoSansSC-HighFreq-IFT.woff2 --allow_transforms=false

build/noto_sans_high_freq_config.txtpb: build/noto_sans_high_freq_glyph_keyed_config.txtpb build/noto_sans_high_freq_table_keyed_config.txtpb
	cat build/noto_sans_high_freq_glyph_keyed_config.txtpb build/noto_sans_high_freq_table_keyed_config.txtpb > build/noto_sans_high_freq_config.txtpb

build/noto_sans_high_freq_glyph_keyed_config.txtpb: build/NotoSansSC-HighFreq.ttf subsets/simplified-chinese-ordered.txt
	bazel run -c opt @ift_encoder//util:closure_glyph_keyed_segmenter_util \
	      --copt="-DABSL_MIN_LOG_LEVEL=absl::LogSeverity::kWarning" -- \
	      --input_font=$(CURDIR)/build/NotoSansSC-HighFreq.ttf \
	      --number_of_segments=17792 --min_patch_size_bytes=2000 --max_patch_size_bytes=12000 \
	      --nooutput_segmentation_analysis \
	      --noinclude_initial_codepoints_in_config \
	      --initial_codepoints_file=$(CURDIR)/subsets/empty.txt \
	      --codepoints_file=$(CURDIR)/subsets/simplified-chinese-ordered.txt \
	      --output_encoder_config > $(CURDIR)/build/noto_sans_high_freq_glyph_keyed_config.txtpb

build/noto_sans_high_freq_table_keyed_config.txtpb: subsets/empty.txt subsets/simplified-chinese_split1.txt original_fonts/noto_sans_additional_config.txtpb
	bazel run -c opt @ift_encoder//util:generate_table_keyed_config -- \
		$(CURDIR)/subsets/{empty,simplified-chinese_split1}.txt > $(CURDIR)/build/noto_sans_high_freq_table_keyed_config.txtpb
	cat $(CURDIR)/original_fonts/noto_sans_additional_config.txtpb >> $(CURDIR)/build/noto_sans_high_freq_table_keyed_config.txtpb

##### Noto Sans Low Freq Build Rules #####

build/NotoSansSC-LowFreq.ttf: original_fonts/NotoSansSC-VF.ttf build/simplified-chinese_split1_unicodes.txt
	bazel run @harfbuzz//:hb-subset -- $(CURDIR)/original_fonts/NotoSansSC-VF.ttf \
		--unicodes=* \
		--unicodes-=`paste -sd, build/simplified-chinese_split1_unicodes.txt` \
		--no-hinting \
		-o $(CURDIR)/build/NotoSansSC-LowFreq.ttf

docs/fonts/notosanslow/NotoSansSC-LowFreq-IFT.ttf: build/NotoSansSC-LowFreq.ttf build/noto_sans_low_freq_config.txtpb
	mkdir -p docs/fonts/notosanslow/
	bazel run -c opt  @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/build/NotoSansSC-LowFreq.ttf \
		--config=$(CURDIR)/build/noto_sans_low_freq_config.txtpb \
		--output_path=$(CURDIR)/docs/fonts/notosanslow/ \
		--output_font="NotoSansSC-LowFreq-IFT.ttf"

docs/fonts/notosanslow/NotoSansSC-LowFreq-IFT.woff2: docs/fonts/notosanslow/NotoSansSC-LowFreq-IFT.ttf
	woff2_compress --in=docs/fonts/notosanslow/NotoSansSC-LowFreq-IFT.ttf --out=docs/fonts/notosanslow/NotoSansSC-LowFreq-IFT.woff2 --allow_transforms=false

build/noto_sans_low_freq_config.txtpb: build/noto_sans_low_freq_glyph_keyed_config.txtpb build/noto_sans_low_freq_table_keyed_config.txtpb
	cat build/noto_sans_low_freq_glyph_keyed_config.txtpb build/noto_sans_low_freq_table_keyed_config.txtpb > build/noto_sans_low_freq_config.txtpb

build/noto_sans_low_freq_glyph_keyed_config.txtpb: build/NotoSansSC-LowFreq.ttf subsets/simplified-chinese-ordered.txt
	bazel run -c opt @ift_encoder//util:closure_glyph_keyed_segmenter_util \
	      --copt="-DABSL_MIN_LOG_LEVEL=absl::LogSeverity::kWarning" -- \
	      --input_font=$(CURDIR)/build/NotoSansSC-LowFreq.ttf \
	      --number_of_segments=3500 --min_patch_size_bytes=5000 --max_patch_size_bytes=12000 \
	      --nooutput_segmentation_analysis \
	      --noinclude_initial_codepoints_in_config \
	      --output_encoder_config > $(CURDIR)/build/noto_sans_low_freq_glyph_keyed_config.txtpb

build/noto_sans_low_freq_table_keyed_config.txtpb: subsets/empty.txt subsets/simplified-chinese_split1.txt original_fonts/noto_sans_additional_config.txtpb build/NotoSansSC-LowFreq.ttf
	bazel run -c opt @ift_encoder//util:generate_table_keyed_config -- \
		--font=$(CURDIR)/build/NotoSansSC-LowFreq.ttf \
		$(CURDIR)/subsets/empty.txt > $(CURDIR)/build/noto_sans_low_freq_table_keyed_config.txtpb
	cat $(CURDIR)/original_fonts/noto_sans_additional_config.txtpb >> $(CURDIR)/build/noto_sans_low_freq_table_keyed_config.txtpb


build/simplified-chinese_split1_unicodes.txt: subsets/simplified-chinese_split1.txt
	cat $(CURDIR)/subsets/simplified-chinese_split1.txt | awk '{print substr($$1, 3)}' > build/simplified-chinese_split1_unicodes.txt

clean: clean_rust
	rm -f build/*
	rm -rf docs/fonts/* docs/rust-client/pkg/*

clean_rust:
	cd rust-client/; cargo clean
	rm -rf rust-client/pkg/*
	rm rust-client/Cargo.lock

