const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const goose = b.dependency(
        "goose",
        .{ .target = target, .optimize = optimize },
    );

    const gooseModule = goose.module("goose");

    const exe = b.addExecutable(.{
        .name = "any_filechooser",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "goose", .module = gooseModule },
            },
        }),
    });

    b.installArtifact(exe);

    const checkStep = b.step("check", "Build on save");
    exe.step.dependOn(checkStep);
}
