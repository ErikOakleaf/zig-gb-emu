pub const Memory = struct {
    rom: [0x8000]u8,
    vram: [0x2000]u8,
    eram: [0x2000]u8,
    wram: [0x2000]u8,
    oam: [0xA0]u8,
    io: [0x80]u8,
    hram: [0x7F]u8,
    ie: u8,

    pub fn read(self: *Memory, address: u16) u8 {
        switch (address) {
            0x00...0x7FFF => {
                return self.rom[address];
            },
            0x8000...0x9FFF => {
                return self.vram[address - 0x8000];
            },
            0xA000...0xBFFF => {
                return self.eram[address - 0xA000];
            },
            0xC000...0xDFFF => {
                return self.wram[address - 0xC000];
            },
            // echo ram so mirror C000-DDFF here
            0xE000...0xFDFF => {
                return self.wram[address - 0xE000];
            },
            0xFE00...0xFE9F => {
                return self.oam[address - 0xFE00];
            },
            0xFEA0...0xFEFF => {
                return 0xFF;
            },
            0xFF00...0xFF7F => {
                return self.io[address - 0xFF00];
            },
            0xFF80...0xFFFE => {
                return self.hram[address - 0xFF80];
            },
            0xFFFF => {
                return self.ie;
            },
            else => {},
        }
    }

    pub fn write(self: *Memory, address: u16, value: u8) void {
        switch (address) {
            0x00...0x7FFF => {
                // cannot write read only memory
            },
            0x8000...0x9FFF => {
                self.vram[address - 0x8000] = value;
            },
            0xA000...0xBFFF => {
                self.eram[address - 0xA000] = value;
            },
            0xC000...0xDFFF => {
                self.wram[address - 0xC000] = value;
            },
            // echo ram so mirror C000-DDFF here
            0xE000...0xFDFF => {
                self.wram[address - 0xE000] = value;
            },
            0xFE00...0xFE9F => {
                self.oam[address - 0xFE00] = value;
            },
            0xFF00...0xFF7F => {
                self.io[address - 0xFF00] = value;
            },
            0xFF80...0xFFFE => {
                self.hram[address - 0xFF80] = value;
            },
            0xFFFF => {
                self.ie = value;
            },
            else => {},
        }
    }
};
