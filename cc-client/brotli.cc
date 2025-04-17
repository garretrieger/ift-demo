#include <emscripten/bind.h>

#include "common/brotli_binary_patch.h"
#include "common/font_data.h"
#include "woff2/decode.h"

using namespace emscripten;
using common::hb_blob_unique_ptr;
using common::make_hb_blob;
using common::FontData;


class BrotliPatch {
 public:
  BrotliPatch(std::string base, std::string patch) :
      patcher(), base_str(base), patch_str(patch), out() {
  }

  bool apply() {
    hb_blob_unique_ptr base_blob = make_hb_blob(hb_blob_create(base_str.data(), base_str.length(),
                                                               HB_MEMORY_MODE_READONLY, nullptr, nullptr));
    hb_blob_unique_ptr patch_blob = make_hb_blob(hb_blob_create(patch_str.data(), patch_str.length(),
                                                               HB_MEMORY_MODE_READONLY, nullptr, nullptr));
    FontData base(base_blob.get());
    FontData patch(patch_blob.get());

    return patcher.Patch(base, patch, &out).ok();
  }

  emscripten::val data() {
    return emscripten::val(emscripten::typed_memory_view(
        out.size(), (const uint8_t*) out.data()));
  }

 private:
  common::BrotliBinaryPatch patcher;
  std::string base_str;
  std::string patch_str;
  FontData out;
};


class Woff2Decoder {
 public:
  Woff2Decoder(std::string woff2) {
    woff2::WOFF2StringOut out(&output_buffer);
    woff2::ConvertWOFF2ToTTF((const uint8_t*) woff2.data(), woff2.size(), &out);
  }

  emscripten::val data() const {
    return emscripten::val(emscripten::typed_memory_view(
        output_buffer.size(), (const uint8_t*) output_buffer.data()));
  }

 private:
  std::string output_buffer;
};

EMSCRIPTEN_BINDINGS(BrotliPatch) {
  emscripten::class_<BrotliPatch>("BrotliPatch")
      .constructor<std::string, std::string>()
          .function("apply", &BrotliPatch::apply)
          .function("data", &BrotliPatch::data);
}

EMSCRIPTEN_BINDINGS(Woff2Decoder) {
  emscripten::class_<Woff2Decoder>("Woff2Decoder")
      .constructor<std::string>()
          .function("data", &Woff2Decoder::data);
}
