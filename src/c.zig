const builtin = @import("builtin");

pub const EcsInOutKind = enum(c_int) {
    ecs_in_out_default,
    ecs_in_out_none,
    ecs_in_out,
    ecs_in,
    ecs_out,
};

pub const EcsOperKind = enum(c_int) {
    ecs_and,
    ecs_or,
    ecs_not,
    ecs_optional,
    ecs_and_from,
    ecs_or_from,
    ecs_not_from,
};

pub const EcsEntityDesc = extern struct {
    _canary: i32,
    id: u64,
    name: [*c]const u8,
    sep: [*c]const u8,
    root_sep: [*c]const u8,
    symbol: [*c]const u8,
    use_low_id: bool,
    add: [32]u64,
    add_expr: [*c]const u8,
};

pub const EcsId = u64;
pub const EcsFlags8 = u8;
pub const EcsFlags32 = u32;
pub const EcsFlags64 = u64;
pub const EcsEntity = u64;
pub const EcsSize = i32;

pub const EcsMixins = opaque {};

pub const EcsTermId = extern struct {
    id: EcsEntity,
    name: [*c]u8,
    trav: EcsEntity,
    flags: EcsFlags32,
};

pub const EcsTerm = extern struct {
    id: EcsId,
    src: EcsTermId,
    first: EcsTermId,
    second: EcsTermId,
    inout: EcsInOutKind,
    oper: EcsOperKind,
    id_flags: EcsId,
    name: [*c]u8,
    field_index: i32,
    move: bool,
};

pub const EcsHeader = extern struct {
    magic: i32,
    type: i32,
    mixins: ?*EcsMixins,
};

pub const EcsTable = opaque {};

pub const EcsTableRange = extern struct {
    table: ?*EcsTable,
    offset: i32,
    count: i32,
};

pub const EcsVar = extern struct {
    range: EcsTableRange,
    entity: EcsEntity,
};

pub const EcsTableRecord = opaque {};

pub const EcsRecord = extern struct {
    table: ?*EcsTable,
    row: u32,
};

pub const EcsIdRecord = opaque {};

pub const EcsRef = extern struct {
    entity: EcsEntity,
    id: EcsEntity,
    tr: ?*EcsTableRecord,
    record: [*c]EcsRecord,
};

pub const EcsTableCacheHdr = opaque {};

pub const EcsTableCacheIter = extern struct {
    cur: ?*EcsTableCacheHdr,
    next: ?*EcsTableCacheHdr,
    next_list: ?*EcsTableCacheHdr,
};

pub const EcsTermIter = extern struct {
    term: EcsTerm,
    self_index: ?*EcsIdRecord,
    set_index: ?*EcsIdRecord,
    cur: ?*EcsIdRecord,
    it: EcsTableCacheIter,
    index: i32,
    observed_table_count: i32,
    table: ?*EcsTable,
    cur_match: i32,
    match_count: i32,
    last_column: i32,
    empty_tables: bool,
    id: EcsId,
    column: i32,
    subject: EcsEntity,
    size: EcsSize,
    ptr: ?*anyopaque,
};

pub const EcsIterKind = enum(c_int) {
    ecs_iter_eval_condition,
    ecs_iter_eval_tables,
    ecs_iter_eval_chain,
    ecs_iter_eval_none,
};

pub const EcsFilterIter = extern struct {
    filter: [*c]const EcsFilter,
    kind: EcsIterKind,
    term_iter: EcsTermIter,
    matches_left: i32,
    pivot_term: i32,
};

pub const EcsQuery = opaque {};
pub const EcsQueryTableNode = opaque {};

pub const EcsQueryIter = extern struct {
    query: ?*EcsQuery,
    node: ?*EcsQueryTableNode,
    prev: ?*EcsQueryTableNode,
    last: ?*EcsQueryTableNode,
    sparse_smallest: i32,
    sparse_first: i32,
    bitset_first: i32,
    skip_count: i32,
};

pub const EcsRule = opaque {};
pub const EcsRuleOpCtx = opaque {};

pub const EcsRuleIter = extern struct {
    rule: ?*const EcsRule,
    registers: [*c]EcsVar,
    op_ctx: ?*EcsRuleOpCtx,
    columns: [*c]i32,
    entity: EcsEntity,
    redo: bool,
    op: i32,
    sp: i32,
};

pub const EcsVector = opaque {};

pub const EcsSnapshotIter = extern struct {
    filter: EcsFilter,
    tables: ?*EcsVector,
    index: i32,
};

pub const EcsPageIter = extern struct {
    offset: i32,
    limit: i32,
    remaining: i32,
};

pub const EcsWorkerIter = extern struct {
    index: i32,
    count: i32,
};

// TODO: hunt down what this is actually named or should be named
const union_unnamed_1 = extern union {
    term: EcsTermIter,
    filter: EcsFilterIter,
    query: EcsQueryIter,
    rule: EcsRuleIter,
    snapshot: EcsSnapshotIter,
    page: EcsPageIter,
    worker: EcsWorkerIter,
};

pub const EcsIterCache = extern struct {
    ids: [4]EcsId,
    columns: [4]i32,
    sources: [4]EcsEntity,
    sizes: [4]EcsSize,
    ptrs: [4]?*anyopaque,
    match_indices: [4]i32,
    variables: [4]EcsVar,
    used: EcsFlags8,
    allocated: EcsFlags8,
};

pub const EcsIterPrivate = extern struct {
    iter: union_unnamed_1,
    cache: EcsIterCache,
};

pub const EcsIterNextAction = if (builtin.zig_backend == .stage1) fn ([*c]EcsIter) callconv(.C) bool else *const fn ([*c]EcsIter) callconv(.C) bool;
pub const EcsIterAction = if (builtin.zig_backend == .stage1) fn (*EcsIter) callconv(.C) void else *const fn (*EcsIter) callconv(.C) void;
pub const EcsIterFiniAction = if (builtin.zig_backend == .stage1) fn ([*c]EcsIter) callconv(.C) void else *const fn ([*c]EcsIter) callconv(.C) void;

pub const EcsIter = extern struct {
    world: ?*EcsWorld,
    real_world: ?*EcsWorld,
    entities: [*c]EcsEntity,
    ptrs: [*c]?*anyopaque,
    sizes: [*c]EcsSize,
    table: ?*EcsTable,
    other_table: ?*EcsTable,
    ids: [*c]EcsId,
    variables: [*c]EcsVar,
    columns: [*c]i32,
    sources: [*c]EcsEntity,
    match_indices: [*c]i32,
    references: [*c]EcsRef,
    constrained_vars: EcsFlags64,
    group_id: u64,
    field_count: i32,
    system: EcsEntity,
    event: EcsEntity,
    event_id: EcsId,
    terms: [*c]EcsTerm,
    table_count: i32,
    term_index: i32,
    variable_count: i32,
    variable_names: [*c][*c]u8,
    param: ?*anyopaque,
    ctx: ?*anyopaque,
    binding_ctx: ?*anyopaque,
    delta_time: f32,
    delta_system_time: f32,
    frame_offset: i32,
    offset: i32,
    count: i32,
    instance_count: i32,
    flags: EcsFlags32,
    interrupted_by: EcsEntity,
    priv: EcsIterPrivate,
    next: ?EcsIterNextAction,
    callback: ?EcsIterAction,
    fini: ?EcsIterFiniAction,
    chain_it: [*c]EcsIter,
};

pub const EcsWorld = opaque {};
pub const EcsPoly = anyopaque;

pub const EcsIterInitAction = if (builtin.zig_backend == .stage1) fn (
    ?*const EcsWorld,
    ?*const EcsPoly,
    [*c]EcsIter,
    [*c]EcsTerm,
) callconv(.C) void else *const fn (
    ?*const EcsWorld,
    ?*const EcsPoly,
    [*c]EcsIter,
    [*c]EcsTerm,
) callconv(.C) void;

pub const EcsIterable = extern struct {
    init: ?EcsIterInitAction,
};

pub const EcsFilter = extern struct {
    hdr: EcsHeader,
    terms: [*c]EcsTerm,
    term_count: i32,
    field_count: i32,
    owned: bool,
    terms_owned: bool,
    flags: EcsFlags32,
    name: [*c]u8,
    variable_names: [1][*c]u8,
    iterable: EcsIterable,
};

pub const EcsFilterDesc = extern struct {
    _canary: i32,
    terms: [16]EcsTerm,
    terms_buffer: [*c]EcsTerm,
    terms_buffer_count: i32,
    storage: [*c]EcsFilter,
    instanced: bool,
    flags: EcsFlags32,
    expr: [*c]const u8,
    name: [*c]const u8,
};

pub const EcsOrderByAction = if (builtin.zig_backend == .stage1) fn (
    EcsEntity,
    ?*const anyopaque,
    EcsEntity,
    ?*const anyopaque,
) callconv(.C) c_int else *const fn (
    EcsEntity,
    ?*const anyopaque,
    EcsEntity,
    ?*const anyopaque,
) callconv(.C) c_int;

pub const EcsSortTableAction = if (builtin.zig_backend == .stage1) fn (
    ?*EcsWorld,
    ?*EcsTable,
    [*c]EcsEntity,
    ?*anyopaque,
    i32,
    i32,
    i32,
    EcsOrderByAction,
) callconv(.C) void else *const fn (
    ?*EcsWorld,
    ?*EcsTable,
    [*c]EcsEntity,
    ?*anyopaque,
    i32,
    i32,
    i32,
    EcsOrderByAction,
) callconv(.C) void;

pub const EcsGroupByAction = if (builtin.zig_backend == .stage1) fn (
    ?*EcsWorld,
    ?*EcsTable,
    EcsId,
    ?*anyopaque,
) callconv(.C) u64 else *const fn (
    ?*EcsWorld,
    ?*EcsTable,
    EcsId,
    ?*anyopaque,
) callconv(.C) u64;

pub const EcsCtxFree = if (builtin.zig_backend == .stage1) fn (?*anyopaque) callconv(.C) void else *const fn (?*anyopaque) callconv(.C) void;

pub const EcsQueryDesc = extern struct {
    _canary: i32,
    filter: EcsFilterDesc,
    order_by_component: EcsEntity,
    order_by: EcsOrderByAction,
    sort_table: EcsSortTableAction,
    group_by_id: EcsId,
    group_by: EcsGroupByAction,
    group_by_ctx: ?*anyopaque,
    group_by_ctx_free: ?EcsCtxFree,
    parent: ?*EcsQuery,
    entity: EcsEntity,
};

pub const EcsRunAction = if (builtin.zig_backend == .stage1) fn (*EcsIter) callconv(.C) void else *const fn (*EcsIter) callconv(.C) void;

pub const EcsSystemDesc = extern struct {
    _canary: i32,
    entity: EcsEntity,
    query: EcsQueryDesc,
    run: ?EcsRunAction,
    callback: ?EcsIterAction,
    ctx: ?*anyopaque,
    binding_ctx: ?*anyopaque,
    ctx_free: ?EcsCtxFree,
    binding_ctx_free: ?EcsCtxFree,
    interval: f32,
    rate: i32,
    tick_source: EcsEntity,
    multi_threaded: bool,
    no_staging: bool,
};

pub const EcsTypeInfo = extern struct {
    size: EcsSize,
    alignment: EcsSize,
    hooks: EcsTypeHooks,
    component: EcsEntity,
};

pub const EcsFiniAction = if (builtin.zig_backend == .stage1) fn (
    ?*EcsWorld,
    ?*anyopaque,
) callconv(.C) void else *const fn (
    ?*EcsWorld,
    ?*anyopaque,
) callconv(.C) void;

pub const EcsXtor = if (builtin.zig_backend == .stage1) fn (
    ?*anyopaque,
    i32,
    [*c]const EcsTypeInfo,
) callconv(.C) void else *const fn (
    ?*anyopaque,
    i32,
    [*c]const EcsTypeInfo,
) callconv(.C) void;

pub const EcsCopy = if (builtin.zig_backend == .stage1) fn (
    ?*anyopaque,
    ?*const anyopaque,
    i32,
    [*c]const EcsTypeInfo,
) callconv(.C) void else *const fn (
    ?*anyopaque,
    ?*const anyopaque,
    i32,
    [*c]const EcsTypeInfo,
) callconv(.C) void;

pub const EcsMove = if (builtin.zig_backend == .stage1) fn (
    ?*anyopaque,
    ?*anyopaque,
    i32,
    [*c]const EcsTypeInfo,
) callconv(.C) void else *const fn (
    ?*anyopaque,
    ?*anyopaque,
    i32,
    [*c]const EcsTypeInfo,
) callconv(.C) void;

pub const EcsTypeHooks = extern struct {
    ctor: ?EcsXtor,
    dtor: ?EcsXtor,
    copy: ?EcsCopy,
    move: ?EcsMove,
    copy_ctor: ?EcsCopy,
    move_ctor: ?EcsMove,
    ctor_move_dtor: ?EcsMove,
    move_dtor: ?EcsMove,
    on_add: ?EcsIterAction,
    on_set: ?EcsIterAction,
    on_remove: ?EcsIterAction,
    ctx: ?*anyopaque,
    binding_ctx: ?*anyopaque,
    ctx_free: ?EcsCtxFree,
    binding_ctx_free: ?EcsCtxFree,
};

pub const EcsType = extern struct {
    array: [*c]EcsId,
    count: i32,
};

pub const EcsEventDesc = extern struct {
    event: EcsEntity,
    ids: [*c]const EcsType,
    table: ?*EcsTable,
    other_table: ?*EcsTable,
    offset: i32,
    count: i32,
    param: ?*const anyopaque,
    observable: ?*EcsPoly,
    table_event: bool,
    relationship: EcsEntity,
};

pub const EcsWorldInfo = extern struct {
    last_component_id: EcsEntity,
    last_id: EcsEntity,
    min_id: EcsEntity,
    max_id: EcsEntity,
    delta_time_raw: f32,
    delta_time: f32,
    time_scale: f32,
    target_fps: f32,
    frame_time_total: f32,
    system_time_total: f32,
    merge_time_total: f32,
    world_time_total: f32,
    world_time_total_raw: f32,
    frame_count_total: i32,
    merge_count_total: i32,
    id_create_total: i32,
    id_delete_total: i32,
    table_create_total: i32,
    table_delete_total: i32,
    pipeline_build_count_total: i32,
    systems_ran_frame: i32,
    id_count: i32,
    tag_id_count: i32,
    component_id_count: i32,
    pair_id_count: i32,
    wildcard_id_count: i32,
    table_count: i32,
    tag_table_count: i32,
    trivial_table_count: i32,
    empty_table_count: i32,
    table_record_count: i32,
    table_storage_count: i32,
    new_count: i32,
    bulk_new_count: i32,
    delete_count: i32,
    clear_count: i32,
    add_count: i32,
    remove_count: i32,
    set_count: i32,
    discard_count: i32,
    name_prefix: [*c]const u8,
};

pub const EcsBulkDesc = extern struct {
    _canary: i32,
    entities: [*c]EcsEntity,
    count: i32,
    ids: [32]EcsId,
    data: [*c]?*anyopaque,
    table: ?*EcsTable,
};

pub const EcsComponentDesc = extern struct {
    _canary: i32,
    entity: EcsEntity,
    type: EcsTypeInfo,
};

pub const EcsStrBufElement = extern struct {
    buffer_embedded: bool,
    pos: i32,
    buf: [*c]u8,
    next: [*c]EcsStrBufElement,
};

pub const EcsStrBufElementEmbedded = extern struct {
    super: EcsStrBufElement,
    buf: [512]u8,
};

pub const EcsStrBufListElem = extern struct {
    count: i32,
    separator: [*c]const u8,
};

pub const EcsStrBuf = extern struct {
    buf: [*c]u8,
    max: i32,
    size: i32,
    elementCount: i32,
    firstElement: EcsStrBufElementEmbedded,
    current: [*c]EcsStrBufElement,
    list_stack: [32]EcsStrBufListElem,
    list_sp: i32,
    content: [*c]u8,
    length: i32,
};

pub const EcsObserverDesc = extern struct {
    _canary: i32,
    entity: EcsEntity,
    filter: EcsFilterDesc,
    events: [8]EcsEntity,
    yield_existing: bool,
    callback: EcsIterAction,
    run: EcsRunAction,
    ctx: ?*anyopaque,
    binding_ctx: ?*anyopaque,
    ctx_free: ?EcsCtxFree,
    binding_ctx_free: ?EcsCtxFree,
    observable: ?*EcsPoly,
    last_event_id: [*c]i32,
    term_index: i32,
};

pub const EcsPipelineDesc = extern struct {
    entity: EcsEntity,
    query: EcsQueryDesc,
};

pub const EcsSnapshot = opaque {};

pub const EcsAppInitAction = if (builtin.zig_backend == .stage1) fn (?*EcsWorld) callconv(.C) c_int else *const fn (?*EcsWorld) callconv(.C) c_int;
pub const EcsAppRunAction = if (builtin.zig_backend == .stage1) fn (
    ?*EcsWorld,
    [*c]EcsAppDesc,
) callconv(.C) c_int else *const fn (
    ?*EcsWorld,
    [*c]EcsAppDesc,
) callconv(.C) c_int;

pub const EcsAppFrameAction = if (builtin.zig_backend == .stage1) fn (
    ?*EcsWorld,
    [*c]const EcsAppDesc,
) callconv(.C) c_int else *const fn (
    ?*EcsWorld,
    [*c]const EcsAppDesc,
) callconv(.C) c_int;

pub const EcsAppDesc = extern struct {
    target_fps: f32,
    delta_time: f32,
    threads: i32,
    enable_rest: bool,
    enable_monitor: bool,
    init: ?EcsAppInitAction,
    ctx: ?*anyopaque,
};

pub extern fn ecs_init() ?*EcsWorld;
pub extern fn ecs_mini() ?*EcsWorld;
pub extern fn ecs_init_w_args(argc: c_int, argv: [*c][*c]u8) ?*EcsWorld;
pub extern fn ecs_fini(world: ?*EcsWorld) c_int;
pub extern fn ecs_is_fini(world: ?*const EcsWorld) bool;
pub extern fn ecs_atfini(world: ?*EcsWorld, action: EcsFiniAction, ctx: ?*anyopaque) void;
pub extern fn ecs_run_post_frame(world: ?*EcsWorld, action: EcsFiniAction, ctx: ?*anyopaque) void;
pub extern fn ecs_quit(world: ?*EcsWorld) void;
pub extern fn ecs_should_quit(world: ?*const EcsWorld) bool;
pub extern fn ecs_set_hooks_id(world: ?*EcsWorld, id: EcsEntity, hooks: [*c]const EcsTypeHooks) void;
pub extern fn ecs_get_hooks_id(world: ?*EcsWorld, id: EcsEntity) [*c]const EcsTypeHooks;
pub extern fn ecs_set_context(world: ?*EcsWorld, ctx: ?*anyopaque) void;
pub extern fn ecs_get_context(world: ?*const EcsWorld) ?*anyopaque;
pub extern fn ecs_get_world_info(world: ?*const EcsWorld) [*c]const EcsWorldInfo;
pub extern fn ecs_dim(world: ?*EcsWorld, entity_count: i32) void;
pub extern fn ecs_set_entity_range(world: ?*EcsWorld, id_start: EcsEntity, id_end: EcsEntity) void;
pub extern fn ecs_set_entity_generation(world: ?*EcsWorld, entity_with_generation: EcsEntity) void;
pub extern fn ecs_enable_range_check(world: ?*EcsWorld, enable: bool) bool;
pub extern fn ecs_measure_frame_time(world: ?*EcsWorld, enable: bool) void;
pub extern fn ecs_measure_system_time(world: ?*EcsWorld, enable: bool) void;
pub extern fn ecs_set_target_fps(world: ?*EcsWorld, fps: f32) void;
pub extern fn ecs_run_aperiodic(world: ?*EcsWorld, flags: EcsFlags32) void;
pub extern fn ecs_delete_empty_tables(world: ?*EcsWorld, id: EcsId, clear_generation: u16, delete_generation: u16, min_id_count: i32, time_budget_seconds: f64) i32;
pub extern fn ecs_new_id(world: ?*EcsWorld) EcsEntity;
pub extern fn ecs_new_low_id(world: ?*EcsWorld) EcsEntity;
pub extern fn ecs_new_w_id(world: ?*EcsWorld, id: EcsId) EcsEntity;
pub extern fn ecs_entity_init(world: ?*EcsWorld, desc: [*c]const EcsEntityDesc) EcsEntity;
pub extern fn ecs_bulk_init(world: ?*EcsWorld, desc: [*c]const EcsBulkDesc) [*c]const EcsEntity;
pub extern fn ecs_component_init(world: ?*EcsWorld, desc: [*c]const EcsComponentDesc) EcsEntity;
pub extern fn ecs_bulk_new_w_id(world: ?*EcsWorld, id: EcsId, count: i32) [*c]const EcsEntity;
pub extern fn ecs_clone(world: ?*EcsWorld, dst: EcsEntity, src: EcsEntity, copy_value: bool) EcsEntity;
pub extern fn ecs_add_id(world: ?*EcsWorld, entity: EcsEntity, id: EcsId) void;
pub extern fn ecs_remove_id(world: ?*EcsWorld, entity: EcsEntity, id: EcsId) void;
pub extern fn ecs_override_id(world: ?*EcsWorld, entity: EcsEntity, id: EcsId) void;
pub extern fn ecs_enable_id(world: ?*EcsWorld, entity: EcsEntity, id: EcsId, enable: bool) void;
pub extern fn ecs_is_enabled_id(world: ?*const EcsWorld, entity: EcsEntity, id: EcsId) bool;
pub extern fn ecs_make_pair(first: EcsEntity, second: EcsEntity) EcsId;
pub extern fn ecs_clear(world: ?*EcsWorld, entity: EcsEntity) void;
pub extern fn ecs_delete(world: ?*EcsWorld, entity: EcsEntity) void;
pub extern fn ecs_delete_with(world: ?*EcsWorld, id: EcsId) void;
pub extern fn ecs_remove_all(world: ?*EcsWorld, id: EcsId) void;
pub extern fn ecs_get_id(world: ?*const EcsWorld, entity: EcsEntity, id: EcsId) ?*const anyopaque;
pub extern fn ecs_ref_init_id(world: ?*const EcsWorld, entity: EcsEntity, id: EcsId) EcsRef;
pub extern fn ecs_ref_get_id(world: ?*const EcsWorld, ref: [*c]EcsRef, id: EcsId) ?*anyopaque;
pub extern fn ecs_get_mut_id(world: ?*EcsWorld, entity: EcsEntity, id: EcsId) ?*anyopaque;
pub extern fn ecs_write_begin(world: ?*EcsWorld, entity: EcsEntity) [*c]EcsRecord;
pub extern fn ecs_write_end(record: [*c]EcsRecord) void;
pub extern fn ecs_read_begin(world: ?*EcsWorld, entity: EcsEntity) [*c]const EcsRecord;
pub extern fn ecs_read_end(record: [*c]const EcsRecord) void;
pub extern fn ecs_record_get_id(world: ?*EcsWorld, record: [*c]const EcsRecord, id: EcsId) ?*const anyopaque;
pub extern fn ecs_record_get_mut_id(world: ?*EcsWorld, record: [*c]EcsRecord, id: EcsId) ?*anyopaque;
pub extern fn ecs_emplace_id(world: ?*EcsWorld, entity: EcsEntity, id: EcsId) ?*anyopaque;
pub extern fn ecs_modified_id(world: ?*EcsWorld, entity: EcsEntity, id: EcsId) void;
pub extern fn ecs_set_id(world: ?*EcsWorld, entity: EcsEntity, id: EcsId, size: usize, ptr: ?*const anyopaque) EcsEntity;
pub extern fn ecs_is_valid(world: ?*const EcsWorld, e: EcsEntity) bool;
pub extern fn ecs_is_alive(world: ?*const EcsWorld, e: EcsEntity) bool;
pub extern fn ecs_strip_generation(e: EcsEntity) EcsId;
pub extern fn ecs_get_alive(world: ?*const EcsWorld, e: EcsEntity) EcsEntity;
pub extern fn ecs_ensure(world: ?*EcsWorld, entity: EcsEntity) void;
pub extern fn ecs_ensure_id(world: ?*EcsWorld, id: EcsId) void;
pub extern fn ecs_exists(world: ?*const EcsWorld, entity: EcsEntity) bool;
pub extern fn ecs_get_type(world: ?*const EcsWorld, entity: EcsEntity) [*c]const EcsType;
pub extern fn ecs_get_table(world: ?*const EcsWorld, entity: EcsEntity) ?*EcsTable;
pub extern fn ecs_get_storage_table(world: ?*const EcsWorld, entity: EcsEntity) ?*EcsTable;
pub extern fn ecs_get_type_info(world: ?*const EcsWorld, id: EcsId) [*c]const EcsTypeInfo;
pub extern fn ecs_get_typeid(world: ?*const EcsWorld, id: EcsId) EcsEntity;
pub extern fn ecs_id_is_tag(world: ?*const EcsWorld, id: EcsId) EcsEntity;
pub extern fn ecs_id_in_use(world: ?*EcsWorld, id: EcsId) bool;
pub extern fn ecs_get_name(world: ?*const EcsWorld, entity: EcsEntity) [*c]const u8;
pub extern fn ecs_get_symbol(world: ?*const EcsWorld, entity: EcsEntity) [*c]const u8;
pub extern fn ecs_set_name(world: ?*EcsWorld, entity: EcsEntity, name: [*c]const u8) EcsEntity;
pub extern fn ecs_set_symbol(world: ?*EcsWorld, entity: EcsEntity, symbol: [*c]const u8) EcsEntity;
pub extern fn ecs_set_alias(world: ?*EcsWorld, entity: EcsEntity, alias: [*c]const u8) void;
pub extern fn ecs_id_flag_str(id_flags: EcsId) [*c]const u8;
pub extern fn ecs_id_str(world: ?*const EcsWorld, id: EcsId) [*c]u8;
pub extern fn ecs_id_str_buf(world: ?*const EcsWorld, id: EcsId, buf: [*c]EcsStrBuf) void;
pub extern fn ecs_type_str(world: ?*const EcsWorld, @"type": [*c]const EcsType) [*c]u8;
pub extern fn ecs_table_str(world: ?*const EcsWorld, table: ?*const EcsTable) [*c]u8;
pub extern fn ecs_entity_str(world: ?*const EcsWorld, entity: EcsEntity) [*c]u8;
pub extern fn ecs_has_id(world: ?*const EcsWorld, entity: EcsEntity, id: EcsId) bool;
pub extern fn ecs_get_target(world: ?*const EcsWorld, entity: EcsEntity, rel: EcsEntity, index: i32) EcsEntity;
pub extern fn ecs_get_target_for_id(world: ?*const EcsWorld, entity: EcsEntity, rel: EcsEntity, id: EcsId) EcsEntity;
pub extern fn ecs_enable(world: ?*EcsWorld, entity: EcsEntity, enabled: bool) void;
pub extern fn ecs_count_id(world: ?*const EcsWorld, entity: EcsId) i32;
pub extern fn ecs_lookup(world: ?*const EcsWorld, name: [*c]const u8) EcsEntity;
pub extern fn ecs_lookup_child(world: ?*const EcsWorld, parent: EcsEntity, name: [*c]const u8) EcsEntity;
pub extern fn ecs_lookup_path_w_sep(world: ?*const EcsWorld, parent: EcsEntity, path: [*c]const u8, sep: [*c]const u8, prefix: [*c]const u8, recursive: bool) EcsEntity;
pub extern fn ecs_lookup_symbol(world: ?*const EcsWorld, symbol: [*c]const u8, lookup_as_path: bool) EcsEntity;
pub extern fn ecs_get_path_w_sep(world: ?*const EcsWorld, parent: EcsEntity, child: EcsEntity, sep: [*c]const u8, prefix: [*c]const u8) [*c]u8;
pub extern fn ecs_get_path_w_sep_buf(world: ?*const EcsWorld, parent: EcsEntity, child: EcsEntity, sep: [*c]const u8, prefix: [*c]const u8, buf: [*c]EcsStrBuf) void;
pub extern fn ecs_new_from_path_w_sep(world: ?*EcsWorld, parent: EcsEntity, path: [*c]const u8, sep: [*c]const u8, prefix: [*c]const u8) EcsEntity;
pub extern fn ecs_add_path_w_sep(world: ?*EcsWorld, entity: EcsEntity, parent: EcsEntity, path: [*c]const u8, sep: [*c]const u8, prefix: [*c]const u8) EcsEntity;
pub extern fn ecs_set_scope(world: ?*EcsWorld, scope: EcsEntity) EcsEntity;
pub extern fn ecs_get_scope(world: ?*const EcsWorld) EcsEntity;
pub extern fn ecs_set_with(world: ?*EcsWorld, id: EcsId) EcsEntity;
pub extern fn ecs_get_with(world: ?*const EcsWorld) EcsId;
pub extern fn ecs_set_name_prefix(world: ?*EcsWorld, prefix: [*c]const u8) [*c]const u8;
pub extern fn ecs_set_lookup_path(world: ?*EcsWorld, lookup_path: [*c]const EcsEntity) [*c]EcsEntity;
pub extern fn ecs_get_lookup_path(world: ?*const EcsWorld) [*c]EcsEntity;
pub extern fn ecs_term_iter(world: ?*const EcsWorld, term: [*c]EcsTerm) EcsIter;
pub extern fn ecs_term_chain_iter(it: [*c]const EcsIter, term: [*c]EcsTerm) EcsIter;
pub extern fn ecs_term_next(it: [*c]EcsIter) bool;
pub extern fn ecs_term_id_is_set(id: [*c]const EcsTermId) bool;
pub extern fn ecs_term_is_initialized(term: [*c]const EcsTerm) bool;
pub extern fn ecs_term_match_this(term: [*c]const EcsTerm) bool;
pub extern fn ecs_term_match_0(term: [*c]const EcsTerm) bool;
pub extern fn ecs_term_finalize(world: ?*const EcsWorld, term: [*c]EcsTerm) c_int;
pub extern fn ecs_term_copy(src: [*c]const EcsTerm) EcsTerm;
pub extern fn ecs_term_move(src: [*c]EcsTerm) EcsTerm;
pub extern fn ecs_term_fini(term: [*c]EcsTerm) void;
pub extern fn ecs_id_match(id: EcsId, pattern: EcsId) bool;
pub extern fn ecs_id_is_pair(id: EcsId) bool;
pub extern fn ecs_id_is_wildcard(id: EcsId) bool;
pub extern fn ecs_id_is_valid(world: ?*const EcsWorld, id: EcsId) bool;
pub extern fn ecs_id_get_flags(world: ?*const EcsWorld, id: EcsId) EcsFlags32;
pub extern fn ecs_filter_init(world: ?*const EcsWorld, desc: [*c]const EcsFilterDesc) [*c]EcsFilter;
pub extern fn ecs_filter_fini(filter: [*c]EcsFilter) void;
pub extern fn ecs_filter_finalize(world: ?*const EcsWorld, filter: [*c]EcsFilter) c_int;
pub extern fn ecs_filter_find_this_var(filter: [*c]const EcsFilter) i32;
pub extern fn ecs_term_str(world: ?*const EcsWorld, term: [*c]const EcsTerm) [*c]u8;
pub extern fn ecs_filter_str(world: ?*const EcsWorld, filter: [*c]const EcsFilter) [*c]u8;
pub extern fn ecs_filter_iter(world: ?*const EcsWorld, filter: [*c]const EcsFilter) EcsIter;
pub extern fn ecs_filter_chain_iter(it: [*c]const EcsIter, filter: [*c]const EcsFilter) EcsIter;
pub extern fn ecs_filter_pivot_term(world: ?*const EcsWorld, filter: [*c]const EcsFilter) i32;
pub extern fn ecs_filter_next(it: [*c]EcsIter) bool;
pub extern fn ecs_filter_next_instanced(it: [*c]EcsIter) bool;
pub extern fn ecs_filter_move(dst: [*c]EcsFilter, src: [*c]EcsFilter) void;
pub extern fn ecs_filter_copy(dst: [*c]EcsFilter, src: [*c]const EcsFilter) void;
pub extern fn ecs_query_init(world: ?*EcsWorld, desc: [*c]const EcsQueryDesc) ?*EcsQuery;
pub extern fn ecs_query_fini(query: ?*EcsQuery) void;
pub extern fn ecs_query_get_filter(query: ?*EcsQuery) [*c]const EcsFilter;
pub extern fn ecs_query_iter(world: ?*const EcsWorld, query: ?*EcsQuery) EcsIter;
pub extern fn ecs_query_next(iter: [*c]EcsIter) bool;
pub extern fn ecs_query_next_instanced(iter: [*c]EcsIter) bool;
pub extern fn ecs_query_changed(query: ?*EcsQuery, it: [*c]const EcsIter) bool;
pub extern fn ecs_query_skip(it: [*c]EcsIter) void;
pub extern fn ecs_query_set_group(it: [*c]EcsIter, group_id: u64) void;
pub extern fn ecs_query_orphaned(query: ?*EcsQuery) bool;
pub extern fn ecs_query_str(query: ?*const EcsQuery) [*c]u8;
pub extern fn ecs_query_table_count(query: ?*const EcsQuery) i32;
pub extern fn ecs_query_empty_table_count(query: ?*const EcsQuery) i32;
pub extern fn ecs_query_entity_count(query: ?*const EcsQuery) i32;
pub extern fn ecs_query_entity(query: ?*const EcsQuery) EcsEntity;

pub extern fn ecs_emit(world: ?*EcsWorld, desc: [*c]EcsEventDesc) void;
pub extern fn ecs_observer_init(world: ?*EcsWorld, desc: [*c]const EcsObserverDesc) EcsEntity;
pub extern fn ecs_observer_default_run_action(it: [*c]EcsIter) bool;
pub extern fn ecs_get_observer_ctx(world: ?*const EcsWorld, observer: EcsEntity) ?*anyopaque;
pub extern fn ecs_get_observer_binding_ctx(world: ?*const EcsWorld, observer: EcsEntity) ?*anyopaque;
pub extern fn ecs_iter_poly(world: ?*const EcsWorld, poly: ?*const EcsPoly, iter: [*c]EcsIter, filter: [*c]EcsTerm) void;
pub extern fn ecs_iter_next(it: [*c]EcsIter) bool;
pub extern fn ecs_iter_fini(it: [*c]EcsIter) void;
pub extern fn ecs_iter_count(it: [*c]EcsIter) i32;
pub extern fn ecs_iter_is_true(it: [*c]EcsIter) bool;
pub extern fn ecs_iter_set_var(it: [*c]EcsIter, var_id: i32, entity: EcsEntity) void;
pub extern fn ecs_iter_set_var_as_table(it: [*c]EcsIter, var_id: i32, table: ?*const EcsTable) void;
pub extern fn ecs_iter_set_var_as_range(it: [*c]EcsIter, var_id: i32, range: [*c]const EcsTableRange) void;
pub extern fn ecs_iter_get_var(it: [*c]EcsIter, var_id: i32) EcsEntity;
pub extern fn ecs_iter_get_var_as_table(it: [*c]EcsIter, var_id: i32) ?*EcsTable;
pub extern fn ecs_iter_get_var_as_range(it: [*c]EcsIter, var_id: i32) EcsTableRange;
pub extern fn ecs_iter_var_is_constrained(it: [*c]EcsIter, var_id: i32) bool;
pub extern fn ecs_page_iter(it: [*c]const EcsIter, offset: i32, limit: i32) EcsIter;
pub extern fn ecs_page_next(it: [*c]EcsIter) bool;
pub extern fn ecs_worker_iter(it: [*c]const EcsIter, index: i32, count: i32) EcsIter;
pub extern fn ecs_worker_next(it: [*c]EcsIter) bool;
pub extern fn ecs_field_w_size(it: [*c]const EcsIter, size: usize, index: i32) ?*anyopaque;
pub extern fn ecs_field_is_readonly(it: [*c]const EcsIter, index: i32) bool;
pub extern fn ecs_field_is_writeonly(it: [*c]const EcsIter, index: i32) bool;
pub extern fn ecs_field_is_set(it: [*c]const EcsIter, index: i32) bool;
pub extern fn ecs_field_id(it: [*c]const EcsIter, index: i32) EcsId;
pub extern fn ecs_field_src(it: [*c]const EcsIter, index: i32) EcsEntity;
pub extern fn ecs_field_size(it: [*c]const EcsIter, index: i32) usize;
pub extern fn ecs_field_is_self(it: [*c]const EcsIter, index: i32) bool;
pub extern fn ecs_iter_str(it: [*c]const EcsIter) [*c]u8;
pub extern fn ecs_iter_find_column(it: [*c]const EcsIter, id: EcsId) i32;
pub extern fn ecs_iter_column_w_size(it: [*c]const EcsIter, size: usize, index: i32) ?*anyopaque;
pub extern fn ecs_iter_column_size(it: [*c]const EcsIter, index: i32) usize;
pub extern fn ecs_frame_begin(world: ?*EcsWorld, delta_time: f32) f32;
pub extern fn ecs_frame_end(world: ?*EcsWorld) void;
pub extern fn ecs_readonly_begin(world: ?*EcsWorld) bool;
pub extern fn ecs_readonly_end(world: ?*EcsWorld) void;
pub extern fn ecs_merge(world: ?*EcsWorld) void;
pub extern fn ecs_defer_begin(world: ?*EcsWorld) bool;
pub extern fn ecs_is_deferred(world: ?*const EcsWorld) bool;
pub extern fn ecs_defer_end(world: ?*EcsWorld) bool;
pub extern fn ecs_defer_suspend(world: ?*EcsWorld) void;
pub extern fn ecs_defer_resume(world: ?*EcsWorld) void;
pub extern fn ecs_set_automerge(world: ?*EcsWorld, automerge: bool) void;
pub extern fn ecs_set_stage_count(world: ?*EcsWorld, stages: i32) void;
pub extern fn ecs_get_stage_count(world: ?*const EcsWorld) i32;
pub extern fn ecs_get_stage_id(world: ?*const EcsWorld) i32;
pub extern fn ecs_get_stage(world: ?*const EcsWorld, stage_id: i32) ?*EcsWorld;
pub extern fn ecs_get_world(world: ?*const EcsPoly) ?*const EcsWorld;
pub extern fn ecs_stage_is_readonly(world: ?*const EcsWorld) bool;
pub extern fn ecs_async_stage_new(world: ?*EcsWorld) ?*EcsWorld;
pub extern fn ecs_async_stage_free(stage: ?*EcsWorld) void;
pub extern fn ecs_stage_is_async(stage: ?*EcsWorld) bool;
pub extern fn ecs_search(world: ?*const EcsWorld, table: ?*const EcsTable, id: EcsId, id_out: [*c]EcsId) i32;
pub extern fn ecs_search_offset(world: ?*const EcsWorld, table: ?*const EcsTable, offset: i32, id: EcsId, id_out: [*c]EcsId) i32;
pub extern fn ecs_search_relation(world: ?*const EcsWorld, table: ?*const EcsTable, offset: i32, id: EcsId, rel: EcsEntity, flags: EcsFlags32, subject_out: [*c]EcsEntity, id_out: [*c]EcsId, tr_out: [*c]?*EcsTableRecord) i32;
pub extern fn ecs_table_get_type(table: ?*const EcsTable) [*c]const EcsType;
pub extern fn ecs_table_get_column(table: ?*EcsTable, index: i32) ?*anyopaque;
pub extern fn ecs_table_get_storage_table(table: ?*const EcsTable) ?*EcsTable;
pub extern fn ecs_table_type_to_storage_index(table: ?*const EcsTable, index: i32) i32;
pub extern fn ecs_table_storage_to_type_index(table: ?*const EcsTable, index: i32) i32;
pub extern fn ecs_table_count(table: ?*const EcsTable) i32;
pub extern fn ecs_table_add_id(world: ?*EcsWorld, table: ?*EcsTable, id: EcsId) ?*EcsTable;
pub extern fn ecs_table_remove_id(world: ?*EcsWorld, table: ?*EcsTable, id: EcsId) ?*EcsTable;
pub extern fn ecs_table_lock(world: ?*EcsWorld, table: ?*EcsTable) void;
pub extern fn ecs_table_unlock(world: ?*EcsWorld, table: ?*EcsTable) void;
pub extern fn ecs_table_has_module(table: ?*EcsTable) bool;
pub extern fn ecs_table_swap_rows(world: ?*EcsWorld, table: ?*EcsTable, row_1: i32, row_2: i32) void;
pub extern fn ecs_commit(world: ?*EcsWorld, entity: EcsEntity, record: [*c]EcsRecord, table: ?*EcsTable, added: [*c]const EcsType, removed: [*c]const EcsType) bool;
pub extern fn ecs_record_find(world: ?*const EcsWorld, entity: EcsEntity) [*c]EcsRecord;
pub extern fn ecs_record_get_column(r: [*c]const EcsRecord, column: i32, c_size: usize) ?*anyopaque;
pub extern fn ecs_should_log(level: i32) bool;
pub extern fn ecs_strerror(error_code: i32) [*c]const u8;
pub extern fn ecs_log_set_level(level: c_int) c_int;
pub extern fn ecs_log_enable_colors(enabled: bool) bool;
pub extern fn ecs_log_enable_timestamp(enabled: bool) bool;
pub extern fn ecs_log_enable_timedelta(enabled: bool) bool;
pub extern fn ecs_log_last_error() c_int;

pub extern fn ecs_app_run(world: ?*EcsWorld, desc: [*c]EcsAppDesc) c_int;
pub extern fn ecs_app_run_frame(world: ?*EcsWorld, desc: [*c]const EcsAppDesc) c_int;
pub extern fn ecs_app_set_run_action(callback: EcsAppRunAction) c_int;
pub extern fn ecs_app_set_frame_action(callback: EcsAppFrameAction) c_int;

pub extern fn ecs_set_timeout(world: ?*EcsWorld, tick_source: EcsEntity, timeout: f32) EcsEntity;
pub extern fn ecs_get_timeout(world: ?*const EcsWorld, tick_source: EcsEntity) f32;
pub extern fn ecs_set_interval(world: ?*EcsWorld, tick_source: EcsEntity, interval: f32) EcsEntity;
pub extern fn ecs_get_interval(world: ?*const EcsWorld, tick_source: EcsEntity) f32;
pub extern fn ecs_start_timer(world: ?*EcsWorld, tick_source: EcsEntity) void;
pub extern fn ecs_stop_timer(world: ?*EcsWorld, tick_source: EcsEntity) void;
pub extern fn ecs_set_rate(world: ?*EcsWorld, tick_source: EcsEntity, rate: i32, source: EcsEntity) EcsEntity;
pub extern fn ecs_set_tick_source(world: ?*EcsWorld, system: EcsEntity, tick_source: EcsEntity) void;

pub extern fn ecs_pipeline_init(world: ?*EcsWorld, desc: [*c]const EcsPipelineDesc) EcsEntity;
pub extern fn ecs_set_pipeline(world: ?*EcsWorld, pipeline: EcsEntity) void;
pub extern fn ecs_get_pipeline(world: ?*const EcsWorld) EcsEntity;
pub extern fn ecs_progress(world: ?*EcsWorld, delta_time: f32) bool;
pub extern fn ecs_set_time_scale(world: ?*EcsWorld, scale: f32) void;
pub extern fn ecs_reset_clock(world: ?*EcsWorld) void;
pub extern fn ecs_run_pipeline(world: ?*EcsWorld, pipeline: EcsEntity, delta_time: f32) void;
pub extern fn ecs_set_threads(world: ?*EcsWorld, threads: i32) void;

pub extern fn ecs_system_init(world: ?*EcsWorld, desc: [*c]const EcsSystemDesc) EcsEntity;
pub extern fn ecs_run(world: ?*EcsWorld, system: EcsEntity, delta_time: f32, param: ?*anyopaque) EcsEntity;
pub extern fn ecs_run_worker(world: ?*EcsWorld, system: EcsEntity, stage_current: i32, stage_count: i32, delta_time: f32, param: ?*anyopaque) EcsEntity;
pub extern fn ecs_run_w_filter(world: ?*EcsWorld, system: EcsEntity, delta_time: f32, offset: i32, limit: i32, param: ?*anyopaque) EcsEntity;
pub extern fn ecs_system_get_query(world: ?*const EcsWorld, system: EcsEntity) ?*EcsQuery;
pub extern fn ecs_get_system_ctx(world: ?*const EcsWorld, system: EcsEntity) ?*anyopaque;
pub extern fn ecs_get_system_binding_ctx(world: ?*const EcsWorld, system: EcsEntity) ?*anyopaque;

// pub extern fn ecs_parse_json(world: ?*const EcsWorld, ptr: [*c]const u8, @"type": EcsEntity, data_out: ?*anyopaque, desc: [*c]const ecs_parse_json_desc_t) [*c]const u8;
// pub extern fn ecs_array_to_json(world: ?*const EcsWorld, @"type": EcsEntity, data: ?*const anyopaque, count: i32) [*c]u8;
// pub extern fn ecs_array_to_json_buf(world: ?*const EcsWorld, @"type": EcsEntity, data: ?*const anyopaque, count: i32, buf_out: [*c]EcsStrBuf) c_int;
// pub extern fn ecs_ptr_to_json(world: ?*const EcsWorld, @"type": EcsEntity, data: ?*const anyopaque) [*c]u8;
// pub extern fn ecs_ptr_to_json_buf(world: ?*const EcsWorld, @"type": EcsEntity, data: ?*const anyopaque, buf_out: [*c]EcsStrBuf) c_int;
// pub extern fn ecs_type_info_to_json(world: ?*const EcsWorld, @"type": EcsEntity) [*c]u8;
// pub extern fn ecs_type_info_to_json_buf(world: ?*const EcsWorld, @"type": EcsEntity, buf_out: [*c]EcsStrBuf) c_int;

// pub extern fn EcsEntityo_json(world: ?*const EcsWorld, entity: EcsEntity, desc: [*c]const EcsEntityo_json_desc_t) [*c]u8;
// pub extern fn EcsEntityo_json_buf(world: ?*const EcsWorld, entity: EcsEntity, buf_out: [*c]EcsStrBuf, desc: [*c]const EcsEntityo_json_desc_t) c_int;

// pub extern fn ecs_iter_to_json(world: ?*const EcsWorld, iter: [*c]EcsIter, desc: [*c]const ecs_iter_to_json_desc_t) [*c]u8;
// pub extern fn ecs_iter_to_json_buf(world: ?*const EcsWorld, iter: [*c]EcsIter, buf_out: [*c]EcsStrBuf, desc: [*c]const ecs_iter_to_json_desc_t) c_int;

pub extern fn ecs_snapshot_take(world: ?*EcsWorld) ?*EcsSnapshot;
pub extern fn ecs_snapshot_take_w_iter(iter: [*c]EcsIter) ?*EcsSnapshot;
pub extern fn ecs_snapshot_restore(world: ?*EcsWorld, snapshot: ?*EcsSnapshot) void;
pub extern fn ecs_snapshot_iter(snapshot: ?*EcsSnapshot) EcsIter;
pub extern fn ecs_snapshot_next(iter: [*c]EcsIter) bool;
pub extern fn ecs_snapshot_free(snapshot: ?*EcsSnapshot) void;
pub extern fn ecs_parse_whitespace(ptr: [*c]const u8) [*c]const u8;
pub extern fn ecs_parse_eol_and_whitespace(ptr: [*c]const u8) [*c]const u8;
pub extern fn ecs_parse_digit(ptr: [*c]const u8, token: [*c]u8) [*c]const u8;
pub extern fn ecs_parse_fluff(ptr: [*c]const u8, last_comment: [*c][*c]u8) [*c]const u8;
pub extern fn ecs_parse_token(name: [*c]const u8, expr: [*c]const u8, ptr: [*c]const u8, token_out: [*c]u8) [*c]const u8;
pub extern fn ecs_parse_term(world: ?*const EcsWorld, name: [*c]const u8, expr: [*c]const u8, ptr: [*c]const u8, term_out: [*c]EcsTerm) [*c]u8;

pub const Constants = struct {
    pub extern const ECS_PAIR: EcsId;
    pub extern const ECS_OVERRIDE: EcsId;
    pub extern const ECS_TOGGLE: EcsId;
    pub extern const ECS_AND: EcsId;
    pub extern const ECS_OR: EcsId;
    pub extern const ECS_NOT: EcsId;

    pub extern const EcsQuery: EcsEntity;
    pub extern const EcsObserver: EcsEntity;
    pub extern const EcsSystem: EcsEntity;
    pub extern const EcsFlecs: EcsEntity;
    pub extern const EcsFlecsCore: EcsEntity;
    pub extern const EcsWorld: EcsEntity;
    pub extern const EcsWildcard: EcsEntity;
    pub extern const EcsAny: EcsEntity;
    pub extern const EcsThis: EcsEntity;
    pub extern const EcsVariable: EcsEntity;
    pub extern const EcsTransitive: EcsEntity;
    pub extern const EcsReflexive: EcsEntity;
    pub extern const EcsFinal: EcsEntity;
    pub extern const EcsDontInherit: EcsEntity;
    pub extern const EcsSymmetric: EcsEntity;
    pub extern const EcsExclusive: EcsEntity;
    pub extern const EcsAcyclic: EcsEntity;
    pub extern const EcsWith: EcsEntity;
    pub extern const EcsOneOf: EcsEntity;
    pub extern const EcsTag: EcsEntity;
    pub extern const EcsUnion: EcsEntity;
    pub extern const EcsName: EcsEntity;
    pub extern const EcsSymbol: EcsEntity;
    pub extern const EcsAlias: EcsEntity;
    pub extern const EcsChildOf: EcsEntity;
    pub extern const EcsIsA: EcsEntity;
    pub extern const EcsDependsOn: EcsEntity;
    pub extern const EcsSlotOf: EcsEntity;
    pub extern const EcsModule: EcsEntity;
    pub extern const EcsPrivate: EcsEntity;
    pub extern const EcsPrefab: EcsEntity;
    pub extern const EcsDisabled: EcsEntity;
    pub extern const EcsOnAdd: EcsEntity;
    pub extern const EcsOnRemove: EcsEntity;
    pub extern const EcsOnSet: EcsEntity;
    pub extern const EcsUnSet: EcsEntity;
    pub extern const EcsMonitor: EcsEntity;
    pub extern const EcsOnDelete: EcsEntity;
    pub extern const EcsOnTableEmpty: EcsEntity;
    pub extern const EcsOnTableFill: EcsEntity;
    pub extern const EcsOnDeleteTarget: EcsEntity;
    pub extern const EcsRemove: EcsEntity;
    pub extern const EcsDelete: EcsEntity;
    pub extern const EcsPanic: EcsEntity;
    pub extern const EcsDefaultChildComponent: EcsEntity;
    pub extern const EcsEmpty: EcsEntity;
    pub extern const EcsPreFrame: EcsEntity;
    pub extern const EcsOnLoad: EcsEntity;
    pub extern const EcsPostLoad: EcsEntity;
    pub extern const EcsPreUpdate: EcsEntity;
    pub extern const EcsOnUpdate: EcsEntity;
    pub extern const EcsOnValidate: EcsEntity;
    pub extern const EcsPostUpdate: EcsEntity;
    pub extern const EcsPreStore: EcsEntity;
    pub extern const EcsOnStore: EcsEntity;
    pub extern const EcsPostFrame: EcsEntity;
    pub extern const EcsPhase: EcsEntity;
};
