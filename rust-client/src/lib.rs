mod utils;

use read_fonts::collections::int_set::IntSet;
use std::sync::Arc;
use tokio::sync::Mutex;
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::JsFuture;
use web_sys::{Request, RequestInit, RequestMode, Response};

#[wasm_bindgen]
pub struct IftState {
    font_url: String,
    target_codepoints: IntSet<u32>,
    state: Arc<Mutex<InnerState>>,
}

#[wasm_bindgen]
pub struct FontSubset {
    data: *const u8,
    length: usize,
}

#[wasm_bindgen]
impl FontSubset {
    pub fn len(&self) -> usize {
        self.length
    }

    pub fn data(&self) -> *const u8 {
        self.data
    }
}

struct InnerState {
    status: Status,
    font_subset: Vec<u8>,
    // TODO store requested codepoints, features, design space.
    // TODO store loaded patch data by url
}

enum Status {
    Uninitialized,
    Ready,
    LoadingPatches,
    Error(String),
}

#[wasm_bindgen]
impl IftState {
    pub fn new(font_url: String) -> Self {
        Self {
            font_url,
            target_codepoints: IntSet::empty(),
            state: Arc::new(Mutex::new(InnerState::new())),
        }
    }

    /// Adds the supplied codepoints to the target subset definition.
    ///
    /// Returns true if at least one new codepoint was added to the definition.
    pub fn add_to_target_subset_definition(&mut self, codepoints: &[u32]) -> bool {
        let start_len = self.target_codepoints.len();
        self.target_codepoints
            .extend_unsorted(codepoints.iter().map(|v| *v));
        self.target_codepoints.len() > start_len
    }

    pub async fn current_font_subset(&self) -> Result<FontSubset, String> {
        let mut lock = Arc::clone(&self.state);
        let mut state = lock.lock().await;

        loop {
            match &state.status {
                Status::Uninitialized => state.initialize(&self.font_url).await,
                Status::Error(err) => return Err(err.clone()),
                _ => break,
            };
        }

        // TODO ...

        Ok(FontSubset {
            data: state.font_subset.as_ptr(),
            length: state.font_subset.len(),
        })
    }
}

impl InnerState {
    fn new() -> Self {
        InnerState {
            status: Status::Uninitialized,
            font_subset: vec![],
        }
    }

    async fn initialize(&mut self, init_font_url: &str) {
        if matches!(self.status, Status::Uninitialized) {
        } else {
            panic!("Can only be called on an uninitialized client.");
        }

        // TODO move request fetching code to a shared util function.

        let opts = RequestInit::new();
        opts.set_method("GET");
        opts.set_mode(RequestMode::Cors);

        let Ok(request) = Request::new_with_str_and_init(init_font_url, &opts) else {
            self.status = Status::Error("Failed to create new GET request.".to_string());
            return;
        };

        let window = web_sys::window().unwrap();
        let Ok(response) = JsFuture::from(window.fetch_with_request(&request)).await else {
            self.status = Status::Error(format!(
                "Init font load request for {} failed.",
                init_font_url
            ));
            return;
        };

        assert!(response.is_instance_of::<Response>());
        let response: Response = response.dyn_into().unwrap();
        if response.status() != 200 {
            self.status = Status::Error(format!(
                "Init font load request for {} failed. Status = {}",
                init_font_url,
                response.status()
            ));
            return;
        }

        let Ok(buffer) = response.array_buffer() else {
            self.status = Status::Error("Unable to get array_buffer() from response.".to_string());
            return;
        };
        let Ok(buffer) = JsFuture::from(buffer).await else {
            self.status = Status::Error("Unable to get array_buffer() from response.".to_string());
            return;
        };
        let array = js_sys::Uint8Array::new(&buffer);
        self.font_subset.resize(array.length() as usize, 0);
        array.copy_to(&mut self.font_subset);

        self.status = Status::Ready;
    }
}
