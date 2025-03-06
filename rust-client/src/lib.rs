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

    async fn ensure_patches_loaded(
        &self,
        state: &mut InnerState,
        patch_group: &PatchGroup<'_>,
    ) -> Result<(), String> {
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
            return Ok(());
        };

        // TODO use &str instead of String?
        let patches: Vec<Result<(String, Vec<u8>), String>> =
            join_all(uris_to_load.map(|uri| IftState::load_patch(uri))).await;
        for result in patches {
            let (uri, data) = result?;

            let Some(UriStatus::Pending(cached_data)) = state.patch_cache.get_mut(&uri) else {
                continue;
            };
            *cached_data = data;
        }

        Ok(())
    }

    async fn load_patch(uri: &str) -> Result<(String, Vec<u8>), String> {
        Ok((uri.to_string(), load_file(uri).await?))
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

        self.font_subset = match load_file(init_font_url).await {
            Err(msg) => {
                self.status = Status::Error(msg);
                return;
            }
            Ok(data) => data,
        };
        self.status = Status::Ready;
    }
}

async fn load_file(uri: &str) -> Result<Vec<u8>, String> {
    let opts = RequestInit::new();
    opts.set_method("GET");
    opts.set_mode(RequestMode::Cors);

    let Ok(request) = Request::new_with_str_and_init(uri, &opts) else {
        return Err(format!("Failed to create new GET request for: {}", uri));
    };

    let window = web_sys::window().unwrap();
    let Ok(response) = JsFuture::from(window.fetch_with_request(&request)).await else {
        return Err(format!("Load request for {} failed.", uri));
    };

    assert!(response.is_instance_of::<Response>());
    let response: Response = response.dyn_into().unwrap();
    if response.status() != 200 {
        return Err(format!(
            "Load request for {} failed. Status = {}",
            uri,
            response.status()
        ));
    }

    let Ok(buffer) = response.array_buffer() else {
        return Err("Unable to get array_buffer() from response.".to_string());
    };
    let Ok(buffer) = JsFuture::from(buffer).await else {
        return Err("Unable to get array_buffer() from response.".to_string());
    };
    let array = js_sys::Uint8Array::new(&buffer);
    let mut result = vec![0u8; array.length() as usize];
    array.copy_to(&mut result);
    Ok(result)
}
