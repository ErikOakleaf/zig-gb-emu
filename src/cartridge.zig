const std = @import("std");
const fs = std.fs;

pub const CartridgeType = enum {
    ROMOnly,
    MBC1,
    MBC2,
    MBC3,
    MBC4,
    MBC5,
};

pub const RomSize = enum {
    KB_32,
    KB_64,
    KB_128,
    KB_256,
    KB_512,
    MB_1,
    MB_2,
    MB_4,
    MB_8,
};

pub const RamSize = enum {
    None,
    KB2,
    KB8,
    KB32,
    KB128,
    KB64,
};

pub const Cartridge = struct {
    rom: []u8,
    ram: []u8,
    title: []const u8,
    type: CartridgeType,
    romSize: RomSize,
    ramSize: RamSize,
    ramEnabled: bool,
    bank: usize,

    pub fn load(self: *Cartridge, path: []const u8, allocator: std.mem.Allocator) !void {
        var file = try fs.cwd().openFile(path, .{});
        defer file.close();

        const fileSize = try file.getEndPos();

        self.rom = try allocator.alloc(u8, fileSize);

        _ = try file.readAll(self.rom);

        // TODO - this will work for now for MBC1 but needs more thourough handling down the line since the
        // buffer values won't map on to the enums
        const title: []const u8 = self.rom[0x0134..0x0143];
        const cartridgeType: CartridgeType = @enumFromInt(self.rom[0x147]);
        const romSize: RomSize = @enumFromInt(self.rom[0x0148]);

        var ramSize: RamSize = undefined;
        const ramSizeByte = self.rom[0x0149];
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

        self.title = title;
        self.type = cartridgeType;
        // for debugging here
        // std.debug.print("cartridgeType: {s}\n", .{@tagName(cartridgeType)});
        self.romSize = romSize;
        self.ramSize = ramSize;
        self.bank = 1;
    }

    pub fn deinit(self: *Cartridge, allocator: std.mem.Allocator) void {
        allocator.free(self.rom);
        // allocator.free(self.ram);
    }
};
