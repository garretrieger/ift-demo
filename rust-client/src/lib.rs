mod utils;

use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::JsFuture;
use web_sys::{Request, RequestInit, RequestMode, Response};

#[wasm_bindgen]
extern "C" {
    fn alert(s: &str);
}

#[wasm_bindgen]
struct IftState {
    font_subset: Vec<u8>,
    font_url: String,
    status: Status,
    pending_callbacks: Vec<js_sys::Function>,
    // TODO store requested codepoints, features, design space.
    // TODO store loaded patch data by url
}

enum Status {
    Uninitialized,
    LoadingInitFont,
    Ready,
    Extending,
    Error,
}

#[wasm_bindgen]
impl IftState {
    pub fn new(font_url: String) -> Self {
        Self {
            font_subset: vec![],
            font_url,
            status: Status::Uninitialized,
            pending_callbacks: vec![],
        }
    }

    pub fn extend(&mut self, codepoints: &[u32], callback: js_sys::Function) {
        self.pending_callbacks.push(callback);
        // TODO: update codepoint list.
        self.process();
    }

    pub fn font_size(&self) -> usize {
        self.font_subset.len()
    }

    pub fn font_ptr(&self) -> *const u8 {
        self.font_subset.as_ptr()
    }

    fn process(&mut self) {
        self.status = match self.status {
            Status::Uninitialized => self.start_init_font_load(),
            _ => todo!("Unimplemented!"),
        };

        if matches!(self.status, Status::Ready) {
            self.notify_pending_callbacks()
        }
    }

    fn notify_pending_callbacks(&mut self) {
        todo!()
    }

    fn start_init_font_load(&mut self) -> Status {
        todo!()
    }
}
