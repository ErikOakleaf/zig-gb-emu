const std = @import("std");
const cpuTest = @import("cpu_test.zig");

pub fn main() !void {
    try cpuTest.cpuTest();
}
