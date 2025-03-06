mod utils;

use futures::future::{self, join_all, FutureExt};
use incremental_font_transfer::{
    patch_group::{PatchGroup, UriStatus},
    patchmap::SubsetDefinition,
};
use std::future::Future;

use read_fonts::{collections::int_set::IntSet, FontRef};
use std::{collections::HashMap, sync::Arc};
use tokio::sync::Mutex;
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::JsFuture;
use web_sys::{Request, RequestInit, RequestMode, Response};

#[wasm_bindgen]
pub struct IftState {
    font_url: String,
    target_subset_definition: SubsetDefinition,
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

// Inner state is the collection of things that are accessed through
// a lock. These are the parts that get modified by the extension process.
struct InnerState {
    status: Status,
    font_subset: Vec<u8>,
    patch_cache: HashMap<String, UriStatus>,
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
            target_subset_definition: Default::default(),
            state: Arc::new(Mutex::new(InnerState::new())),
        }
    }

    /// Adds the supplied codepoints to the target subset definition.
    ///
    /// Returns true if at least one new codepoint was added to the definition.
    pub fn add_to_target_subset_definition(&mut self, codepoints: &[u32]) -> bool {
        let start_len = self.target_subset_definition.codepoints.len();
        self.target_subset_definition
            .codepoints
            .extend_unsorted(codepoints.iter().map(|v| *v));
        self.target_subset_definition.codepoints.len() > start_len
    }

    pub async fn current_font_subset(&self) -> Result<FontSubset, String> {
        let lock = Arc::clone(&self.state);
        let mut state = lock.lock().await;

        loop {
            match &state.status {
                Status::Uninitialized => state.initialize(&self.font_url).await,
                Status::Error(err) => return Err(err.clone()),
                Status::Ready => {
                    todo!()
                }
                _ => break,
            };
        }

        // TODO ...

        Ok(FontSubset {
            data: state.font_subset.as_ptr(),
            length: state.font_subset.len(),
        })
    }

    async fn ensure_extended(&self, state: &mut InnerState) -> Result<(), String> {
        // check the current font against the target subset
        let font =
            FontRef::new(&state.font_subset).map_err(|_| "Failed to load current font subset.")?;
        let patch_group = PatchGroup::select_next_patches(font, &self.target_subset_definition)
            .map_err(|_| "Failed to compute the patch group.")?;

        // if there are pending urls fetch those
        // once all fetches are done extend the font subset
        // break out of the loop if no work remaings.

        todo!()
    }

    async fn ensure_patches_loaded(&self, state: &mut InnerState, patch_group: &PatchGroup<'_>) {
        let mut uris_to_load = patch_group
            .uris()
            .filter(|uri| {
                let e = state.patch_cache.entry(uri.to_string());
                let status = e.or_insert(UriStatus::Pending(Default::default()));
                matches!(status, UriStatus::Pending(_))
            })
            .peekable();

        if uris_to_load.peek().is_none() {
            // Nothing to do.
            return;
        };

        let futures: Vec<_> = uris_to_load
            .map(|uri| IftState::load_patch(uri).boxed())
            .collect();

        let patches: Vec<(&str, Vec<u8>)> = join_all(futures).await;
        for (uri, data) in patches {
            let Some(UriStatus::Pending(cached_data)) = state.patch_cache.get_mut(uri) else {
                continue;
            };
            *cached_data = data;
        }
    }

    async fn load_patch(uri: &str) -> (&str, Vec<u8>) {
        todo!()
    }
}

impl InnerState {
    fn new() -> Self {
        InnerState {
            status: Status::Uninitialized,
            font_subset: vec![],
            patch_cache: Default::default(),
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
