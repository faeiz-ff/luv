const std = @import("std");
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const luv_mod = b.addModule("luv", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    luv_mod.addImport("luv", luv_mod);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "luv", .module = luv_mod },
        }
    });

    const luv_check = b.addExecutable(.{
        .name = "luv",
        .root_module = luv_mod,
    });

    const exe_check = b.addExecutable(.{
        .name = "luvc",
        .root_module = exe_mod,
    });

    const check_step = b.step("check", "Check if luv compiles");
    check_step.dependOn(&exe_check.step);
    check_step.dependOn(&luv_check.step);

    const exe = b.addExecutable(.{
        .name = "luvc",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const luv_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test/all.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "luv", .module = luv_mod },
            },
        }),
    });

    const run_exe_tests = b.addRunArtifact(luv_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
