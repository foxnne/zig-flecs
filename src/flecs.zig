const std = @import("std");
pub const c = @import("c.zig");

// - Utility Functions

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
        .Type, .Struct => return T,
        else => {},
    }
    @compileError("Expected pointer or optional pointer, found '" ++ @typeName(T) ++ "'");
}

/// Combines two EcsIds into the lo and hi bits of an EcsId.
fn ecs_entity_comb(lo: c.EcsId, hi: c.EcsId) c.EcsId {
    return (hi << @as(u32, 32)) + @intCast(u64, @truncate(u32, lo));
}

/// Casts the anyopaque pointer to a const pointer of the given type.
pub fn ecs_cast(comptime T: type, val: ?*const anyopaque) *const T {
    return @ptrCast(*const T, @alignCast(@alignOf(T), val));
}

/// Returns the EcsId of the given type.
pub fn ecs_id(world: *c.EcsWorld, comptime T: type) c.EcsId {
    if (@sizeOf(T) == 0) {
        var desc = std.mem.zeroInit(c.EcsEntityDesc, .{ .name = @typeName(T) });
        return c.ecs_entity_init(world, &desc);
    } else {
        var entity_desc = std.mem.zeroInit(c.EcsEntityDesc, .{ .name = @typeName(T) });
        var comp_desc = std.mem.zeroInit(c.EcsComponentDesc, .{ .entity = c.ecs_entity_init(world, &entity_desc) });
        comp_desc.type.alignment = @alignOf(T);
        comp_desc.type.size = @sizeOf(T);
        return c.ecs_component_init(world, &comp_desc);
    }
}

/// Returns an EcsId for the given pair of EcsIds.
pub fn ecs_pair(pred: c.EcsId, obj: c.EcsId) c.EcsId {
    return c.Constants.ECS_PAIR | ecs_entity_comb(obj, pred);
}

/// Returns an EcsId for the given pair.
pub fn ecs_pair_id(world: *c.EcsWorld, first: anytype, second: anytype) c.EcsId {
    const First = @TypeOf(first);
    const Second = @TypeOf(second);

    const first_type_info = @typeInfo(First);
    const second_type_info = @typeInfo(Second);

    std.debug.assert(First == c.EcsEntity or first_type_info == .Type);
    std.debug.assert(Second == c.EcsEntity or second_type_info == .Type);

    const first_id = if (First == c.EcsEntity) first else ecs_id(world, First);
    const second_id = if (Second == c.EcsEntity) second else ecs_id(world, Second);
    return ecs_pair(first_id, second_id);
}

// - New

/// Returns a new entity with the given component. Pass null if no component is desired.
pub fn ecs_new(world: *c.EcsWorld, comptime T: ?type) c.EcsEntity {
    if (T) |Type| {
        std.debug.assert(@typeInfo(Type) == .Struct or @typeInfo(Type) == .Type);
        return c.ecs_new_w_id(world, ecs_id(world, Type));
    } 

    return c.ecs_new_id(world);
}

/// Returns a new entity with the given pair.
pub fn ecs_new_w_pair(world: *c.EcsWorld, first: anytype, second: anytype) c.EcsEntity {
    return c.ecs_new_w_id(world, ecs_pair_id(first, second));
}

/// Creates count entities in bulk with the given component, returning an array of those entities. 
/// Pass null for the component if none is desired.
pub fn ecs_bulk_new(world: *c.EcsWorld, comptime Component: ?type, count: i32) []const c.EcsEntity {
    if (Component) |T| {
        std.debug.assert(@typeInfo(T) == .Struct or @typeInfo(T) == .Type);
        return c.ecs_bulk_new_w_id(world, ecs_id(world, T), count)[0..@intCast(usize, count)];
    }

    return c.ecs_bulk_new_w_id(world, 0, count)[0..@intCast(usize, count)];
}

/// Returns a new entity with the given name.
pub fn ecs_new_entity(world: *c.EcsWorld, name: [:0]const u8) c.EcsEntity {
    const desc = std.mem.zeroInit(c.EcsEntityDesc, .{ .name = name, .id = c.ecs_new_id(world) });
    return c.ecs_entity_init(world, &desc);
}

// - Add

/// Adds a component to the entity. If the type is a non-zero struct, the values are default.
pub fn ecs_add(world: *c.EcsWorld, entity: c.EcsEntity, comptime T: type) void {
    std.debug.assert(@typeInfo(T) == .Struct or @typeInfo(T) == .Type);
    c.ecs_add_id(world, entity, ecs_id(world, T));
}

/// Adds the pair to the entity.
///
/// first = EcsEntity or type
/// second = EcsEntity or type
pub fn ecs_add_pair(world: *c.EcsWorld, entity: c.EcsEntity, first: anytype, second: anytype) void {
    c.ecs_add_id(world, entity, ecs_pair_id(world, first, second));
}

// - Remove

/// Removes the component or entity from the entity.
///
/// t = EcsEntity or Type
pub fn ecs_remove(world: *c.EcsWorld, entity: c.EcsEntity, t: anytype) void {
    const T = @TypeOf(t);
    const type_info = @typeInfo(T);

    std.debug.assert(T == c.EcsEntity or type_info == .Type);

    const id = if (T == c.EcsEntity) t else ecs_id(world, t);
    c.ecs_remove_id(world, entity, id);
}

/// Removes the pair from the entity.
///
/// first = EcsEntity or type
/// second = EcsEntity or type
pub fn ecs_remove_pair(world: *c.EcsWorld, entity: c.EcsEntity, first: anytype, second: anytype) void {
    c.ecs_remove_id(world, entity, ecs_pair_id(world, first, second));
}

// - Override

/// Overrides the component on the entity.
pub fn ecs_override(world: *c.EcsWorld, entity: c.EcsEntity, comptime T: type) void {
    std.debug.assert(@typeInfo(T) == .Struct or @typeInfo(T) == .Type);
    c.ecs_override_id(world, entity, ecs_id(world, T));
}

/// Overrides the pair on the entity.
///
/// first = EcsEntity or type
/// second = EcsEntity or type
pub fn ecs_override_pair(world: *c.EcsWorld, entity: c.EcsEntity, first: anytype, second: anytype) void {
    c.ecs_override_id(world, entity, ecs_pair_id(world, first, second));
}

// Bulk remove/delete

/// Deletes all children from parent entity.
pub fn ecs_delete_children(world: *c.EcsWorld, parent: c.EcsEntity) void {
    c.ecs_delete_with(world, ecs_pair_id(world, c.Constants.EcsChildOf, parent));
}

// - Set

/// Sets the component on the entity. If the component is not already added, it will automatically be added and set.
pub fn ecs_set(world: *c.EcsWorld, entity: c.EcsEntity, t: anytype) void {
    std.debug.assert(@typeInfo(@TypeOf(t)) == .Pointer or @typeInfo(@TypeOf(t)) == .Struct);
    const T = BaseType(@TypeOf(t));
    const ptr = if (@typeInfo(@TypeOf(t)) == .Pointer) t else &t;
    _ = c.ecs_set_id(world, entity, ecs_id(world, T), @sizeOf(T), ptr);
}

/// Sets the component on the first element of the pair. If the component is not already added, it will automatically be added and set.
///
/// first = pointer or struct
/// second = type or EcsEntity
pub fn ecs_set_pair(world: *c.EcsWorld, entity: c.EcsEntity, first: anytype, second: anytype) void {
    const First = @TypeOf(first);
    const Second = @TypeOf(second);

    const first_type_info = @typeInfo(First);
    const second_type_info = @typeInfo(Second);

    std.debug.assert(first_type_info == .Pointer or first_type_info == .Struct);
    std.debug.assert(second_type_info == .Type or Second == c.EcsEntity);

    const FirstT = BaseType(First);

    const first_id = ecs_id(world, FirstT);
    const second_id = if (Second == c.EcsEntity) second else ecs_id(world, Second);
    const pair_id = ecs_pair(first_id, second_id);

    const ptr = if (first_type_info == .Pointer) first else &first;

    _ = c.ecs_set_id(world, entity, pair_id, @sizeOf(FirstT), ptr);
}

/// Sets the component on the second element of the pair. If the component is not already added, it will automatically be added and set.
///
/// first = type or EcsEntity
/// second = pointer or struct
pub fn ecs_set_pair_second(world: *c.EcsWorld, entity: c.EcsEntity, first: anytype, second: anytype) void {
    const First = @TypeOf(first);
    const Second = @TypeOf(second);

    const first_type_info = @typeInfo(First);
    const second_type_info = @typeInfo(Second);

    std.debug.assert(first_type_info == .Type or First == c.EcsEntity);
    std.debug.assert(second_type_info == .Pointer or second_type_info == .Struct);

    const SecondT = BaseType(Second);

    const first_id = if (First == c.EcsEntity) first else ecs_id(world, First);
    const second_id = ecs_id(world, SecondT);
    const pair_id = ecs_pair(second_id, first_id);

    const ptr = if (second_type_info == .Pointer) second else &second;

    _ = c.ecs_set_id(world, entity, pair_id, @sizeOf(SecondT), ptr);
}

// - Get

/// Gets an optional pointer to the given component type on the entity.
pub fn ecs_get(world: *c.EcsWorld, entity: c.EcsEntity, comptime T: type) ?*const T {
    std.debug.assert(@typeInfo(T) == .Struct or @typeInfo(T) == .Type);
    if (c.ecs_get_id(world, entity, ecs_id(world, T))) |ptr| {
        return ecs_cast(T, ptr);
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

    const first_id = ecs_id(world, First);
    const second_id = if (Second == c.EcsEntity) second else ecs_id(world, Second);

    const pair_id = ecs_pair(first_id, second_id);

    if (c.ecs_get_id(world, entity, pair_id)) |ptr| {
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

    const first_id = if (First == c.EcsEntity) first else ecs_id(world, First);
    const second_id = ecs_id(world, Second);

    const pair_id = ecs_pair(second_id, first_id);

    if (c.ecs_get_id(world, entity, pair_id)) |ptr| {
        return ecs_cast(Second, ptr);
    }
    return null;
}
