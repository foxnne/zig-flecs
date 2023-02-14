const std = @import("std");
const c = @import("c.zig");

// Import wrapper function
pub usingnamespace c;

/// Returns the base type of the given type, useful for pointers.
pub fn BaseType(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Pointer => |info| switch (info.size) {
            .One => if (validComponentType(info.child)) return info.child,
            else => {},
        },
        .Optional => |opt_info| switch (@typeInfo(opt_info.child)) {
            .Pointer => |info| switch (info.size) {
                .One => if (validComponentType(info.child)) return info.child,
                else => {},
            },
            else => {},
        },
        .Enum, .Struct, .Union => return T,
        else => {},
    }
    @compileError("Expected pointer or optional pointer to container type, found '" ++ @typeName(T) ++ "'");
}

inline fn validComponentType(comptime T: type) bool {
    return comptime switch (@typeInfo(T)) {
        .Enum, .Struct, .Union => true,
        else => false,
    };
}

/// Casts the anyopaque pointer to a const pointer of the given type.
pub fn ecs_cast(comptime T: type, val: ?*const anyopaque) *const T {
    return @ptrCast(*const T, @alignCast(@alignOf(T), val));
}

/// Casts the anyopaque pointer to a pointer of the given type.
pub fn ecs_cast_mut(comptime T: type, val: ?*anyopaque) *T {
    return @ptrCast(*T, @alignCast(@alignOf(T), val));
}

fn IdHandle(comptime T: type) type {
    comptime std.debug.assert(validComponentType(T));
    return struct {
        var handle: c.EcsId = 0;
    };
}

/// Returns a pointer to the EcsId of the given type.
pub inline fn ecs_id_handle(comptime T: type) *c.EcsId {
    return comptime &IdHandle(T).handle;
}

/// Returns the id assigned to the given type.
pub inline fn ecs_id(comptime T: type) c.EcsId {
    return ecs_id_handle(T).*;
}

/// Returns the full id of the first element of the pair.
pub fn ecs_pair_first(pair: c.EcsId) c.EcsId {
    return @intCast(c.EcsId, @truncate(u32, (pair & c.Constants.ECS_COMPONENT_MASK) >> 32));
}

/// returns the full id of the second element of the pair.
pub fn ecs_pair_second(pair: c.EcsId) c.EcsId {
    return @intCast(c.EcsId, @truncate(u32, pair));
}

/// Returns an EcsId for the given pair.
///
/// first = EcsEntity or type
/// second = EcsEntity or type
pub fn ecs_pair(first: anytype, second: anytype) c.EcsId {
    const First = @TypeOf(first);
    const Second = @TypeOf(second);

    const first_type_info = @typeInfo(First);
    const second_type_info = @typeInfo(Second);

    comptime std.debug.assert(First == c.EcsEntity or First == type or first_type_info == .Enum);
    comptime std.debug.assert(Second == c.EcsEntity or Second == type or second_type_info == .Enum);

    const first_id = if (First == c.EcsEntity) first else if (first_type_info == .Enum) ecs_id(First) else ecs_id(first);
    const second_id = if (Second == c.EcsEntity) second else if (second_type_info == .Enum) ecs_id(Second) else ecs_id(second);
    return c.ecs_make_pair(first_id, second_id);
}

/// Registers the given type as a new component.
pub fn ecs_component(world: *c.EcsWorld, comptime T: type) void {
    const handle = ecs_id_handle(T);

    const entity_desc = std.mem.zeroInit(c.EcsEntityDesc, .{
        .name = @typeName(T),
        .id = handle.*,
        .use_low_id = true,
    });

    const component_desc = std.mem.zeroInit(c.EcsComponentDesc, .{
        .entity = c.ecs_entity_init(world, &entity_desc),
        .type = .{
            .alignment = @alignOf(T),
            .size = @sizeOf(T),
        },
    });

    handle.* = c.ecs_component_init(world, &component_desc);
}

/// Registers a new system with the world run during the given phase.
pub fn ecs_system(world: *c.EcsWorld, name: [*:0]const u8, phase: c.EcsEntity, desc: *c.EcsSystemDesc) void {
    var entity_desc = std.mem.zeroes(c.EcsEntityDesc);
    entity_desc.id = c.ecs_new_id(world);
    entity_desc.name = name;
    entity_desc.add[0] = ecs_dependson(phase);
    entity_desc.add[1] = phase;
    desc.entity = c.ecs_entity_init(world, &entity_desc);
    _ = c.ecs_system_init(world, desc);
}

/// Registers a new observer with the world.
pub fn ecs_observer(world: *c.EcsWorld, name: [*:0]const u8, desc: *c.EcsObserverDesc) void {
    var entity_desc = std.mem.zeroes(c.EcsEntityDesc);
    entity_desc.id = c.ecs_new_id(world);
    entity_desc.name = name;
    desc.entity = c.ecs_entity_init(world, &entity_desc);
    _ = c.ecs_observer_init(world, desc);
}

// - New

/// Returns a new entity with the given component. Pass null if no component is desired.
pub fn ecs_new(world: *c.EcsWorld, comptime T: ?type) c.EcsEntity {
    if (T) |Type| {
        return c.ecs_new_w_id(world, ecs_id(Type));
    }

    return c.ecs_new_id(world);
}

/// Returns a new entity with the given pair.
///
/// first = EcsEntity or type
/// second = EcsEntity or type
pub fn ecs_new_w_pair(world: *c.EcsWorld, first: anytype, second: anytype) c.EcsEntity {
    return c.ecs_new_w_id(world, ecs_pair(first, second));
}

/// Creates count entities in bulk with the given component, returning an array of those entities.
/// Pass null for the component if none is desired.
pub fn ecs_bulk_new(world: *c.EcsWorld, comptime Component: ?type, count: i32) []const c.EcsEntity {
    if (Component) |T| {
        return c.ecs_bulk_new_w_id(world, ecs_id(T), count)[0..@intCast(usize, count)];
    }

    return c.ecs_bulk_new_w_id(world, 0, count)[0..@intCast(usize, count)];
}

/// Returns a new entity with the given name.
pub fn ecs_new_entity(world: *c.EcsWorld, name: [*:0]const u8) c.EcsEntity {
    const desc = std.mem.zeroInit(c.EcsEntityDesc, .{ .name = name });
    return c.ecs_entity_init(world, &desc);
}

/// Returns a new prefab with the given name.
pub fn ecs_new_prefab(world: *c.EcsWorld, name: [*:0]const u8) c.EcsEntity {
    var desc = std.mem.zeroInit(c.EcsEntityDesc, .{ .name = name });
    desc.add[0] = c.Constants.EcsPrefab;
    return c.ecs_entity_init(world, &desc);
}

// - Add

/// Adds a component to the entity. If the type is a non-zero struct, the values may be undefined!
pub fn ecs_add(world: *c.EcsWorld, entity: c.EcsEntity, t: anytype) void {
    const T = @TypeOf(t);
    if (T == type) {
        c.ecs_add_id(world, entity, ecs_id(t));
    } else {
        _ = c.ecs_set_id(world, entity, ecs_id(T), @sizeOf(T), &t);
    }
}

/// Adds the pair to the entity.
///
/// first = EcsEntity or type
/// second = EcsEntity or type
pub fn ecs_add_pair(world: *c.EcsWorld, entity: c.EcsEntity, first: anytype, second: anytype) void {
    const First = @TypeOf(first);

    if (@typeInfo(First) == .Enum) {
        _ = c.ecs_set_id(world, entity, ecs_pair(first, second), @sizeOf(First), &first);
    } else c.ecs_add_id(world, entity, ecs_pair(first, second));
}

// - Remove

/// Removes the component or entity from the entity.
///
/// t = EcsEntity or Type
pub fn ecs_remove(world: *c.EcsWorld, entity: c.EcsEntity, t: anytype) void {
    const T = @TypeOf(t);

    const id = if (T == c.EcsEntity) t else ecs_id(T);
    c.ecs_remove_id(world, entity, id);
}

/// Removes the pair from the entity.
///
/// first = EcsEntity or type
/// second = EcsEntity or type
pub fn ecs_remove_pair(world: *c.EcsWorld, entity: c.EcsEntity, first: anytype, second: anytype) void {
    c.ecs_remove_id(world, entity, ecs_pair(first, second));
}

// - Override

/// Overrides the component on the entity.
pub fn ecs_override(world: *c.EcsWorld, entity: c.EcsEntity, comptime T: type) void {
    c.ecs_override_id(world, entity, ecs_id(T));
}

/// Overrides the pair on the entity.
///
/// first = EcsEntity or type
/// second = EcsEntity or type
pub fn ecs_override_pair(world: *c.EcsWorld, entity: c.EcsEntity, first: anytype, second: anytype) void {
    c.ecs_override_id(world, entity, ecs_pair(first, second));
}

// Bulk remove/delete

/// Deletes all children from parent entity.
pub fn ecs_delete_children(world: *c.EcsWorld, parent: c.EcsEntity) void {
    c.ecs_delete_with(world, ecs_pair(c.Constants.EcsChildOf, parent));
}

// - Set

/// Sets the component on the entity. If the component is not already added, it will automatically be added and set.
pub fn ecs_set(world: *c.EcsWorld, entity: c.EcsEntity, t: anytype) void {
    const T = BaseType(@TypeOf(t));
    comptime std.debug.assert(@typeInfo(@TypeOf(t)) == .Pointer or @TypeOf(t) == T);
    const ptr = if (@typeInfo(@TypeOf(t)) == .Pointer) t else &t;
    _ = c.ecs_set_id(world, entity, ecs_id(T), @sizeOf(T), ptr);
}

/// Sets the component on the first element of the pair. If the component is not already added, it will automatically be added and set.
///
/// first = pointer or struct
/// second = type or EcsEntity
pub fn ecs_set_pair(world: *c.EcsWorld, entity: c.EcsEntity, first: anytype, second: anytype) void {
    const First = @TypeOf(first);
    const FirstT = BaseType(First);

    comptime std.debug.assert(@typeInfo(First) == .Pointer or First == FirstT);
    comptime std.debug.assert(@sizeOf(FirstT) > 0);

    const pair_id = ecs_pair(FirstT, second);
    const ptr = if (@typeInfo(First) == .Pointer) first else &first;

    _ = c.ecs_set_id(world, entity, pair_id, @sizeOf(FirstT), ptr);
}

/// Sets the component on the second element of the pair. If the component is not already added, it will automatically be added and set.
///
/// first = type or EcsEntity
/// second = pointer or struct
pub fn ecs_set_pair_second(world: *c.EcsWorld, entity: c.EcsEntity, first: anytype, second: anytype) void {
    const Second = @TypeOf(second);
    const SecondT = BaseType(Second);

    comptime std.debug.assert(@typeInfo(Second) == .Pointer or Second == SecondT);
    comptime std.debug.assert(@sizeOf(SecondT) > 0);

    const pair_id = ecs_pair(first, SecondT);
    const ptr = if (@typeInfo(Second) == .Pointer) second else &second;

    if (@TypeOf(first) == type and @sizeOf(first) > 0) {
        @compileError("Cannot set second element of a pair when the first element is a component (" ++ @typeName(first) ++ ")");
    }

    _ = c.ecs_set_id(world, entity, pair_id, @sizeOf(SecondT), ptr);
}

// - Get

/// Gets an optional const pointer to the given component type on the entity.
pub fn ecs_get(world: *c.EcsWorld, entity: c.EcsEntity, comptime T: type) ?*const T {
    if (c.ecs_get_id(world, entity, ecs_id(T))) |ptr| {
        return ecs_cast(T, ptr);
    }
    return null;
}

/// Gets an optional pointer to the given component type on the entity.
pub fn ecs_get_mut(world: *c.EcsWorld, entity: c.EcsEntity, comptime T: type) ?*T {
    if (c.ecs_get_mut_id(world, entity, ecs_id(T))) |ptr| {
        return ecs_cast_mut(T, ptr);
    }
    return null;
}

/// Gets an optional pointer to the first element of the pair.
///
/// First = type
/// second = type or entity
pub fn ecs_get_pair(world: *c.EcsWorld, entity: c.EcsEntity, comptime First: type, second: anytype) ?*const First {
    comptime std.debug.assert(validComponentType(First) and @sizeOf(First) > 0);

    const Second = @TypeOf(second);
    comptime std.debug.assert(Second == c.EcsEntity or Second == type);

    if (c.ecs_get_id(world, entity, ecs_pair(First, second))) |ptr| {
        return ecs_cast(First, ptr);
    }
    return null;
}

/// Gets an optional pointer to the second element of the pair.
///
/// first = type or entity
/// Second = type
pub fn ecs_get_pair_second(world: *c.EcsWorld, entity: c.EcsEntity, first: anytype, comptime Second: type) ?*const Second {
    comptime std.debug.assert(validComponentType(Second) and @sizeOf(Second) > 0);

    const First = @TypeOf(first);
    comptime std.debug.assert(First == c.EcsEntity or First == type);

    if (c.ecs_get_id(world, entity, ecs_pair(first, Second))) |ptr| {
        return ecs_cast(Second, ptr);
    }
    return null;
}

// - Iterators

/// Returns an optional slice for the type given the field location.
/// Use the entity's index from the iterator to access component.
pub fn ecs_field(it: *c.EcsIter, comptime T: type, index: usize) ?[]T {
    if (c.ecs_field_w_size(it, @sizeOf(T), @intCast(i32, index))) |ptr| {
        const c_ptr = @ptrCast([*]T, @alignCast(@alignOf(T), ptr));
        return c_ptr[0..@intCast(usize, it.count)];
    }
    return null;
}

// - Utilities for commonly used operations

/// Returns a pair id for isa e.
pub fn ecs_isa(e: anytype) c.EcsId {
    return ecs_pair(c.Constants.EcsIsA, e);
}

/// Returns a pair id for child of e.
pub fn ecs_childof(e: anytype) c.EcsId {
    return ecs_pair(c.Constants.EcsChildOf, e);
}

/// Returns a pair id for depends on e.
pub fn ecs_dependson(e: anytype) c.EcsId {
    return ecs_pair(c.Constants.EcsDependsOn, e);
}
