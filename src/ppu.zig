pub const PPU = struct {
    vram: [0x2000]u8,
    oam: [0xA0]u8,

    pub fn init(self: *PPU) void {
        @memset(self.vram[0..], 0);
        @memset(self.oam[0..], 0);
    }
};
