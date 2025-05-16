const std = @import("std");
const Memory = @import("memory.zig").Memory;
const Cpu = @import("cpu.zig").Cpu;
const Timer = @import("timer.zig").Timer;
const Bus = @import("bus.zig").Bus;

pub fn main() !void {
    // setup memory
    var memory: Memory = undefined;

    // setup timer
    var timer: Timer = undefined;

    // setup bus
    var bus: Bus = undefined;
    bus.init(&memory, &timer);

    // load cartrige
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    try bus.loadCartrige("tests/test_roms/cpu_instrs/cpu_instrs.gb", allocator);

    // setup cpu
    var cpu: Cpu = undefined;
    try cpu.init(&bus);

    var totalMCycles: u32 = 0;
    // const T_CYCLES_PER_FRAME: u32 = 70224;

    while (true) {
        const mCycles = cpu.tick();
        totalMCycles += mCycles;
    }

    std.debug.print("{d}", .{totalMCycles});
}
