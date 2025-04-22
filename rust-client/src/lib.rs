mod utils;

use futures::future::join_all;
use incremental_font_transfer::{
    patch_group::{PatchGroup, UriStatus},
    patchmap::{DesignSpace, SubsetDefinition},
};

use read_fonts::{
    collections::RangeSet,
    types::{Fixed, Tag},
    FontRef,
};
use shared_brotli_patch_decoder::{decode_error::DecodeError, SharedBrotliDecoder};
use std::path::{Path, PathBuf};
use std::{collections::HashMap, sync::Arc};
use tokio::sync::Mutex;
use wasm_bindgen::prelude::*;
use wasm_bindgen_futures::JsFuture;
use web_sys::{Request, RequestInit, RequestMode, Response};

#[wasm_bindgen]
extern "C" {
    pub type BrotliPatcher;

    #[wasm_bindgen(structural, method)]
    pub fn patch(this: &BrotliPatcher, base: &[u8], patch: &[u8]) -> Option<Box<[u8]>>;

    pub type Woff2Decoder;

    #[wasm_bindgen(structural, method)]
    pub fn unwoff2(this: &Woff2Decoder, encoded: &[u8]) -> Box<[u8]>;

    #[wasm_bindgen(js_namespace = console, js_name = log)]
    fn log_u8(a: u8);
}

impl SharedBrotliDecoder for BrotliPatcher {
    fn decode(
        &self,
        encoded: &[u8],
        shared_dictionary: Option<&[u8]>,
        max_uncompressed_length: usize,
    ) -> Result<Vec<u8>, DecodeError> {
        let bytes = match shared_dictionary {
            None => self.patch(&[], encoded),
            Some(shared_dictionary) => self.patch(shared_dictionary, encoded),
        }
        .ok_or(DecodeError::InvalidStream("".to_string()))?;

        if bytes.len() > max_uncompressed_length {
            return Err(DecodeError::MaxSizeExceeded);
        }

        Ok(bytes.iter().copied().collect())
    }
}

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

    pub fn add_design_space_to_target_subset_definition(
        &mut self,
        tag: &str,
        start: f64,
        end: f64,
    ) -> bool {
        let Ok(tag) = Tag::new_checked(tag.as_bytes()) else {
            return false;
        };

        let range = Fixed::from_f64(start)..=Fixed::from_f64(end);
        match &mut self.target_subset_definition.design_space {
            DesignSpace::All => {
                let mut ranges: RangeSet<Fixed> = Default::default();
                ranges.insert(range);
                self.target_subset_definition.design_space =
                    DesignSpace::Ranges([(tag, ranges)].into_iter().collect());
                true
            }
            DesignSpace::Ranges(ranges) => {
                let range_set = ranges.entry(tag).or_default();
                range_set.insert(range);
                // TODO(garretrieger): detect if a change was made or not.
                //   return true only if the insert made a change.
                true
            }
        }
    }

    pub async fn current_font_subset(
        &self,
        patcher: &BrotliPatcher,
        woff2: &Woff2Decoder,
    ) -> Result<FontSubset, String> {
        let lock = Arc::clone(&self.state);
        let mut state = lock.lock().await;

        loop {
            match &state.status {
                Status::Uninitialized => state.initialize(&self.font_url, woff2).await,
                Status::Error(err) => return Err(err.clone()),
                Status::Ready => {
                    if let Err(msg) = self.ensure_extended(&mut state, patcher).await {
                        state.status = Status::Error(msg);
                        continue;
                    }
                    break;
                }
            };
        }

        Ok(FontSubset {
            data: state.font_subset.as_ptr(),
            length: state.font_subset.len(),
        })
    }

    async fn ensure_extended(
        &self,
        state: &mut InnerState,
        patcher: &BrotliPatcher,
    ) -> Result<(), String> {
        loop {
            state.font_subset = {
                // check the current font against the target subset
                let font = FontRef::new(&state.font_subset)
                    .map_err(|e| format!("Failed to load current font subset: {}", e))?;
                let patch_group =
                    PatchGroup::select_next_patches(font, &self.target_subset_definition)
                        .map_err(|e| format!("Failed to compute the patch group: {}", e))?;
                if !patch_group.has_uris() {
                    // No more remaining work.
                    return Ok(());
                }

                // There are pending urls fetch any we don't yet have.
                self.ensure_patches_loaded(&mut state.patch_cache, &patch_group)
                    .await?;

                // Apply them and update the current font subset
                patch_group
                    .apply_next_patches(&mut state.patch_cache)
                    .map_err(|e| format!("Failed to extend the current IFT font subset: {}", e))?
            };
        }
    }

    async fn ensure_patches_loaded(
        &self,
        patch_cache: &mut HashMap<String, UriStatus>,
        patch_group: &PatchGroup<'_>,
    ) -> Result<(), String> {
        // TODO change back to iter
        let mut uris_to_load: Vec<(&str, String)> = vec![];
        for uri in patch_group.uris() {
            if patch_cache.contains_key(uri) {
                continue;
            }
            uris_to_load.push((uri, combine_urls(&self.font_url, uri)));
        }

        let uris_to_load = uris_to_load;
        if uris_to_load.is_empty() {
            // Nothing to do.
            return Ok(());
        };

        let patches: Vec<Result<(String, Vec<u8>), String>> = join_all(
            uris_to_load
                .iter()
                .map(|(uri, full_uri)| IftState::load_patch(uri, &full_uri)),
        )
        .await;
        for result in patches {
            let (uri, data) = result?;
            patch_cache.insert(uri, UriStatus::Pending(data));
        }

        Ok(())
    }

    async fn load_patch(uri: &str, full_uri: &str) -> Result<(String, Vec<u8>), String> {
        Ok((uri.to_string(), load_file(full_uri).await?))
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

    async fn initialize(&mut self, init_font_url: &str, woff2: &Woff2Decoder) {
        if matches!(self.status, Status::Uninitialized) {
        } else {
            panic!("Can only be called on an uninitialized client.");
        }

        let woff2_data = match load_file(init_font_url).await {
            Err(msg) => {
                self.status = Status::Error(msg);
                return;
            }
            Ok(data) => data,
        };

        let ttf = woff2.unwoff2(&woff2_data);
        self.font_subset = ttf.iter().copied().collect();

        self.status = Status::Ready;
    }
}

fn combine_urls(base: &str, relative: &str) -> String {
    let mut result = PathBuf::from(Path::new(base));
    result.pop(); //remove the file name from the base path.
    result.push(Path::new(relative));
    result.to_string_lossy().to_string()
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
