const std = @import("std");
const Renderer = @import("renderer.zig").Renderer;

const MAX_SPRITES_PER_LINE = 10;

pub const PPUMode = enum {
    OAMSearch,
    PixelTransfer,
    HBlank,
    VBlank,
};

const Sprite = struct {
    xPosition: u8,
    oamIndex: u8,
    tileRow: u8,
};

const SpriteBuffer = struct {
    spriteCount: u8,
    buffer: [10]Sprite,
};

pub const PPU = struct {
    // memory
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

    // lcdc control fields
    enabled: bool,
    windowTileMapArea: bool,
    windowEnable: bool,
    bgWindowTileDataArea: bool,
    bgTileMapArea: bool,
    objSize: bool,
    objEnable: bool,
    bgEnable: bool,

    // ppu fields
    cycles: u32,
    ppuMode: PPUMode,
    spriteBuffer: SpriteBuffer,
    pixelBuffer: [144][160]u2,
    backgroundFifo: [16]u2,
    objectFifo: [16]u2,

    // dma fields
    dmaActive: bool,
    dmaCycles: u16,
    dmaSource: u16,

    // renderer
    renderer: *Renderer,

    pub fn init(self: *PPU, renderer: *Renderer) void {
        @memset(self.vram[0..], 0);
        @memset(self.oam[0..], 0);
        self.lcdc = 0x91;
        self.stat = 0;
        self.scy = 0;
        self.scx = 0;
        self.ly = 0;
        self.lyc = 0;
        self.dma = 0;
        self.bgp = 0;
        self.obp0 = 0xFF;
        self.obp1 = 0xFF;
        self.wy = 0;
        self.wx = 14;

        self.enabled = false;
        self.windowTileMapArea = false;
        self.windowEnable = false;
        self.bgWindowTileDataArea = false;
        self.bgTileMapArea = false;
        self.objSize = false;
        self.objEnable = false;
        self.bgEnable = false;

        self.cycles = 0;
        self.ppuMode = PPUMode.OAMSearch;
        self.spriteBuffer = undefined;
        self.pixelBuffer = undefined;
        self.backgroundFifo = undefined;
        self.objectFifo = undefined;

        self.dmaActive = false;
        self.dmaCycles = 160;
        self.dmaSource = 0;

        self.renderer = renderer;
    }

    pub fn tick(self: *PPU) void {
        if (!self.enabled) {
            return;
        }

        self.cycles +%= 1;

        switch (self.ppuMode) {
            PPUMode.OAMSearch => {
                if (self.cycles >= 80) {
                    self.cycles -= 80;
                    self.ppuMode = PPUMode.PixelTransfer;
                }
            },
            PPUMode.PixelTransfer => {},
            PPUMode.HBlank => {},
            PPUMode.VBlank => {},
        }
    }

    fn scanOamLine(self: *PPU) void {
        var spriteCount = 0;
        var i = 0;
        while (i < self.oam.len and spriteCount < 10) : (i += 4) {
            const spriteHeight = if (self.objSize) 16 else 8;

            const scanlineBelowOrAtTop = self.ly + 16 >= self.oam[i];
            const scanlineAboveBottom = self.ly + 16 < self.oam[i] + spriteHeight;
            const isVisible = self.oam[i + 1] > 0;

            if (scanlineBelowOrAtTop and scanlineAboveBottom and isVisible) {
                self.spriteBuffer.buffer[spriteCount] = Sprite{
                    .xPosition = self.oam[i + 1],
                    .oamIndex = i,
                    .tileRow = self.ly + 16 - self.oam[i],
                };
                spriteCount += 1;
            }
        }

        self.spriteBuffer.spriteCount = spriteCount;
    }

    pub fn writeLCDC(self: *PPU, value: u8) void {
        self.lcdc = value;

        self.enabled = value & (1 << 7) != 0;
        self.windowTileMapArea = value & (1 << 6) != 0;
        self.windowEnable = value & (1 << 5) != 0;
        self.bgWindowTileDataArea = value & (1 << 4) != 0;
        self.bgTileMapArea = value & (1 << 3) != 0;
        self.objSize = value & (1 << 2) != 0;
        self.objEnable = value & (1 << 1) != 0;
        self.bgEnable = value & (1 << 0) != 0;
    }
};
