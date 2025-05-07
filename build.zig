const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = std.builtin.OptimizeMode.Debug;

    // main executable

    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);

    // tests
    const tests = b.addExecutable(.{
        .name = "tests",
        .root_source_file = b.path("tests/all_tests.zig"),
        .target = target,
        .optimize = optimize,
    });

    const cpu = b.createModule(.{ .root_source_file = .{ .cwd_relative = "src/cpu.zig" } });
    const mem = b.createModule(.{ .root_source_file = .{ .cwd_relative = "src/memory.zig" } });
    tests.root_module.addImport("cpu", cpu);
    tests.root_module.addImport("mem", mem);

    b.installArtifact(tests);

    const run_tests = b.addRunArtifact(tests);

    const run_tests_step = b.step("test", "run tests");
    run_tests_step.dependOn(&run_tests.step);
}
