import init, { IftState } from './rust-client/pkg/rust_client.js';

let page_index = -1;
let states = {};
let also_load_unicode_range = true;
let show_unicode_range = false;
let text_samples_promise = fetch("./sample-texts.json").then(response => response.json());

async function update_all_fonts() {
  if (page_index < 0) {
    show_intro();
    return;
  }

  text_samples_promise.then(async (text_samples) => {
    if (page_index >= text_samples.length) page_index = text_samples.length - 1;

    let sample = text_samples[page_index];
    let title_font = sample.title_font;
    let title_text = sample.title;
    let paragraph_font = sample.paragraph_font;
    let paragraph_text = sample.paragraph.join('');
    let title_features = [];
    if (Object.hasOwn(sample, "title_features")) {
      title_features = sample.title_features;
    }
    let paragraph_features = [];
    if (Object.hasOwn(sample, "paragraph_features")) {
      paragraph_features = sample.paragraph_features;
    }
    let title_ds = {};
    if (Object.hasOwn(sample, "title_design_space")) {
      title_ds = sample.title_design_space;
    }
    let paragraph_ds = {};
    if (Object.hasOwn(sample, "paragraph_design_space")) {
      paragraph_ds = sample.paragraph_design_space;
    }

    if (title_font.includes("Playfair")) {
      document.getElementById("title_ur").classList.add("playfair");
    } else {
      document.getElementById("title_ur").classList.remove("playfair");
    }


    let p1 = update_fonts(title_text,
			  title_font,
			  "Title Font",
			  title_features,
			  title_ds);
    let p2 = update_fonts(paragraph_text,
			  paragraph_font,
			  "Paragraph Font",
			  paragraph_features,
			  paragraph_ds);

    let f1 = await p1;
    let f2 = await p2;
    document.fonts.clear();
    document.fonts.add(f1);
    document.fonts.add(f2);

    document.getElementById("title_pfe").innerHTML = title_text;
    document.getElementById("paragraph_pfe").innerHTML = paragraph_text;
    if (also_load_unicode_range) {
      document.getElementById("title_ur").innerHTML = title_text;
      document.getElementById("paragraph_ur").innerHTML = paragraph_text;
    }

    document.getElementById("prev").disabled = (page_index == -1);
    document.getElementById("next").disabled = (page_index ==  text_samples.length - 1);

    update_sample_toggle();
  }).catch(e => {
    console.log("Failed to load the text samples: ", e);
  });
}

function show_intro() {
  document.getElementById("prev").disabled = true;
  document.getElementById("next").disabled = false;

  document.getElementById("pfe_sample").classList.add("hide");
  document.getElementById("ur_sample").classList.add("hide");
  document.getElementById("intro").classList.remove("hide");
}

function update_sample_toggle() {
  document.getElementById("sample_toggle").style.visibility =
      (page_index >= 0 && also_load_unicode_range) ? "visible" : "hidden";
  document.getElementById("sample_toggle").value =
      show_unicode_range ? "Show Incremental Font Transfer" : "Show unicode range";

  if (page_index < 0) {
    return;
  }

  if (show_unicode_range) {
    document.getElementById("pfe_sample").classList.add("hide");
    document.getElementById("ur_sample").classList.remove("hide");
    document.getElementById("intro").classList.add("hide");
  } else {
    document.getElementById("pfe_sample").classList.remove("hide");
    document.getElementById("ur_sample").classList.add("hide");
    document.getElementById("intro").classList.add("hide");
  }
}

function update_fonts(text, font_id, font_face, features, ds) {
  let cps = new Set();
  for (let i = 0; text.codePointAt(i); i++) {
    cps.add(text.codePointAt(i));
  }

  let cps_array = [];
  for (let cp of cps) {
    cps_array.push(cp);
  }

  let axes = new Map();
  for (let [tag, value] of Object.entries(ds)) {
    axes.set(tag, value);
  }

  return patch_codepoints(font_id, font_face, cps_array, features, axes);
}

function save_font(filename, data) {
  const blob = new Blob([data], {type: 'font/ttf'});
  const elem = window.document.createElement('a');
  elem.href = window.URL.createObjectURL(blob);
  elem.download = filename;
  document.body.appendChild(elem);
  elem.click();
  document.body.removeChild(elem);
}

const woff2_decoder = {
  unwoff2: (encoded) => {
    let decoder = new window.Woff2Decoder(encoded);
    return decoder.data();
  }
}

function patch_codepoints(font_id, font_face, cps, features, axes) {
  if (!states[font_id]) {
    states[font_id] = IftState.new(font_id);
  }
  let state = states[font_id];

  // TODO(garretrieger): check return values of add_* methods and don't update the font
  //                     if no changes are made.

  for (const [tag, point] of axes) {
    state.add_design_space_to_target_subset_definition(tag, point, point);
  }

  for (const tag of features) {
    state.add_feature_to_target_subset_definition(tag);
  }

  state.add_to_target_subset_definition(cps);
  return state.current_font_subset(woff2_decoder).then(font => {
    const font_data = new Uint8Array(window.ift_memory.buffer, font.data(), font.len());
    let descriptor = {};
    if (font_id.includes("Roboto")) {
      descriptor = {
	weight: "100 900",
	stretch: "75% 100%"
      };
    } else  if (font_id.includes("NotoSerif")) {
      descriptor = {
	weight: "900",
      };
    } else if (font_id.includes("NotoSans")) {
      descriptor = {
	weight: "100 900",
      };
    }

    font = new FontFace(font_face, font_data, descriptor);
    return font.load();
  })
}

let pfe_total = 0;
let ur_total = 0;
let total = 0;
const observer = new PerformanceObserver((list, obj) => {
  list.getEntries().forEach((r) => {
    if ((r.name.includes("/experimental/patch_subset")
         || r.name.includes("/fonts/")
         || r.name.includes("_iftb"))
        && (r.name.endsWith(".ttf") || r.name.endsWith(".otf") || r.name.endsWith(".ift_tk") || r.name.endsWith(".ift_gk") || r.name.endsWith(".woff2"))) {
      pfe_total += r.transferSize;
    }
    if (r.name.includes("/s/")) {
      ur_total += r.transferSize;
    }
  });
  schedule_update_transfer_bars();
});
observer.observe({ type: "resource", buffered: true });

let transfer_bars_update = null;
function schedule_update_transfer_bars() {
  if (transfer_bars_update != null) {
    return;
  }

  transfer_bars_update = setTimeout(() => {
    update_transfer_bars();
  }, 500);
}

function update_transfer_bars() {
  transfer_bars_update = null;
  let new_total = pfe_total + ur_total;
  let max = Math.max(Math.max(pfe_total, ur_total), 1);
  if (new_total <= total) {
    return;
  }

  total = new_total;
  document.getElementById("pfe_bar").style.width =
      ((pfe_total / max) * 100) + "%";
  document.getElementById("pfe_bar").textContent = as_string(pfe_total);

  document.getElementById("ur_bar").style.width =
      ((ur_total / max) * 100) + "%";
  document.getElementById("ur_bar").textContent = as_string(ur_total);

  document.getElementById("ur_byte_counter").style.visibility =
      (also_load_unicode_range ? "visible" : "hidden");
}

function as_string(byte_count) {
    return Math.round(byte_count / 1000).toLocaleString() + " kb";
}

init().then(function(Module) {
  window.ift_memory = Module.memory;
});

window.addEventListener('DOMContentLoaded', function() {
    let prev = document.getElementById("prev");
    prev.addEventListener("click", function() {
        page_index--;
        if (page_index < -1) page_index = -1;
        update_all_fonts();
    });
    let next = document.getElementById("next");
    next.addEventListener("click", function() {
      page_index++;
      update_all_fonts();
    });
    let viet = document.getElementById("to-vietnamese");
    viet.addEventListener("click", function() {
        page_index = 1;
        update_all_fonts();
    });
    let cg = document.getElementById("to-cyr-greek");
    cg.addEventListener("click", function() {
        page_index = 2;
        update_all_fonts();
    });
    let sc = document.getElementById("to-small-caps");
    sc.addEventListener("click", function() {
        page_index = 4;
        update_all_fonts();
    });
    let w = document.getElementById("to-width");
    w.addEventListener("click", function() {
        page_index = 5;
        update_all_fonts();
    });
    let sim_chinese = document.getElementById("to-sim-chinese");
    sim_chinese.addEventListener("click", function() {
        page_index = 6;
        update_all_fonts();
    });
    let lo_freq_sim_chinese = document.getElementById("to-lo-freq-sim-chinese");
    lo_freq_sim_chinese.addEventListener("click", function() {
        page_index = 14;
        update_all_fonts();
    });

    document.getElementById("also_ur").addEventListener("change", function(e) {
        also_load_unicode_range = e.target.checked;
        if (!also_load_unicode_range) {
            sample_toggle = false;
        }
        update_all_fonts();
        update_sample_toggle();
    });
    document.getElementById("sample_toggle").addEventListener("click", e => {
        show_unicode_range = !show_unicode_range;
        update_sample_toggle();
    });
});
