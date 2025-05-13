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

    var totalTCycles: u32 = 0;
    // const T_CYCLES_PER_FRAME: u32 = 70224;

    while (totalTCycles < 100000000) {
        const tCycles = cpu.tick() * 4;
        totalTCycles += tCycles;
    }

    std.debug.print("{d}", .{totalTCycles});
}
