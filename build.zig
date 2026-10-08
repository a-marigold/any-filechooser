const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const glib = b.addTranslateC(.{
        .root_source_file = b.path("src/glibBridge.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    glib.linkSystemLibrary("glib-2.0", .{});

    const exe = b.addExecutable(.{
        .name = "any_filechooser",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "glib", .module = glib.createModule() },
            },
        }),
    });

    exe.root_module.linkSystemLibrary("glib-2.0", .{});
    b.installArtifact(exe);

    const checkStep = b.step("check", "Build on save");
    checkStep.dependOn(&exe.step);
}
