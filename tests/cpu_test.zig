const std = @import("std");
const fs = std.fs;
const heap = std.heap;
const json = std.json;

const Cpu = @import("cpu").Cpu;

// create structs for coresponding json

const CpuState = struct {
    a: u8,
    b: u8,
    c: u8,
    d: u8,
    e: u8,
    f: u8,
    h: u8,
    l: u8,
    pc: u16,
    sp: u16,
    ram: []const [2]u16,
};

const TestVector = struct { name: []const u8, initial: CpuState, final: CpuState, cycles: []struct { u16, u8, []const u8 } };

const vectors_path = "/tests/vectors/cpu";

pub fn cpuTest() !void {
    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    var cpu: Cpu = undefined; // alloc CPU uninitialized

    var dir = try fs.cwd().openDir("tests/vectors/cpu", .{ .iterate = true });
    defer dir.close();

    var iter = dir.iterate();
    while (try iter.next()) |file| {
        std.debug.print("File: {s}\n", .{file.name});

        var fileHandle = try dir.openFile(file.name, .{});
        defer fileHandle.close();

        const fileSize = try fileHandle.getEndPos();
        const contentBuffer = try allocator.alloc(u8, fileSize);
        defer allocator.free(contentBuffer);

        _ = try fileHandle.readAll(contentBuffer);

        const parsedTestVectors = try json.parseFromSlice([]TestVector, allocator, contentBuffer[0..], .{});
        defer parsedTestVectors.deinit();

        for (parsedTestVectors.value) |vector| {
            try cpu.init(&allocator);

            var testFail: bool = false;

            cpu.a = vector.initial.a;
            cpu.b = vector.initial.b;
            cpu.c = vector.initial.c;
            cpu.d = vector.initial.d;
            cpu.e = vector.initial.e;
            cpu.f = vector.initial.f;
            cpu.h = vector.initial.h;
            cpu.l = vector.initial.l;
            cpu.pc = vector.initial.pc;
            cpu.sp = vector.initial.sp;

            _ = cpu.tick();

            for (vector.initial.ram) |mem| {
                const address: u16 = mem[0];
                const value: u8 = @intCast(mem[1]);

                switch (address) {
                    0x00...0x7FFF => {
                        cpu.memory.rom[address] = value;
                    },
                    else => {
                        cpu.memory.write(address, value);
                    },
                }
            }

            if (cpu.a != vector.final.a) {
                testFail = true;
                std.debug.print("register a: {d} is not: {d}\n", .{ cpu.a, vector.final.a });
            }

            if (cpu.b != vector.final.b) {
                testFail = true;
                std.debug.print("register a: {d} is not: {d}\n", .{ cpu.b, vector.final.b });
            }

            if (cpu.c != vector.final.c) {
                testFail = true;
                std.debug.print("register a: {d} is not: {d}\n", .{ cpu.c, vector.final.c });
            }

            if (cpu.d != vector.final.d) {
                testFail = true;
                std.debug.print("register a: {d} is not: {d}\n", .{ cpu.d, vector.final.d });
            }

            if (cpu.e != vector.final.e) {
                testFail = true;
                std.debug.print("register a: {d} is not: {d}\n", .{ cpu.e, vector.final.e });
            }

            if (cpu.f != vector.final.f) {
                testFail = true;
                std.debug.print("register a: {d} is not: {d}\n", .{ cpu.f, vector.final.f });
            }

            if (cpu.h != vector.final.h) {
                testFail = true;
                std.debug.print("register a: {d} is not: {d}\n", .{ cpu.h, vector.final.h });
            }

            if (cpu.l != vector.final.l) {
                testFail = true;
                std.debug.print("register a: {d} is not: {d}\n", .{ cpu.l, vector.final.l });
            }

            if (cpu.pc != vector.final.pc) {
                testFail = true;
                std.debug.print("register a: {d} is not: {d}\n", .{ cpu.pc, vector.final.pc });
            }

            if (cpu.sp != vector.final.sp) {
                testFail = true;
                std.debug.print("register a: {d} is not: {d}\n", .{ cpu.sp, vector.final.sp });
            }

            for (vector.final.ram) |mem| {
                const address: u16 = mem[0];
                const value: u8 = @intCast(mem[1]);
                const cpuValue: u8 = cpu.memory.read(address);

                if (cpu.memory.read(address) != value) {
                    testFail = true;
                    std.debug.print("memory at {d}: {d} is not {d}\n", .{ address, cpuValue, value });
                }
            }

            if (testFail) {
                std.debug.print("test {s} failed\n", .{vector.name});
            } else {
                std.debug.print("test {s} succeded\n", .{vector.name});
            }
        }
    }
}
