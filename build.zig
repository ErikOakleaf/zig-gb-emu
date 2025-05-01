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
    const cpu_test = b.addTest(.{
        .name = "cpu_test",
        .root_source_file = b.path("tests/cpu_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    const cpu_module = b.createModule(.{ .root_source_file = b.path("src/cpu.zig") });

    cpu_test.root_module.addImport("cpu", cpu_module);

    b.installArtifact(cpu_test);

    const run_test = b.addRunArtifact(cpu_test);

    const run_test_step = b.step("test", "run tests");
    run_test_step.dependOn(&run_test.step);
}
