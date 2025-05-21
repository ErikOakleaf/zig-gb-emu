const std = @import("std");
const fs = std.fs;
const Memory = @import("memory.zig").Memory;
const Timer = @import("timer.zig").Timer;
const Cartridge = @import("cartridge.zig").Cartridge;
const CartridgeType = @import("cartridge.zig").CartridgeType;
const RomSize = @import("cartridge.zig").RomSize;
const RamSize = @import("cartridge.zig").RamSize;
const PPU = @import("ppu.zig").PPU;

// define constants
// const BITS: [4]u8 = .{ 9, 3, 5, 7 };

pub const Bus = struct {
    memory: *Memory,
    timer: *Timer,
    cartridge: *Cartridge,
    ppu: *PPU,

    // Init functions

    pub fn init(self: *Bus, memory: *Memory, timer: *Timer, ppu: *PPU) void {
        self.memory = memory;
        self.timer = timer;
        self.ppu = ppu;
        self.memory.init();
        self.ppu.init();
        self.timer.init();
    }
    // tick subsystems

    pub fn tick(self: *Bus, tCycles: u32) void {
        // request timer interupt if timer function returns true meaning overflow
        if (self.timer.tick(tCycles)) {
            self.memory.write(0xFF0F, self.memory.read(0xFF0F) | 0b100);
        }
    }

    // MMU

    pub fn write(self: *Bus, address: u16, value: u8) void {
        switch (address) {
            0x0000...0x7FFF => {
                // memory bank switching TODO - maket his work completely and make it into helper functions
                switch (self.cartridge.type) {
                    CartridgeType.MBC1 => {
                        switch (address) {
                            0x0000...0x1FFF => {
                                self.cartridge.ramEnabled = (value & 0x0F) == 0x0A;
                            },
                            0x2000...0x3FFF => {
                                const bankSelect: usize = @max(1, value & 0x1F);
                                self.cartridge.bank = bankSelect;
                                std.debug.print("memory bank {d} in use selected bank: {d}", .{ self.cartridge.bank, bankSelect });
                            },
                            0x4000...0x5FFF => {
                                std.debug.print("higher bits selected", .{});
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
            0xFF02 => {
                // TODO - check this implementation more thourgouhly later now for debugging serial transfer
                if ((value & 0x80) != 0) {
                    const serialBuffer = self.memory.read(0xFF01);
                    std.debug.print("{c}", .{serialBuffer});

                    self.memory.write(address, self.memory.read(address) & ~@as(u8, 0x80));
                }
            },
            0xFF04 => {
                // if write is done to div register [0xFF04] always reset it
                self.timer.div = 0;
                self.timer.sysCount = 0;
            },
            0xFF05 => {
                self.timer.tima = value;
            },
            0xFF06 => {
                self.timer.tma = value;
            },
            0xFF07 => {
                self.timer.tac = value;
            },
            else => {
                self.memory.write(address, value);
            },
        }
    }

    pub fn read(self: *Bus, address: u16) u8 {
        switch (address) {
            0xFF44 => {
                // TODO - for debbuging right now remove this later when the PPU is finished
                return 0x90;
            },
            0x4000...0x7FFF => {
                if (self.cartridge.type != CartridgeType.ROMOnly) {
                    const memoryBank = self.cartridge.bank;
                    return self.memory.rom[memoryBank * 0x4000 + (address - 0x4000)];
                } else {
                    return self.memory.read(address);
                }
            },
            0x8000...0x9FFF => {
                return self.ppu.vram[address - 0x8000];
            },
            0xFE00...0xFE9F => {
                return self.ppu.oam[address - 0xFE00];
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
            else => {
                return self.memory.read(address);
            },
        }
    }

    pub fn loadCartrige(self: *Bus, path: []const u8, allocator: std.mem.Allocator) !void {
        var file = try fs.cwd().openFile(path, .{});
        defer file.close();

        const fileSize = try file.getEndPos();

        self.memory.rom = try allocator.alloc(u8, fileSize);

        _ = try file.readAll(self.memory.rom);

        // TODO - this will work for now for MBC1 but needs more thourough handling down the line since the buffer values
        // won't map on to the enums
        const title: []const u8 = self.memory.rom[0x0134..0x0143];
        const cartridgeType: CartridgeType = @enumFromInt(self.memory.rom[0x147]);
        const romSize: RomSize = @enumFromInt(self.memory.rom[0x0148]);

        var ramSize: RamSize = undefined;
        const ramSizeByte = self.memory.rom[0x0149];
        switch (ramSizeByte) {
            0x00 => {
                ramSize = RamSize.None;
            },
            0x01 => {
                ramSize = RamSize.None;
            },
            0x02 => {
                ramSize = RamSize.KB8;
            },
            0x03 => {
                ramSize = RamSize.KB32;
            },
            0x04 => {
                ramSize = RamSize.KB128;
            },
            0x05 => {
                ramSize = RamSize.KB64;
            },
            else => {},
        }

        const cartridge = try allocator.create(Cartridge);
        cartridge.title = title;
        cartridge.type = cartridgeType;
        // for debugging here
        // std.debug.print("cartridgeType: {s}\n", .{@tagName(cartridgeType)});
        cartridge.romSize = romSize;
        cartridge.ramSize = ramSize;
        cartridge.bank = 1;

        self.cartridge = cartridge;
    }

    pub fn deinitCartridge(self: *Bus, allocator: std.mem.Allocator) void {
        allocator.destroy(self.cartridge);
        allocator.free(self.memory.rom);
    }
};
