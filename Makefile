SHELL=/bin/bash
SHELLOPTS=braceexpand:emacs:hashall:histexpand:history:interactive-comments:monitor
BAZEL_OPTS = -c opt --copt=-DABSL_MIN_LOG_LEVEL=absl::LogSeverity::kInfo

all: docs/rust-client/pkg/rust_client.js docs/cc-client/brotli.js fonts

fonts: docs/fonts/roboto/Roboto-IFT.woff2 docs/fonts/notoserifhigh/NotoSerifSC-HighFreq-IFT.woff2 docs/fonts/notosanshigh/NotoSansSC-HighFreq-IFT.woff2 docs/fonts/notoseriflow/NotoSerifSC-LowFreq-IFT.woff2 docs/fonts/notosanslow/NotoSansSC-LowFreq-IFT.woff2 docs/fonts/notoserifjphigh/NotoSerifJP-HighFreq-IFT.woff2 docs/fonts/notosansjphigh/NotoSansJP-HighFreq-IFT.woff2

always:

docs/rust-client/pkg/rust_client.js: always
	cd rust-client; wasm-pack build --release --target web
	cp rust-client/pkg/* docs/rust-client/pkg/

docs/cc-client/brotli.js: always
	bazel build -c opt cc-client:brotli-wasm
	mkdir -p docs/cc-client/
	cat bazel-bin/cc-client/brotli-wasm/brotli-wasm.js > docs/cc-client/brotli.js

##### Roboto

docs/fonts/roboto/Roboto-IFT.woff2: build/Roboto-Preprocessed.ttf build/roboto_segmentation_plan.txtpb
	mkdir -p docs/fonts/roboto
	bazel run $(BAZEL_OPTS) @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/build/Roboto-Preprocessed.ttf \
		--plan=$(CURDIR)/build/roboto_segmentation_plan.txtpb \
		--output_path=$(CURDIR)/docs/fonts/roboto/ \
		--output_font="Roboto-IFT.woff2"

build/Roboto-Preprocessed.ttf: original_fonts/Roboto[wdth,wght].ttf
	bazel run $(BAZEL_OPTS) @harfbuzz//:hb-subset -- $(CURDIR)/original_fonts/Roboto[wdth,wght].ttf \
		--no-hinting \
		--layout-features+=c2sc,smcp \
		--unicodes=* \
		-o $(CURDIR)/build/Roboto-Preprocessed.ttf

build/roboto_segmentation_plan.txtpb: build/Roboto-Preprocessed.ttf config/roboto_table_keyed_segmentation_plan.txtpb
	bazel run $(BAZEL_OPTS) @ift_encoder//util:gen_ift_segmentation_plan -- \
	      --input_font=$(CURDIR)/build/Roboto-Preprocessed.ttf \
	      --auto_config_quality=7 \
	      --nooutput_segmentation_analysis \
	      --output_segmentation_plan > $(CURDIR)/build/roboto_segmentation_plan.txtpb
	cat  $(CURDIR)/config/roboto_table_keyed_segmentation_plan.txtpb >> $(CURDIR)/build/roboto_segmentation_plan.txtpb

##### Noto Serif High Freq Build Rules #####

build/NotoSerifSC-HighFreq.otf: original_fonts/NotoSerifSC-VF.otf build/simplified-chinese_split1_unicodes.txt
	bazel run $(BAZEL_OPTS) @harfbuzz//:hb-subset -- $(CURDIR)/original_fonts/NotoSerifSC-VF.otf \
		--unicodes-file=$(CURDIR)/build/simplified-chinese_split1_unicodes.txt \
		--desubroutinize \
		--no-hinting \
		--instance="wght=900" \
		-o $(CURDIR)/build/NotoSerifSC-HighFreq.otf

docs/fonts/notoserifhigh/NotoSerifSC-HighFreq-IFT.woff2: build/NotoSerifSC-HighFreq.otf
	mkdir -p docs/fonts/notoserifhigh
	bazel run $(BAZEL_OPTS) @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/build/NotoSerifSC-HighFreq.otf \
	        --auto_config_quality=3 \
	        --auto_config_primary_script=Script_chinese-simplified \
		--output_path=$(CURDIR)/docs/fonts/notoserifhigh/ \
		--output_font="NotoSerifSC-HighFreq-IFT.woff2"

##### Noto Serif Low Freq Build Rules #####

build/NotoSerifSC-LowFreq.otf: original_fonts/NotoSerifSC-VF.otf build/simplified-chinese_split1_unicodes.txt
	bazel run $(BAZEL_OPTS) @harfbuzz//:hb-subset -- $(CURDIR)/original_fonts/NotoSerifSC-VF.otf \
		--unicodes=* \
		--unicodes-=`paste -sd, build/simplified-chinese_split1_unicodes.txt` \
		--desubroutinize \
		--no-hinting \
		--instance="wght=900" \
		-o $(CURDIR)/build/NotoSerifSC-LowFreq.otf

docs/fonts/notoseriflow/NotoSerifSC-LowFreq-IFT.woff2: build/NotoSerifSC-LowFreq.otf
	mkdir -p docs/fonts/notoseriflow/
	bazel run $(BAZEL_OPTS)  @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/build/NotoSerifSC-LowFreq.otf \
	        --auto_config_quality=2 \
	        --auto_config_primary_script=Script_chinese-simplified \
		--output_path=$(CURDIR)/docs/fonts/notoseriflow/ \
		--output_font="NotoSerifSC-LowFreq-IFT.woff2"

##### Noto Sans High Freq Build Rules #####

build/NotoSansSC-HighFreq.ttf: original_fonts/NotoSansSC-VF.ttf build/simplified-chinese_split1_unicodes.txt
	bazel run $(BAZEL_OPTS) @harfbuzz//:hb-subset -- $(CURDIR)/original_fonts/NotoSansSC-VF.ttf \
		--unicodes-file=$(CURDIR)/build/simplified-chinese_split1_unicodes.txt \
		--no-hinting \
		-o $(CURDIR)/build/NotoSansSC-HighFreq.ttf

# TODO Make wght axis extensible in the generated segmentation plan.
docs/fonts/notosanshigh/NotoSansSC-HighFreq-IFT.woff2: build/NotoSansSC-HighFreq.ttf
	mkdir -p docs/fonts/notosanshigh/
	bazel run $(BAZEL_OPTS) @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/build/NotoSansSC-HighFreq.ttf \
	        --auto_config_quality=3 \
	        --auto_config_primary_script=Script_chinese-simplified \
		--output_path=$(CURDIR)/docs/fonts/notosanshigh/ \
		--output_font="NotoSansSC-HighFreq-IFT.woff2"

##### Noto Sans Low Freq Build Rules #####

build/NotoSansSC-LowFreq.ttf: original_fonts/NotoSansSC-VF.ttf build/simplified-chinese_split1_unicodes.txt
	bazel run $(BAZEL_OPTS) @harfbuzz//:hb-subset -- $(CURDIR)/original_fonts/NotoSansSC-VF.ttf \
		--unicodes=* \
		--unicodes-=`paste -sd, build/simplified-chinese_split1_unicodes.txt` \
		--no-hinting \
		-o $(CURDIR)/build/NotoSansSC-LowFreq.ttf

docs/fonts/notosanslow/NotoSansSC-LowFreq-IFT.woff2: build/NotoSansSC-LowFreq.ttf
	mkdir -p docs/fonts/notosanslow/
	bazel run $(BAZEL_OPTS)  @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/build/NotoSansSC-LowFreq.ttf \
	        --auto_config_quality=2 \
	        --auto_config_primary_script=Script_chinese-simplified \
		--output_path=$(CURDIR)/docs/fonts/notosanslow/ \
		--output_font="NotoSansSC-LowFreq-IFT.woff2"

build/simplified-chinese_split1_unicodes.txt: subsets/simplified-chinese_split1.txt
	cat $(CURDIR)/subsets/simplified-chinese_split1.txt | awk '{print substr($$1, 3)}' > build/simplified-chinese_split1_unicodes.txt

##### Japanese (Noto Serif) #####

build/NotoSerifJP-HighFreq.ttf: original_fonts/NotoSerifJP-VF.ttf build/japanese-hifreq.txt
	bazel run $(BAZEL_OPTS) @harfbuzz//:hb-subset -- $(CURDIR)/original_fonts/NotoSerifJP-VF.ttf \
		--unicodes-file=$(CURDIR)/build/japanese-hifreq.txt \
		--no-hinting \
		--instance="wght=900" \
		-o $(CURDIR)/build/NotoSerifJP-HighFreq.ttf

docs/fonts/notoserifjphigh/NotoSerifJP-HighFreq-IFT.woff2: build/NotoSerifJP-HighFreq.ttf
	mkdir -p docs/fonts/notoserifjphigh
	bazel run $(BAZEL_OPTS) @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/build/NotoSerifJP-HighFreq.ttf \
	        --auto_config_quality=3 \
	        --auto_config_primary_script=Script_japanese \
		--output_path=$(CURDIR)/docs/fonts/notoserifjphigh/ \
		--output_font="NotoSerifJP-HighFreq-IFT.woff2"

##### Japanese (Noto Sans) #####

build/NotoSansJP-HighFreq.ttf: original_fonts/NotoSansJP-VF.ttf build/japanese-hifreq.txt
	bazel run $(BAZEL_OPTS) @harfbuzz//:hb-subset -- $(CURDIR)/original_fonts/NotoSansJP-VF.ttf \
		--unicodes-file=$(CURDIR)/build/japanese-hifreq.txt \
		--no-hinting \
		--instance="wght=400" \
		-o $(CURDIR)/build/NotoSansJP-HighFreq.ttf

docs/fonts/notosansjphigh/NotoSansJP-HighFreq-IFT.woff2: build/NotoSansJP-HighFreq.ttf
	mkdir -p docs/fonts/notosansjphigh
	bazel run $(BAZEL_OPTS) @ift_encoder//util:font2ift -- \
		--input_font=$(CURDIR)/build/NotoSansJP-HighFreq.ttf \
	        --auto_config_quality=3 \
	        --auto_config_primary_script=Script_japanese \
		--output_path=$(CURDIR)/docs/fonts/notosansjphigh/ \
		--output_font="NotoSansJP-HighFreq-IFT.woff2"

build/japanese-hifreq.txt : subsets/japanese-ordered.txt
	cat subsets/japanese-ordered.txt | grep 0x | head -n 6000 | awk '{print $$1}' > build/japanese-hifreq.txt
	cat subsets/japanese-supplemental.txt | grep -v "^#" >> build/japanese-hifreq.txt
	cat subsets/latin.txt | awk '{print $$1}' >> build/japanese-hifreq.txt

clean: clean_rust
	rm -f build/*
	rm -rf docs/fonts/* docs/rust-client/pkg/*

clean_rust:
	cd rust-client/; cargo clean
	rm -rf rust-client/pkg/*
	rm -f rust-client/Cargo.lock

