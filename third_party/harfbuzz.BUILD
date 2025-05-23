# Define HAVE_XLOCALE_H for OSX

config_setting(
    name = "macos",
    constraint_values = [
        "@platforms//os:osx",
    ],
)

cc_binary(
    name = "hb-subset",
    srcs = [
        "util/hb-subset.cc",
        "util/batch.hh",
        "util/options.hh",
        "util/face-options.hh",
        "util/main-font-text.hh",
        "util/text-options.hh",
        "util/output-options.hh",
	"util/helper-subset.hh",
    ],
    deps = [
        ":harfbuzz",
        "@glib//glib",
    ],
)

cc_library(
    name = "harfbuzz",
    srcs = glob(
        [
            "src/hb.hh",
            "src/hb-*.cc",
            "src/hb-*.hh",
            "src/hb-subset-*.cc",
            "src/hb-subset-*.hh",
            "src/OT/glyf/*.hh",
            "src/OT/Layout/GSUB/*.hh",
            "src/OT/Layout/GPOS/*.hh",
            "src/OT/Layout/GDEF/*.hh",            
            "src/OT/Layout/Common/*.hh",
            "src/OT/Layout/*.hh",
            "src/OT/Color/CBDT/*.hh",
            "src/OT/Color/COLR/*.hh",
            "src/OT/Color/sbix/*.hh",
            "src/OT/Color/svg/*.hh",
            "src/OT/Color/CPAL/*.hh",
            "src/OT/name/name.hh",
            "src/OT/Var/VARC/*.hh",
            "src/OT/Var/VARC/*.cc",
            "src/graph/*.hh",
            "src/graph/*.cc",
        ],
        exclude = [
            "src/test-*.cc",
            "src/graph/test-*.cc",
            "src/hb-coretext.cc",
            "src/hb-ft.cc",
            "src/hb-glib.cc",
            "src/hb-gobject-enums.cc",
            "src/hb-gobject-structs.cc",
            "src/hb-graphite2.cc",
            "src/hb-icu.cc",
            "src/hb-uniscribe.cc",
            "src/hb-directwrite.cc",  # exclude windows platform related files.
        ],
    ),
    deps = [
        "@ift_encoder//third_party/harfbuzz:config",
    ],
    hdrs = [
        "src/hb.h",
        "src/hb-aat.h",
        "src/hb-aat-layout.h",
        "src/hb-blob.h",
        "src/hb-buffer.h",
        "src/hb-common.h",
        "src/hb-deprecated.h",
        "src/hb-face.h",
        "src/hb-font.h",
        "src/hb-paint.h",
        "src/hb-cairo.h",
        "src/hb-map.h",
        "src/hb-draw.h",
        "src/hb-ot.h",
        "src/hb-ot-color.h",
        "src/hb-ot-deprecated.h",
        "src/hb-ot-font.h",
        "src/hb-ot-layout.h",
        "src/hb-ot-math.h",
        "src/hb-ot-meta.h",
        "src/hb-ot-metrics.h",
        "src/hb-ot-name.h",
        "src/hb-ot-shape.h",
        "src/hb-ot-var.h",
        "src/hb-set.h",
        "src/hb-shape.h",
        "src/hb-shape-plan.h",
        "src/hb-style.h",
        "src/hb-subset.h",
        "src/hb-subset-serialize.h",
        "src/hb-unicode.h",
        "src/hb-version.h",
    ],
    copts = [
        "-DHAVE_CONFIG_H",
        "-DHB_EXPERIMENTAL_API",
        "-Iexternal/w3c_patch_subset_incxfer/third_party/harfbuzz",
    ] + select({
        ":macos": ["-DHAVE_XLOCALE_H=1"],
        "//conditions:default": [],
    }),
    includes = [
        "src",
        "src/hb-ucdn",
    ],
    visibility = ["//visibility:public"],
)
