const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    // const optimize = std.builtin.OptimizeMode.Debug;
    const optimize = std.builtin.OptimizeMode.ReleaseFast;

    // main executable

    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // SDL
    const sdl_path = "deps/SDL3-3.2.14/";
    exe.addIncludePath(b.path(sdl_path ++ "include"));
    exe.addLibraryPath(b.path(sdl_path ++ "lib/x64"));
    b.installBinFile(sdl_path ++ "lib/x64/SDL3.dll", "SDL3.dll");
    exe.linkSystemLibrary("sdl3");
    exe.linkLibC();

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
