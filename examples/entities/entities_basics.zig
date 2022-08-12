const std = @import("std");
const flecs = @import("flecs");

const Position = struct { x: f32, y: f32 };
const Walking = struct {};

const Has = struct{};
const Apples = struct { count: i32 };
const Eats = struct { count: i32 }; 
const Likes = struct{ amount: i32 = 10 };

pub fn main() !void {
    var world = flecs.c.ecs_init().?;

    // Create an entity with name Bob
    const bob = flecs.ecs_new(world, null);

    // The set operation finds or creates a component, and sets it.
    flecs.ecs_set(world, bob, &Position { .x = 10, .y = 20 });

    // The add operation adds a component without setting a value. This is
    // useful for tags, or when adding a component with its default value.
    flecs.ecs_add(world, bob, Walking);

    // Get the value for the Position component
    if (flecs.ecs_get(world, bob, Position)) |position| {
        std.log.debug("position: {any}", .{position});
    }

    // Overwrite the value of the Position component
    flecs.ecs_set(world, bob, &Position{ .x = 20.0, .y = 30.0 });

    if (flecs.ecs_get(world, bob, Position)) |position| {
        std.log.debug("position: {any}", .{position});
    }

    // Create another named entity
    const alice = flecs.ecs_new_entity(world, "Alice");
    flecs.ecs_set(world, alice, &Position { .x = 10, .y = 20 });
    flecs.ecs_add(world, bob, Walking);


    flecs.ecs_set_pair_second(world, alice, Has, &Apples{ .count = 5 });

    if (flecs.ecs_get_pair_second(world, alice, Has, Apples)) |apples| {
        std.log.debug("Alice has {d} apples!", .{ apples.count });
    }

    flecs.ecs_set_pair(world, alice, &Eats{ .count = 2, }, Apples);

    if (flecs.ecs_get_pair(world, alice, Eats, Apples)) |eats| {
        std.log.debug("Alice eats {d} apples!", .{ eats.count });
    }

    flecs.ecs_set_pair(world, alice, Likes{ .amount = 10, }, bob);
    flecs.ecs_set_pair(world, alice, Likes{ .amount = 5, }, Apples);

    if (flecs.ecs_get_pair(world, alice, Likes, bob)) |b| {
        std.log.debug("How much does Alice like bob? {d}", .{ b.amount });
    }

    if (flecs.ecs_get_pair(world, alice, Likes, flecs.c.Constants.EcsWildcard)) |likes| {
        std.log.debug("Alice likes someone how much? {d}", .{ likes.amount });
    }

    const entities = flecs.ecs_bulk_new(world, Apples, 10);

    for (entities) |entity, i| {
        if (flecs.ecs_get(world, entity, Apples)) |apples| {
            std.log.debug("Bulk Entity {d}: {d} apples!", .{i, apples.count});
        } 
    }

    


    // TODO: add a getType method and wrapper for flecs types
    // Print all the components the entity has. This will output:
    //    Position, Walking, (Identifier,Name)
    // const alice_type = alice.getType();

    // // Remove tag
    // alice.remove(Walking);

    // // Iterate all entities with Position
    // var term = flecs.Term(Position).init(world);
    // defer term.deinit();
    // var it = term.iterator();

    // while (it.next()) |position| {
    //     std.log.debug("{s}: {d}", .{ it.entity().getName(), position });
    // }

    // world.deinit();
}
