const std = @import("std");
const fs = std.fs;
const heap = std.heap;

const Cpu = @import("cpu").Cpu;

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
        std.debug.print("--- Content of {s} ---\n{s}\n----------------------\n", .{ file.name, contentBuffer[0..] });
    }
}
