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
    ram: []struct { u16, u16 },
};

const TestVector = struct { name: []const u8, initial: CpuState, final: CpuState, cycles: []struct { u16, u8, []const u8 } };

const vectors_path = "/tests/vectors/cpu";

pub fn cpuTest() !void {
    // var cpu: Cpu = undefined;

    var gpa = heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

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
            std.debug.print("vector name: {s}\n", .{vector.name});
        }
    }
}
