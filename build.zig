const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addSharedLibrary(.{
        .name = "HelloVST3",
        .root_source_file = .{ .path = "src/plugin.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib.linkLibC();

    b.installArtifact(lib);
}
