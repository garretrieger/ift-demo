/* tslint:disable */
/* eslint-disable */

export class FontSubset {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    data(): number;
    len(): number;
}

export class IftState {
    private constructor();
    free(): void;
    [Symbol.dispose](): void;
    add_design_space_to_target_subset_definition(tag: string, start: number, end: number): boolean;
    add_feature_to_target_subset_definition(feature: string): boolean;
    /**
     * Adds the supplied codepoints to the target subset definition.
     *
     * Returns true if at least one new codepoint was added to the definition.
     */
    add_to_target_subset_definition(codepoints: Uint32Array): boolean;
    current_font_subset(woff2: any): Promise<FontSubset>;
    static new(font_url: string): IftState;
}

export type InitInput = RequestInfo | URL | Response | BufferSource | WebAssembly.Module;

export interface InitOutput {
    readonly memory: WebAssembly.Memory;
    readonly __wbg_fontsubset_free: (a: number, b: number) => void;
    readonly __wbg_iftstate_free: (a: number, b: number) => void;
    readonly fontsubset_data: (a: number) => number;
    readonly fontsubset_len: (a: number) => number;
    readonly iftstate_add_design_space_to_target_subset_definition: (a: number, b: number, c: number, d: number, e: number) => number;
    readonly iftstate_add_feature_to_target_subset_definition: (a: number, b: number, c: number) => number;
    readonly iftstate_add_to_target_subset_definition: (a: number, b: number, c: number) => number;
    readonly iftstate_current_font_subset: (a: number, b: any) => any;
    readonly iftstate_new: (a: number, b: number) => number;
    readonly wasm_bindgen__convert__closures_____invoke__ha3202597bd061669: (a: number, b: number, c: any) => [number, number];
    readonly wasm_bindgen__convert__closures_____invoke__hbe85fd29ed6f7998: (a: number, b: number, c: any, d: any) => void;
    readonly __wbindgen_malloc: (a: number, b: number) => number;
    readonly __wbindgen_realloc: (a: number, b: number, c: number, d: number) => number;
    readonly __wbindgen_exn_store: (a: number) => void;
    readonly __externref_table_alloc: () => number;
    readonly __wbindgen_externrefs: WebAssembly.Table;
    readonly __wbindgen_destroy_closure: (a: number, b: number) => void;
    readonly __externref_table_dealloc: (a: number) => void;
    readonly __wbindgen_start: () => void;
}

export type SyncInitInput = BufferSource | WebAssembly.Module;

/**
 * Instantiates the given `module`, which can either be bytes or
 * a precompiled `WebAssembly.Module`.
 *
 * @param {{ module: SyncInitInput }} module - Passing `SyncInitInput` directly is deprecated.
 *
 * @returns {InitOutput}
 */
export function initSync(module: { module: SyncInitInput } | SyncInitInput): InitOutput;

/**
 * If `module_or_path` is {RequestInfo} or {URL}, makes a request and
 * for everything else, calls `WebAssembly.instantiate` directly.
 *
 * @param {{ module_or_path: InitInput | Promise<InitInput> }} module_or_path - Passing `InitInput` directly is deprecated.
 *
 * @returns {Promise<InitOutput>}
 */
export default function __wbg_init (module_or_path?: { module_or_path: InitInput | Promise<InitInput> } | InitInput | Promise<InitInput>): Promise<InitOutput>;
