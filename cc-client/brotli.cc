#include <emscripten/bind.h>

#include "common/brotli_binary_patch.h"
#include "common/font_data.h"

using namespace emscripten;
using common::hb_blob_unique_ptr;
using common::make_hb_blob;
using common::FontData;


class BrotliPatch {
 public:
  BrotliPatch(std::string base_str, std::string patch_str) :
      patcher(), base_data(make_hb_blob()), patch_data(make_hb_blob()), out() {
    base_data = make_hb_blob(hb_blob_create(base_str.data(), base_str.length(),
                                            HB_MEMORY_MODE_READONLY, nullptr, nullptr));
    patch_data = make_hb_blob(hb_blob_create(patch_str.data(), patch_str.length(),
                                             HB_MEMORY_MODE_READONLY, nullptr, nullptr));
  }

  bool apply() {
    FontData base(base_data.get());
    FontData patch(patch_data.get());
    return patcher.Patch(base, patch, &out).ok();
  }

  emscripten::val data() {
    return emscripten::val(emscripten::typed_memory_view(
        out.size(), (const uint8_t*) out.data()));
  }

 private:
  common::BrotliBinaryPatch patcher;
  hb_blob_unique_ptr base_data;
  hb_blob_unique_ptr patch_data;
  FontData out;
};

EMSCRIPTEN_BINDINGS(BrotliPatch) {
  emscripten::class_<BrotliPatch>("BrotliPatch")
      .constructor<std::string, std::string>()
          .function("apply", &BrotliPatch::apply)
          .function("data", &BrotliPatch::data);
}
