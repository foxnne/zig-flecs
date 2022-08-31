const std = @import("std");
const c = @import("c.zig");

// Import wrapper function
pub usingnamespace c;

/// Returns the base type of the given type, useful for pointers.
pub fn BaseType(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Pointer => |info| switch (info.size) {
            .One => switch (@typeInfo(info.child)) {
                .Struct => return info.child,
                .Optional => |opt_info| return opt_info.child,
                else => {},
            },
            else => {},
        },
        .Optional => |info| return BaseType(info.child),
        .Struct => return T,
        else => {},
    }
    @compileError("Expected pointer or optional pointer, found '" ++ @typeName(T) ++ "'");
}

/// Casts the anyopaque pointer to a const pointer of the given type.
pub fn ecs_cast(comptime T: type, val: ?*const anyopaque) *const T {
    return @ptrCast(*const T, @alignCast(@alignOf(T), val));
}

/// Casts the anyopaque pointer to a pointer of the given type.
pub fn ecs_cast_mut(comptime T: type, val: ?*anyopaque) *T {
    return @ptrCast(*T, @alignCast(@alignOf(T), val));
}

/// Returns a pointer to the EcsId of the given type.
pub fn ecs_id_handle(comptime T: type) *c.EcsId {
    _ = T;
    return &(struct {
        pub var handle: c.EcsId = std.math.maxInt(c.EcsId);
    }.handle);
}

/// Returns the id assigned to the given type.
pub fn ecs_id(comptime T: type) c.EcsId {
    return ecs_id_handle(T).*;
}

/// Returns the full id of the first element of the pair.
pub fn ecs_pair_first (pair: c.EcsId) c.EcsId {
    return @intCast(c.EcsId, @truncate(u32, (pair & c.Constants.ECS_COMPONENT_MASK) >> 32));
}

/// returns the full id of the second element of the pair.
pub fn ecs_pair_second (pair: c.EcsId) c.EcsId {
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

    std.debug.assert(First == c.EcsEntity or first_type_info == .Type);
    std.debug.assert(Second == c.EcsEntity or second_type_info == .Type);

    const first_id = if (First == c.EcsEntity) first else ecs_id(first);
    const second_id = if (Second == c.EcsEntity) second else ecs_id(second);
    return c.ecs_make_pair(first_id, second_id);
}

/// Registers the given type as a new component.
pub fn ecs_component(world: *c.EcsWorld, comptime T: type) void {
    std.debug.assert(@typeInfo(T) == .Struct or @typeInfo(T) == .Type);

    var handle = ecs_id_handle(T);
    if (handle.* < std.math.maxInt(c.EcsId)) return;

    if (@sizeOf(T) == 0) {
        var desc = std.mem.zeroInit(c.EcsEntityDesc, .{ .name = @typeName(T) });
        handle.* = c.ecs_entity_init(world, &desc);
    } else {
        var entity_desc = std.mem.zeroInit(c.EcsEntityDesc, .{ .name = @typeName(T)});
        var component_desc = std.mem.zeroInit(c.EcsComponentDesc, .{.entity = c.ecs_entity_init(world, &entity_desc)});
        component_desc.type.alignment = @alignOf(T);
        component_desc.type.size = @sizeOf(T);
        handle.* = c.ecs_component_init(world, &component_desc);
    }
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

// - New

/// Returns a new entity with the given component. Pass null if no component is desired.
pub fn ecs_new(world: *c.EcsWorld, comptime T: ?type) c.EcsEntity {
    if (T) |Type| {
        std.debug.assert(@typeInfo(Type) == .Struct or @typeInfo(Type) == .Type);
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
        std.debug.assert(@typeInfo(T) == .Struct or @typeInfo(T) == .Type);
        return c.ecs_bulk_new_w_id(world, ecs_id(T), count)[0..@intCast(usize, count)];
    }

    return c.ecs_bulk_new_w_id(world, 0, count)[0..@intCast(usize, count)];
}

/// Returns a new entity with the given name.
pub fn ecs_new_entity(world: *c.EcsWorld, name: [*:0]const u8) c.EcsEntity {
    const desc = std.mem.zeroInit(c.EcsEntityDesc, .{ .name = name, .id = c.ecs_new_id(world) });
    return c.ecs_entity_init(world, &desc);
}

// - Add

/// Adds a component to the entity. If the type is a non-zero struct, the values may be undefined!
pub fn ecs_add(world: *c.EcsWorld, entity: c.EcsEntity, comptime T: type) void {
    std.debug.assert(@typeInfo(T) == .Struct or @typeInfo(T) == .Type);
    c.ecs_add_id(world, entity, ecs_id(T));
}

/// Adds the pair to the entity.
///
/// first = EcsEntity or type
/// second = EcsEntity or type
pub fn ecs_add_pair(world: *c.EcsWorld, entity: c.EcsEntity, first: anytype, second: anytype) void {
    c.ecs_add_id(world, entity, ecs_pair(first, second));
}

// - Remove

/// Removes the component or entity from the entity.
///
/// t = EcsEntity or Type
pub fn ecs_remove(world: *c.EcsWorld, entity: c.EcsEntity, t: anytype) void {
    const T = @TypeOf(t);
    const type_info = @typeInfo(T);

    std.debug.assert(T == c.EcsEntity or type_info == .Type);

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
    std.debug.assert(@typeInfo(T) == .Struct or @typeInfo(T) == .Type);
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
    std.debug.assert(@typeInfo(@TypeOf(t)) == .Pointer or @typeInfo(@TypeOf(t)) == .Struct);
    const T = BaseType(@TypeOf(t));
    const ptr = if (@typeInfo(@TypeOf(t)) == .Pointer) t else &t;
    _ = c.ecs_set_id(world, entity, ecs_id(T), @sizeOf(T), ptr);
}

/// Sets the component on the first element of the pair. If the component is not already added, it will automatically be added and set.
///
/// first = pointer or struct
/// second = type or EcsEntity
pub fn ecs_set_pair(world: *c.EcsWorld, entity: c.EcsEntity, first: anytype, second: anytype) void {
    const First = @TypeOf(first);
    const first_type_info = @typeInfo(First);
    const FirstT = BaseType(First);

    std.debug.assert(first_type_info == .Pointer or first_type_info == .Struct);

    const pair_id = ecs_pair(FirstT, second);
    const ptr = if (first_type_info == .Pointer) first else &first;

    _ = c.ecs_set_id(world, entity, pair_id, @sizeOf(FirstT), ptr);
}

/// Sets the component on the second element of the pair. If the component is not already added, it will automatically be added and set.
///
/// first = type or EcsEntity
/// second = pointer or struct
pub fn ecs_set_pair_second(world: *c.EcsWorld, entity: c.EcsEntity, first: anytype, second: anytype) void {
    const Second = @TypeOf(second);
    const second_type_info = @typeInfo(Second);
    const SecondT = BaseType(Second);

    std.debug.assert(second_type_info == .Pointer or second_type_info == .Struct);

    const pair_id = ecs_pair(first, SecondT);
    const ptr = if (second_type_info == .Pointer) second else &second;

    const First = @TypeOf(first);
    const first_type_info = @typeInfo(First);
    if (first_type_info == .Type and @sizeOf(First) > 0) {
        std.log.warn("[{s}] ecs_set_pair_second: Both types are components, attached data will assume the type of {s}.", .{ @typeName(First)});
    }

    _ = c.ecs_set_id(world, entity, pair_id, @sizeOf(SecondT), ptr);
}

// - Get

/// Gets an optional const pointer to the given component type on the entity.
pub fn ecs_get(world: *c.EcsWorld, entity: c.EcsEntity, comptime T: type) ?*const T {
    std.debug.assert(@typeInfo(T) == .Struct or @typeInfo(T) == .Type);
    if (c.ecs_get_id(world, entity, ecs_id(T))) |ptr| {
        return ecs_cast(T, ptr);
    }
    return null;
}

/// Gets an optional pointer to the given component type on the entity.
pub fn ecs_get_mut(world: *c.EcsWorld, entity: c.EcsEntity, comptime T: type) ?*T {
    std.debug.assert(@typeInfo(T) == .Struct or @typeInfo(T) == .Type);
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
    std.debug.assert(@typeInfo(First) == .Struct or @typeInfo(First) == .Type);

    const Second = @TypeOf(second);
    const second_type_info = @typeInfo(Second);

    std.debug.assert(second_type_info == .Type or Second == c.EcsEntity);

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
    std.debug.assert(@typeInfo(Second) == .Struct or @typeInfo(Second) == .Type);

    const First = @TypeOf(first);
    const first_type_info = @typeInfo(First);

    std.debug.assert(first_type_info == .Type or First == c.EcsEntity);

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
pub fn ecs_isa( e: anytype) c.EcsId {
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