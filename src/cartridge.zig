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
    title: []const u8,
    type: CartridgeType,
    romSize: RomSize,
    ramSize: RamSize,
    ramEnabled: bool,
    bank: u8,
};
