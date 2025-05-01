const std = @import("std");
const expect = std.testing.expect;
const Cpu = @import("cpu").Cpu;

var cpu: Cpu = undefined;

test "init test" {
    cpu.a = 5;
    try expect(cpu.a == 5);
}

test "init false test" {
    cpu.a = 5;
    try expect(cpu.a == 3);
}
