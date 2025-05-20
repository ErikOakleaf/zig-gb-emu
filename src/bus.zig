const std = @import("std");
const fs = std.fs;
const Memory = @import("memory.zig").Memory;
const Timer = @import("timer.zig").Timer;
const Cartridge = @import("cartridge.zig").Cartridge;
const CartridgeType = @import("cartridge.zig").CartridgeType;
const RomSize = @import("cartridge.zig").RomSize;
const RamSize = @import("cartridge.zig").RamSize;

// define constants
const BITS: [4]u8 = .{ 9, 3, 5, 7 };

pub const Bus = struct {
    memory: *Memory,
    timer: *Timer,
    cartridge: *Cartridge,

    // Init functions

    pub fn init(self: *Bus, memory: *Memory, timer: *Timer) void {
        self.memory = memory;
        self.timer = timer;
        self.memory.init();
        self.initTimer();
    }

    pub fn initTimer(self: *Bus) void {
        self.timer.sysCount = 0;

        self.memory.write(0xFF04, 0);
        self.memory.write(0xFF05, 0);
        self.memory.write(0xFF06, 0);
        self.memory.write(0xFF07, 0);
    }

    // Timer functions

    pub fn tickTimer(self: *Bus, tCycles: u32) void {
        // if there is a overflow delay decrement it and handle overflow
        if (self.timer.overflowDelay > 0) {
            const toConsume = @min(self.timer.overflowDelay, tCycles);
            self.timer.overflowDelay -= toConsume;
            if (self.timer.overflowDelay == 0) {
                self.handleOverflow();
            }
        }

        self.incrementTima(tCycles);
        self.timer.sysCount +%= tCycles;
        self.updateDiv();
    }

    fn updateDiv(self: *Bus) void {
        // update the div register to be the high byte of the sysCount
        const newDiv: u8 = @truncate(self.timer.sysCount >> 8);
        self.memory.write(0xFF04, newDiv);
    }

    fn incrementTima(self: *Bus, tCycles: u32) void {
        const TAC: u8 = self.memory.read(0xFF07);
        const enable: bool = (TAC & 0b100) > 0;
        const clockSelect: u2 = @truncate(TAC);

        if (enable) {
            const bit = BITS[@as(usize, clockSelect)];

            const fallingEdges: u8 = checkFallingEdges(self.timer.sysCount, tCycles, bit);

            // read the current time
            const currentValue: u8 = self.memory.read(0xFF05);

            // check for overflow
            if (currentValue >= 0xFF - fallingEdges) {
                // there is a 4‑cycle delay between TIMA overflow and interrupt
                self.timer.overflowDelay = 4;
                self.memory.write(0xFF05, 0x00); // TIMA reads as 0 during this delay period
            } else {
                self.memory.write(0xFF05, currentValue + fallingEdges);
            }
        }
    }

    fn checkFallingEdges(old: u32, tCycles: u32, bit: u8) u8 {
        // this is equivalent to 2^(bit + 1)
        const period: u32 = std.math.shl(u32, 1, bit + 1); // one full cycle for the given bit
        const halfPeriod: u32 = std.math.shl(u32, 1, bit); // half a cycle for the given bit
        const oldPosition = old & (period - 1); // old % period. This is were we are right now in a cycle
        const total = oldPosition + tCycles;
        const newPosition = total & (period - 1);

        // calculate the full wraps. Simple enough just see how many times the total value fits in the period
        const fullWraps: u8 = @truncate(total / period);

        // if the old position is lagrer than a half period and the new position is smaller it means we have a partial
        // wrap around since they combined become >= one period
        var partialWraps: u8 = 0;
        if (oldPosition >= halfPeriod and newPosition < halfPeriod) {
            partialWraps = 1;
        }

        return fullWraps + partialWraps;
    }

    fn handleOverflow(self: *Bus) void {
        // set TIMA to TMA
        self.memory.write(0xFF05, self.memory.read(0xFF06));

        // request timer interupt
        self.memory.write(0xFF0F, self.memory.read(0xFF0F) | 0b100);
    }

    // MMU

    pub fn write(self: *Bus, address: u16, value: u8) void {
        // if write is done to div register [0xFF04] always reset it
        if (address == 0xFF04) {
            self.memory.write(0xFF04, 0);
            self.timer.sysCount = 0;
            return;
        }

        // serial transfer register
        if (address == 0xFF02) {
            // TODO - check this implementation more thourgouhly later now for debugging serial transfer
            if ((value & 0x80) != 0) {
                const serialBuffer = self.memory.read(0xFF01);
                std.debug.print("{c}", .{serialBuffer});

                self.memory.write(address, self.memory.read(address) & ~@as(u8, 0x80));
            }
            return;
        }

        // handle memory bank switching
        if (address < 0x8000) {
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

            return;
        }

        self.memory.write(address, value);
    }

    pub fn read(self: *Bus, address: u16) u8 {
        // TODO - for debbuging right now remove this later when the PPU is finished
        if (address == 0xFF44) {
            return 0x90;
        }

        // handle reading from switching rom banks
        if (address < 0x8000 and address > 0x3FFF) {
            if (self.cartridge.type != CartridgeType.ROMOnly) {
                const memoryBank = self.cartridge.bank;
                return self.memory.rom[memoryBank * 0x4000 + (address - 0x4000)];
            }
        }

        return self.memory.read(address);
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
