const std = @import("std");
const Memory = @import("memory.zig").Memory;
const Cpu = @import("cpu.zig").Cpu;
const Timer = @import("timer.zig").Timer;
const Bus = @import("bus.zig").Bus;

pub fn main() !void {
    // setup general purpose allocator
    // TODO - remove this later since you can probably init everything here and then attach it to the cpu because the tests don't matter that much anymore

    // setup memory
    var memory: Memory = undefined;
    memory.init();

    // setup timer
    var timer: Timer = undefined;

    // setup bus
    var bus: Bus = undefined;
    bus.init(&memory, &timer);
    bus.initTimer();

    // setup cpu
    var cpu: Cpu = undefined;
    try cpu.init(&bus);

    var totalMCycles: u32 = 0;
    // const T_CYCLES_PER_FRAME: u32 = 70224;

    while (totalMCycles < 100000000) {
        const mCycles = cpu.tick();
        totalMCycles += mCycles;
    }

    std.debug.print("{d}", .{totalMCycles});
}
