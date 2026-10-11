const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libdbus = b.addTranslateC(.{
        .root_source_file = b.path("src/libdbusBridge.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    libdbus.addIncludePath(b.graph.cwdRelativePath("/usr/include/dbus-1.0"));
    libdbus.addIncludePath(b.graph.cwdRelativePath("/usr/lib/dbus-1.0/include"));

    const mainMod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "libdbus", .module = libdbus.createModule() },
        },
    });

    mainMod.linkSystemLibrary("glib-2.0", .{});

    const exe = b.addExecutable(.{
        .name = "any_filechooser",
        .root_module = mainMod,
    });

    b.installArtifact(exe);

    const checkStep = b.step("check", "Build on save");
    checkStep.dependOn(&exe.step);
}
