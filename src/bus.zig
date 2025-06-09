const std = @import("std");
const fs = std.fs;
const Memory = @import("memory.zig").Memory;
const Timer = @import("timer.zig").Timer;
const BITS = @import("timer.zig").BITS;
const Cartridge = @import("cartridge.zig").Cartridge;
const CartridgeType = @import("cartridge.zig").CartridgeType;
const RomSize = @import("cartridge.zig").RomSize;
const RamSize = @import("cartridge.zig").RamSize;
const PPU = @import("ppu.zig").PPU;
const Renderer = @import("renderer.zig").Renderer;
const Joypad = @import("joypad.zig").Joypad;

pub const Bus = struct {
    memory: *Memory,
    timer: *Timer,
    cartridge: *Cartridge,
    ppu: *PPU,
    joypad: *Joypad,

    pub fn init(self: *Bus, memory: *Memory, timer: *Timer, cartridge: *Cartridge, ppu: *PPU, joypad: *Joypad, renderer: *Renderer) void {
        self.memory = memory;
        self.memory.init();

        self.timer = timer;
        self.timer.init();
        self.timer.flagRegister = &self.memory.io[0x0F];

        self.ppu = ppu;
        self.ppu.flagRegister = &self.memory.io[0x0F];
        self.ppu.init(renderer);

        self.cartridge = cartridge;

        self.joypad = joypad;
        self.joypad.init();
        self.joypad.flagRegister = &self.memory.io[0x0F];
    }
    // tick subsystems

    pub fn tick(self: *Bus, tCycles: u32) void {
        self.timer.tick();
        self.ppu.tick(tCycles);
    }

    // MMU

    pub fn write(self: *Bus, address: u16, value: u8) void {
        switch (address) {
            0x0000...0x7FFF => {
                // memory bank switching TODO - make this work completely and make it into helper functions
                switch (self.cartridge.type) {
                    CartridgeType.MBC1 => {
                        switch (address) {
                            0x0000...0x1FFF => {
                                self.cartridge.ramEnabled = (value & 0x0F) == 0x0A;
                            },
                            0x2000...0x3FFF => {
                                const bankSelect: usize = @max(1, value & 0x1F);
                                self.cartridge.bank = bankSelect;
                                // std.debug.print("memory bank {d} in use selected bank: {d}", .{ self.cartridge.bank, bankSelect });
                            },
                            0x4000...0x5FFF => {
                                // std.debug.print("higher bits selected", .{});
                            },
                            else => {},
                        }
                    },
                    else => {},
                }
            },
            0x8000...0x9FFF => {
                self.ppu.vram[address - 0x8000] = value;
            },
            0xFE00...0xFE9F => {
                self.ppu.oam[address - 0xFE00] = value;
            },
            0xFF00 => {
                // write to p1 lower nibble is read only
                const maskedValue = value & 0xF0;
                self.joypad.p1 = (self.joypad.p1 & 0x0F) | maskedValue;
            },
            0xFF02 => {
                self.memory.write(address, value);

                // TODO - check this implementation more thourgouhly later now for debugging serial transfer
                if ((value & 0x80) != 0) {
                    // enable these two lines under here if you want to see what serial transfer is printing out

                    const serialBuffer = self.memory.read(0xFF01);
                    std.debug.print("{c}", .{serialBuffer});

                    self.memory.write(address, self.memory.read(address) & ~@as(u8, 0x80));
                }
            },
            // timer memory registers
            0xFF04 => {
                // if write is done to div register [0xFF04] always reset it
                self.timer.div = 0;
                self.timer.cycles = 0;
                self.timer.incrementTima();
                self.timer.previousCycles = 0;
            },
            0xFF05 => {
                if (self.timer.overflowDelay == 0) {
                    self.timer.tima = value;
                    std.debug.print("normal tima write\n", .{});
                } else if (self.timer.overflowDelay > 4) {
                    std.debug.print("cancel timer reload\n", .{});
                    self.timer.tima = value;
                    self.timer.overflowDelay = 0;
                } else {
                    std.debug.print("ignored tima write\n", .{});
                }
            },
            0xFF06 => {
                self.timer.tma = value;
                if (self.timer.overflowDelay < 4 and self.timer.overflowDelay > 0) {
                    self.timer.tima = value;
                }
            },
            0xFF07 => {
                const oldTac = self.timer.tac;
                const oldEnable = (oldTac & (1 << 2)) != 0;
                const oldClockSelect: u2 = @truncate(oldTac);
                const oldMask = std.math.shl(u32, 1, BITS[@as(usize, oldClockSelect)]);
                const oldEdge = self.timer.cycles & oldMask != 0;

                const newTac = value;
                const newEnable = (newTac & (1 << 2)) != 0;
                const newClockSelect: u2 = @truncate(newTac);
                const newMask = std.math.shl(u32, 1, BITS[@as(usize, newClockSelect)]);
                const newEdge = self.timer.cycles & newMask != 0;

                // check if timer get's disabled and if we might increment tima
                if (oldEnable and !newEnable and oldEdge) {
                    self.timer.incrementTima();
                }

                // check if the new clock select value is 1 and the current one is 0 if this is the case increment tima
                if (newEnable and !oldEdge and newEdge) {
                    self.timer.incrementTima();
                }

                self.timer.tac = value;
            },
            // ppu memory registers
            0xFF40 => {
                self.ppu.lcdc = value;
            },
            0xFF41 => {
                self.ppu.stat = value;
            },
            0xFF42 => {
                self.ppu.scy = value;
            },
            0xFF43 => {
                self.ppu.scx = value;
            },
            0xFF44 => {
                self.ppu.ly = value;
            },
            0xFF45 => {
                self.ppu.lyc = value;
            },
            0xFF46 => {
                // handle dma transfer
                self.ppu.dma = value;
                self.ppu.dmaSource = @as(u16, value) << 8;
                self.ppu.dmaActive = true;
                self.ppu.dmaCycles = 160;
            },
            0xFF47 => {
                self.ppu.bgp = value;
            },
            0xFF48 => {
                self.ppu.obp0 = value;
            },
            0xFF49 => {
                self.ppu.obp1 = value;
            },
            0xFF4A => {
                self.ppu.wy = value;
            },
            0xFF4B => {
                self.ppu.wx = value;
            },
            else => {
                self.memory.write(address, value);
            },
        }
    }

    pub fn read(self: *Bus, address: u16) u8 {
        // check if DMA is active and if the adress is not in oam or hram
        if (self.ppu.dmaActive) {
            const inOam = (address >= 0xFE00 and address <= 0xFE9F);
            const inHram = (address >= 0xFF80 and address <= 0xFFFE);
            if (!(inOam or inHram)) {
                return 0x0;
            }
        }

        switch (address) {
            0x0000...0x3FFF => {
                return self.cartridge.rom[address];
            },
            0x4000...0x7FFF => {
                // TODO - make this better later and expand it to more cartridge types and use helper functions
                // to maintain readability
                if (self.cartridge.type != CartridgeType.ROMOnly) {
                    const memoryBank = self.cartridge.bank;
                    return self.cartridge.rom[memoryBank * 0x4000 + (address - 0x4000)];
                } else {
                    return self.cartridge.rom[address];
                }
            },
            0x8000...0x9FFF => {
                return self.ppu.vram[address - 0x8000];
            },
            0xFE00...0xFE9F => {
                return self.ppu.oam[address - 0xFE00];
            },
            0xFF00 => {
                return self.joypad.p1;
            },
            0xFF04 => {
                return self.timer.div;
            },
            0xFF05 => {
                return self.timer.tima;
            },
            0xFF06 => {
                return self.timer.tma;
            },
            0xFF07 => {
                return self.timer.tac;
            },
            // ppu memory registers
            0xFF40 => {
                return self.ppu.lcdc;
            },
            0xFF41 => {
                return self.ppu.stat;
            },
            0xFF42 => {
                return self.ppu.scy;
            },
            0xFF43 => {
                return self.ppu.scx;
            },
            0xFF44 => {
                return self.ppu.ly;
            },
            0xFF45 => {
                return self.ppu.lyc;
            },
            0xFF46 => {
                return self.ppu.dma;
            },
            0xFF47 => {
                return self.ppu.bgp;
            },
            0xFF48 => {
                return self.ppu.obp0;
            },
            0xFF49 => {
                return self.ppu.obp1;
            },
            0xFF4A => {
                return self.ppu.wy;
            },
            0xFF4B => {
                return self.ppu.wx;
            },
            else => {
                return self.memory.read(address);
            },
        }
    }
};
