mod utils;

use std::sync::Arc;
use tokio::sync::Mutex;
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::JsFuture;
use web_sys::{Request, RequestInit, RequestMode, Response};

#[wasm_bindgen]
pub struct IftState {
    font_url: String,
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
    Error, // TODO have an error message?
}

#[wasm_bindgen]
impl IftState {
    pub fn new(font_url: String) -> Self {
        Self {
            font_url,
            state: Arc::new(Mutex::new(InnerState::new())),
        }
    }

    pub async fn extend(&self, codepoints: &[u32]) -> FontSubset {
        {
            let mut lock = Arc::clone(&self.state);
            let mut state = lock.lock().await;
            if matches!(state.status, Status::Uninitialized) {
                state.initialize("common.css").await;
            }

            // TODO ...

            FontSubset {
                data: state.font_subset.as_ptr(),
                length: state.font_subset.len(),
            }
        }
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

        let opts = RequestInit::new();
        opts.set_method("GET");
        opts.set_mode(RequestMode::Cors);

        let Ok(request) = Request::new_with_str_and_init(init_font_url, &opts) else {
            // TODO return error
            return;
        };

        let window = web_sys::window().unwrap();
        JsFuture::from(window.fetch_with_request(&request)).await;
        // TODO actually get the value of the response...
        self.status = Status::Ready;
        self.font_subset = vec![42, 1, 2, 3]

        // TODO....
        /*
        let opts = RequestInit::new();
        opts.set_method("GET");
        opts.set_mode(RequestMode::Cors);

        let Ok(request) = Request::new_with_str_and_init(&self.font_url, &opts) else {
            return Status::Error;
        };

        let window = web_sys::window().unwrap();
        let future = JsFuture::from(window.fetch_with_request(&request));
        todo!()
        */
        //let resp_value = JsFuture::from(window.fetch_with_request(&request)).await?;

        // `resp_value` is a `Response` object.
        //assert!(resp_value.is_instance_of::<Response>());
        //let resp: Response = resp_value.dyn_into().unwrap();

        // Convert this other `Promise` into a rust `Future`.
        //let json = JsFuture::from(resp.json()?).await?;

        // Send the JSON response back to JS.
        //Ok(json)
    }
}
