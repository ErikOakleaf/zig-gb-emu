pub const PPU = struct {
    vram: [0x2000]u8, // 0x8000 - 0x9FFF
    oam: [0xA0]u8, // 0xFE00 - 0xFE9F

    lcdc: u8, // 0xFF40
    stat: u8, // 0xFF41
    scy: u8, // 0xFF42
    scx: u8, // 0xFF43
    ly: u8, // 0xFF44
    lyc: u8, // 0xFF45
    dma: u8, // 0xFF46
    bgp: u8, // 0xFF47
    obp0: u8, // 0xFF48
    obp1: u8, // 0xFF49
    wy: u8, // 0xFF4A
    wx: u8, // 0xFF4B

    flagRegister: *u8, // reference to FF0F

    pub fn init(self: *PPU) void {
        @memset(self.vram[0..], 0);
        @memset(self.oam[0..], 0);
        self.lcdc = 0;
        self.stat = 0;
        self.scy = 0;
        self.scx = 0;
        self.ly = 0;
        self.lyc = 0;
        self.dma = 0;
        self.bgp = 0;
        self.obp0 = 0;
        self.obp1 = 0;
        self.wy = 0;
        self.wx = 0;
    }
};
