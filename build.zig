const builtin = @import("builtin");
const std = @import("std");

const new_build_system = @hasDecl(std, "Build");
const Build = if (new_build_system) std.Build else std.build.Builder;
const CompileStep = if (new_build_system) Build.CompileStep else std.build.LibExeObjStep;
const FileSource = if (new_build_system) Build.FileSource else std.build.FileSource;

const current_version = "3.1.1";

pub fn build(b: *Build) anyerror!void {
    const target = b.standardTargetOptions(.{});

    const examples = getAllExamples(b, b.pathFromRoot("examples"));

    const examples_step = b.step("all_examples", "build all examples");
    b.default_step.dependOn(examples_step);

    if (new_build_system) {
        b.addModule(.{
            .name = "flecs",
            .source_file = FileSource.relative("src/flecs.zig"),
        });
    }

    for (examples) |example| {
        const name = example[0];
        const source = example[1];

        const exe = if (new_build_system) blk: {
            const exe = b.addExecutable(.{
                .name = name,
                .root_source_file = .{ .path = source },
                .target = target,
            });
            exe.addModule("flecs", b.modules.get("flecs").?);

            break :blk exe;
        } else blk: {
            const exe = b.addExecutable(name, source);
            exe.setTarget(target);
            exe.addPackage(pkg);

            break :blk exe;
        };

        exe.setOutputDir("zig-cache/bin");
        link(exe, target);

        const run_cmd = exe.run();
        const exe_step = b.step(name, b.fmt("run {s}.zig", .{ name }));
        exe_step.dependOn(&run_cmd.step);
        examples_step.dependOn(&exe.step);
    }

    // only mac and linux get the update_flecs command
    if (!target.isWindows()) {
        var exe = b.addSystemCommand(&[_][]const u8{ "zsh", ".vscode/update_flecs.sh" });
        const exe_step = b.step("update_flecs", b.fmt("updates Flecs.h/c and runs translate-c", .{}));
        exe_step.dependOn(&exe.step);
    }
}

fn getAllExamples(b: *Build, root_directory: []const u8) [][2][]const u8 {
    var list = std.ArrayList([2][]const u8).init(b.allocator);

    const recursor = struct {
        fn search(alloc: std.mem.Allocator, directory: []const u8, filelist: *std.ArrayList([2][]const u8)) void {
            var dir = std.fs.cwd().openIterableDir(directory, .{ .access_sub_paths = true }) catch unreachable;
            defer dir.close();

            var iter = dir.iterate();
            while (iter.next() catch unreachable) |entry| {
                if (entry.kind == .File) {
                    if (std.mem.endsWith(u8, entry.name, ".zig")) {
                        const abs_path = std.fs.path.join(alloc, &[_][]const u8{ directory, entry.name }) catch unreachable;
                        const name = std.fs.path.basename(abs_path);

                        filelist.append([2][]const u8{ name[0 .. name.len - 4], abs_path }) catch unreachable;
                    }
                } else if (entry.kind == .Directory) {
                    const abs_path = std.fs.path.join(alloc, &[_][]const u8{ directory, entry.name }) catch unreachable;
                    search(alloc, abs_path, filelist);
                }
            }
        }
    }.search;

    recursor(b.allocator, root_directory, &list);

    return list.toOwnedSlice() catch unreachable;
}

pub const pkg = std.build.Pkg{
    .name = "flecs",
    .source = .{
        .path = thisDir() ++ "/src/flecs.zig",
    },
};

pub fn module(b: *std.Build) *std.Build.Module {
    return b.createModule(.{
        .source_file = .{
            .path = thisDir() ++ "/src/flecs.zig",
        },
    });
}

pub fn link(exe: *CompileStep, target: std.zig.CrossTarget) void {
    exe.linkLibC();
    exe.addIncludePath(thisDir() ++ "/src/c");

    if (target.isWindows()) {
        exe.linkSystemLibrary("Ws2_32");
    }

    exe.addCSourceFile(thisDir() ++ "/src/c/flecs.c", &.{""});
}

inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse ".";
}
