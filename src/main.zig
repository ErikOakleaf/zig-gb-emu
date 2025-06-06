const std = @import("std");
const Memory = @import("memory.zig").Memory;
const Cpu = @import("cpu.zig").Cpu;
const Timer = @import("timer.zig").Timer;
const Bus = @import("bus.zig").Bus;
const Renderer = @import("renderer.zig").Renderer;
const Cartridge = @import("cartridge.zig").Cartridge;
const PPU = @import("ppu.zig").PPU;
const Joypad = @import("joypad.zig").Joypad;
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

// enable debug here to get the execution trace
const debug = false;

pub fn main() !void {
    // setup memory
    var memory: Memory = undefined;

    // setup timer
    var timer: Timer = undefined;

    // setup cartrige
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var cartridge: Cartridge = undefined;

    try cartridge.load("tests/test_roms/cpu_instrs/cpu_instrs.gb", allocator);
    // try cartridge.load("tests/test_roms/cpu_instrs/individual/01-special.gb", allocator);
    // try cartridge.load("tests/test_roms/tetris.gb", allocator);
    // try cartridge.load("tests/test_roms/Dr. Mario.gb", allocator);
    // try cartridge.load("tests/test_roms/Super Mario Land.gb", allocator);
    defer cartridge.deinit(allocator);

    // setup ppu
    var ppu: PPU = undefined;

    var joypad: Joypad = undefined;

    // setup sdl and renderer
    var renderer: Renderer = undefined;
    try renderer.init(6);
    defer renderer.deinit();

    // setup bus
    var bus: Bus = undefined;
    bus.init(&memory, &timer, &cartridge, &ppu, &joypad, &renderer);

    // setup cpu
    var cpu: Cpu = undefined;
    try cpu.init(&bus, debug);

    const TARGET_FPS = 59.7;
    const FRAME_TIME_MS: u32 = @intFromFloat(1000.0 / TARGET_FPS); // ~16.75 ms per frame
    const CYCLES_PER_FRAME = 70224 * 4; // Game Boy cycles per frame (4.194304 MHz / 59.7 Hz)

    var lastFrameTime = c.SDL_GetTicks();

    mainloop: while (true) {
        // tick cpu
        try cpu.step();

        // delay to keep steady fps
        if (cpu.cycles >= CYCLES_PER_FRAME) {
            cpu.cycles -= CYCLES_PER_FRAME;

            const currentTime = c.SDL_GetTicks();
            const frameTime = currentTime - lastFrameTime;

            if (frameTime < FRAME_TIME_MS) {
                const delayTime: u32 = @intCast(FRAME_TIME_MS - frameTime);
                c.SDL_Delay(delayTime);
                // std.debug.print("slept for {d} ms", .{delayTime});
            }

            lastFrameTime = c.SDL_GetTicks();
        }

        var sdl_event: c.SDL_Event = undefined;

        while (c.SDL_PollEvent(&sdl_event)) {
            switch (sdl_event.type) {
                c.SDL_EVENT_QUIT => break :mainloop,
                c.SDL_EVENT_KEY_DOWN => {
                    cpu.bus.joypad.updateJoypadState(sdl_event.key.scancode, true);
                },
                c.SDL_EVENT_KEY_UP => {
                    cpu.bus.joypad.updateJoypadState(sdl_event.key.scancode, false);
                },
                else => {},
            }
        }
    }

    if (debug) {
        cpu.debugFile.close();
    }
}
