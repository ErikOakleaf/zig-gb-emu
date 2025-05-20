const std = @import("std");
const Memory = @import("memory.zig").Memory;
const Cpu = @import("cpu.zig").Cpu;
const Timer = @import("timer.zig").Timer;
const Bus = @import("bus.zig").Bus;
const Renderer = @import("renderer.zig").Renderer;
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

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

    try bus.loadCartrige("tests/test_roms/instr_timing/instr_timing.gb", allocator);
    defer bus.deinitCartridge(allocator);

    // setup cpu
    var cpu: Cpu = undefined;
    try cpu.init(&bus);

    // setup sdl and renderer
    var renderer: Renderer = undefined;
    try renderer.init(5);
    defer renderer.deinit();

    mainloop: while (true) {
        var sdl_event: c.SDL_Event = undefined;

        while (c.SDL_PollEvent(&sdl_event)) {
            switch (sdl_event.type) {
                c.SDL_EVENT_QUIT => break :mainloop,
                else => {},
            }
        }
    }
}
