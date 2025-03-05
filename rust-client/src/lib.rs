mod utils;

use wasm_bindgen::prelude::*;

#[wasm_bindgen]
extern "C" {
    fn alert(s: &str);
}

#[wasm_bindgen]
struct IftState {
    font_subset: Vec<u8>,
}

#[wasm_bindgen]
impl IftState {
    pub fn new(font_url: &str) -> Self {
        // TODO: implement me!
        Self {
            font_subset: vec![1, 2, 3, 4],
        }
    }

    pub fn extend(&self, codepoints: &[u32], callback: &js_sys::Function) {
        if !codepoints.is_empty() {
            let this = JsValue::null();
            let v = JsValue::from(codepoints[0]);
            callback.call1(&this, &v);
        }
        // TODO: implement me!
    }

    pub fn font_size(&self) -> usize {
        self.font_subset.len()
    }

    pub fn font_ptr(&self) -> *const u8 {
        self.font_subset.as_ptr()
    }
}
