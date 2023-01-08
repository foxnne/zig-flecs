const builtin = @import("builtin");
const std = @import("std");

const current_version = "3.1.1";

pub fn build(b: *std.build.Builder) anyerror!void {
    const target = b.standardTargetOptions(.{});

    const examples = getAllExamples(b, projectPath(b, "examples"));

    const examples_step = b.step("all_examples", "build all examples");
    b.default_step.dependOn(examples_step);

    for (examples) |example| {
        const name = example[0];
        const source = example[1];

        var exe = b.addExecutable(name, source);
        exe.setTarget(target);
        exe.setOutputDir("zig-cache/bin");

        link(exe, target);
        exe.addPackage(pkg(b));

        const run_cmd = exe.run();
        const exe_step = b.step(name, b.fmt("run {s}.zig", .{name}));
        exe_step.dependOn(&run_cmd.step);
    }

    // only mac and linux get the update_flecs command
    if (!target.isWindows()) {
        var exe = b.addSystemCommand(&[_][]const u8{ "zsh", ".vscode/update_flecs.sh" });
        const exe_step = b.step("update_flecs", b.fmt("updates Flecs.h/c and runs translate-c", .{}));
        exe_step.dependOn(&exe.step);
    }
}

fn getAllExamples(b: *std.build.Builder, root_directory: []const u8) [][2][]const u8 {
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

pub fn pkg(b: *std.build.Builder) std.build.Pkg {
    const cached_result = struct {
        var pkg: ?std.build.Pkg = null;
    };
    if (cached_result.pkg == null) {
        cached_result.pkg = .{
            .name = "flecs",
            .source = .{ .path = projectPath(b, "src/flecs.zig") },
        };
    }
    return cached_result.pkg.?;
}

pub fn link(exe: *std.build.LibExeObjStep, target: std.zig.CrossTarget) void {
    exe.linkLibC();
    exe.addIncludePath(projectPath(exe.builder, "src/c"));

    if (target.isWindows()) {
        exe.linkSystemLibrary("Ws2_32");
    }

    exe.addCSourceFile(projectPath(exe.builder, "src/c/flecs.c"), &.{""});
}

const projectPath = (struct {
    inline fn projectRoot() []const u8 {
        return comptime std.fs.path.dirname(@src().file) orelse ".";
    }

    inline fn projectPath(allocator: anytype, comptime suffix: []const u8) []const u8 {
        if (@TypeOf(allocator) == std.mem.Allocator) {
            return resolvePath(allocator, suffix.len, suffix[0..suffix.len].*);
        } else {
            return resolvePath(allocator.allocator, suffix.len, suffix[0..suffix.len].*);
        }
    }

    fn cwd(allocator: std.mem.Allocator) []const u8 {
        const cached_result = struct {
            var resolved_path: ?[]const u8 = null;
        };
        if (cached_result.resolved_path == null) {
            cached_result.resolved_path = std.process.getCwdAlloc(allocator) catch unreachable;
        }
        return cached_result.resolved_path.?;
    }

    fn resolvePath(allocator: std.mem.Allocator, comptime len: usize, comptime suffix: [len]u8) []const u8 {
        const project_path = projectRoot() ++ "/" ++ suffix[0..];
        if (comptime std.fs.path.isAbsolute(project_path)) {
            return project_path;
        }
        const cached_result = struct {
            var resolved_path: ?[]const u8 = null;
        };
        if (cached_result.resolved_path == null) {
            cached_result.resolved_path = std.fs.path.resolve(
                allocator,
                &.{ cwd(allocator), project_path },
            ) catch unreachable;
        }
        return cached_result.resolved_path.?;
    }
}).projectPath;
