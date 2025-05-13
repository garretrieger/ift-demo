#include <emscripten/bind.h>

#include "woff2/decode.h"

using namespace emscripten;


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

EMSCRIPTEN_BINDINGS(Woff2Decoder) {
  emscripten::class_<Woff2Decoder>("Woff2Decoder")
      .constructor<std::string>()
          .function("data", &Woff2Decoder::data);
}
