const std = @import("std");
const memory = @import("memory.zig");
const Cpu = @import("cpu.zig").Cpu;

pub fn main() !void {
    // setup general purpose allocator
    // TODO - remove this later since you can probably init everything here and then attach it to the cpu because the tests don't matter that much anymore

    // setup memory
    var gbMemory: memory.Memory = undefined;
    gbMemory.init();

    // setup cpu

    var cpu: Cpu = undefined;
    try cpu.init(&gbMemory);

    var cycles: u32 = 0;
    // const CYCLES_PER_FRAME: u32 = 70224;

    while (cycles < 100000000) {
        cycles += cpu.tick();
    }

    std.debug.print("{d}", .{cycles});
}
