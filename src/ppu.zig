const std = @import("std");
const Renderer = @import("renderer.zig").Renderer;

const MAX_SPRITES_PER_LINE = 10;

pub const PPUMode = enum {
    OAMSearch,
    PixelTransfer,
    HBlank,
    VBlank,
};

const Fifo = struct {
    queue: Queue(u2, 16),
    cycles: u16,
    fetcherX: u8,
    windowX: u8,
    windowY: u8,
    incrementWindowY: bool,
    currentTileAddress: u16,
    dataLow: u8,
    dataHigh: u8,
    usingWindow: bool,
};

const Sprite = struct {
    xPosition: u8,
    attributes: u8,
    tileIndex: u8,
    tileRow: u8,
};

fn Queue(comptime T: type, size: u8) type {
    return struct {
        data: [size]T,
        head: u8,
        tail: u8,
        count: u8,

        fn push(self: *Queue(T, size), item: T) void {
            if (self.count >= 16) {
                return;
            }
            self.data[self.tail] = item;
            self.tail = (self.tail + 1) & 15;
            self.count += 1;
        }

        fn pop(self: *Queue(T, size)) T {
            if (self.count == 0) {
                return 0; // for now just return 0 as a placeholder for nothing maybe should return null in the future
            }
            const pixel = self.data[self.head];
            self.head = (self.head + 1) & 15;
            self.count -= 1;
            return pixel;
        }

        fn clear(self: *Queue(T, size)) void {
            self.data = undefined;
            self.head = 0;
            self.tail = 0;
            self.count = 0;
        }
    };
}

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
    spriteBuffer: Queue(Sprite, 10),
    pixelBuffer: [144][160]u2,
    scanlineX: u8,
    pixelsToDiscard: u8,

    // fifo fields
    bgFifo: Fifo,
    objFifo: Fifo,

    // dma fields
    dmaActive: bool,
    dmaCycles: u16,
    dmaCountdown: u8,
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
        self.scanlineX = 0;
        self.pixelsToDiscard = 0;

        self.bgFifo = Fifo{
            .queue = undefined,
            .cycles = 0,
            .fetcherX = 0,
            .windowX = 0,
            .windowY = 0,
            .incrementWindowY = false,
            .currentTileAddress = undefined,
            .dataHigh = undefined,
            .dataLow = undefined,
            .usingWindow = false,
        };
        self.bgFifo.queue.clear();
        self.objFifo = Fifo{
            .queue = undefined,
            .cycles = 0,
            .fetcherX = 0,
            .windowX = 0,
            .windowY = 0,
            .incrementWindowY = false,
            .currentTileAddress = undefined,
            .dataHigh = undefined,
            .dataLow = undefined,
            .usingWindow = false,
        };
        self.objFifo.queue.clear();

        self.dmaActive = false;
        self.dmaCycles = 160;
        self.dmaSource = 0;

        self.renderer = renderer;
    }

    pub fn tick(self: *PPU) void {
        if (!self.enabled) {
            return;
        }

        self.cycles += 1;

        switch (self.ppuMode) {
            PPUMode.OAMSearch => {
                if (self.cycles >= 80) {
                    self.scanOamLine();
                    self.setMode(PPUMode.PixelTransfer);
                    self.bgFifo.cycles = 0;
                    self.pixelsToDiscard = self.scx & 0x07;
                }
            },
            PPUMode.PixelTransfer => {
                if (self.scanlineX >= 160) {
                    self.setMode(PPUMode.HBlank);
                    // Reset for next scanline
                    self.bgFifo.queue.clear();
                    self.bgFifo.fetcherX = 0;
                    self.scanlineX = 0;
                } else {
                    self.pixelTransferFifo();
                }
            },
            PPUMode.HBlank => {
                if (self.cycles >= 456) {
                    self.incrementLy();
                    self.cycles = 0;

                    if (self.ly < 144) {
                        self.setMode(PPUMode.OAMSearch);
                    } else if (self.ly == 144) {
                        self.setMode(PPUMode.VBlank);
                        self.renderer.renderPixelBuffer(self.pixelBuffer);
                        self.flagRegister.* |= 1;
                    }
                }
            },
            PPUMode.VBlank => {
                if (self.cycles != 0 and self.cycles % 456 == 0) {
                    self.incrementLy();
                }

                if (self.cycles == 4560) {
                    self.ly = 0;
                    self.bgFifo.windowY = 0;
                    self.bgFifo.incrementWindowY = false;
                    self.cycles = 0;
                    self.setMode(PPUMode.OAMSearch);
                }
            },
        }
    }

    fn scanOamLine(self: *PPU) void {
        self.spriteBuffer.clear();
        var i: u8 = 0;
        while (i < self.oam.len and self.spriteBuffer.count < 10) : (i += 4) {
            const spriteHeight: u8 = if (self.objSize) 16 else 8;

            const scanlineBelowOrAtTop = self.ly + 16 >= self.oam[i];
            const scanlineAboveBottom = self.ly + 16 < self.oam[i] + spriteHeight;
            const isVisible = self.oam[i + 1] > 0;

            if (scanlineBelowOrAtTop and scanlineAboveBottom and isVisible) {
                const sprite = Sprite{
                    .xPosition = self.oam[i + 1],
                    .attributes = self.oam[i + 3],
                    .tileIndex = self.oam[i + 2],
                    .tileRow = self.ly + 16 - self.oam[i],
                };
                self.spriteBuffer.push(sprite);
            }
        }
    }

    fn pixelTransferFifo(self: *PPU) void {
        self.tickBgFifo();
        // self.tickObjFifo();

        if (self.bgFifo.queue.count > 0) {
            self.popPixel();
        }
    }

    // pixel fifo functions

    inline fn tickBgFifo(self: *PPU) void {
        self.bgFifo.cycles += 1;

        // check if the window is in use

        const wasUsingWindow = self.bgFifo.usingWindow;
        self.bgFifo.usingWindow = self.windowEnable and self.scanlineX >= (self.wx - 7) and self.ly >= self.wy;

        // If we just enterd window mode we clear the fifo and reset the fifo
        if (self.bgFifo.usingWindow and !wasUsingWindow) {
            self.bgFifo.queue.clear();
            self.bgFifo.cycles = 0;
            self.bgFifo.windowX = 0;
            self.bgFifo.cycles = 0;
            self.pixelsToDiscard = 0;
        }

        if (self.bgFifo.cycles == 6) {
            self.fetchBgTile();
            self.bgFifo.dataLow = self.vram[self.bgFifo.currentTileAddress];
            self.bgFifo.dataHigh = self.vram[self.bgFifo.currentTileAddress + 1];
        } else if (self.bgFifo.queue.count <= 8 and self.bgFifo.cycles > 6) {
            self.pushPixels();
            if (self.bgFifo.usingWindow) {
                self.bgFifo.windowX += 1;
            } else {
                self.bgFifo.fetcherX += 1;
            }
            self.bgFifo.cycles = 0;
        }
    }

    inline fn fetchBgTile(self: *PPU) void {
        var tileColumn: u8 = undefined;
        var tileRow: u8 = undefined;
        var pixelRowInTile: u8 = undefined;

        if (self.bgFifo.usingWindow) {
            tileColumn = self.bgFifo.windowX & 0x1F;
            tileRow = (self.bgFifo.windowY / 8) & 0x1F;
            pixelRowInTile = self.bgFifo.windowY & 0x07;
            self.bgFifo.incrementWindowY = true;
        } else {
            tileColumn = ((self.scx / 8) +% self.bgFifo.fetcherX) & 0x1F;
            tileRow = ((self.ly +% self.scy) / 8) & 0x1F;
            pixelRowInTile = (self.ly +% self.scy) & 0x07;
        }

        const tileMapBaseAddress: u16 = if (self.bgFifo.usingWindow)
            (if (self.windowTileMapArea) @as(u16, 0x1C00) else @as(u16, 0x1800))
        else
            (if (self.bgTileMapArea) @as(u16, 0x1C00) else @as(u16, 0x1800));

        const tileMapAddress: u16 = tileMapBaseAddress + (@as(u16, @intCast(tileRow)) * 32) + tileColumn;
        const tileId = self.vram[tileMapAddress];

        const tileDataBaseAddress: u16 = if (self.bgWindowTileDataArea) 0x0000 else 0x1000;

        var address: u16 = undefined;
        if (self.bgWindowTileDataArea) {
            address = tileDataBaseAddress + (@as(u16, @intCast(tileId)) * 16) + (pixelRowInTile * 2);
        } else {
            const signedTileId: i8 = @bitCast(tileId);
            const addressSigned: i32 = @as(i32, @intCast(tileDataBaseAddress)) + (@as(i16, @intCast(signedTileId)) * 16) + (pixelRowInTile * 2);
            address = @intCast(addressSigned);
        }

        self.bgFifo.currentTileAddress = address;
    }

    inline fn pushPixels(self: *PPU) void {
        for (0..8) |i| {
            const bitPosition: u3 = @intCast(7 - i);
            const highBit: u1 = @truncate(self.bgFifo.dataHigh >> bitPosition);
            const lowBit: u1 = @truncate(self.bgFifo.dataLow >> bitPosition);
            const pixel: u2 = @as(u2, highBit) << 1 | lowBit;
            self.bgFifo.queue.push(pixel);
        }
    }

    inline fn popPixel(self: *PPU) void {
        const rawPixel: u3 = @as(u3, @intCast(self.bgFifo.queue.pop())) * 2;

        // if there is a pixel to discard don't add it to the pixel buffer
        if (self.pixelsToDiscard > 0) {
            self.pixelsToDiscard -= 1;
            return;
        }

        const palletteShiftedPixel: u2 = @truncate(self.bgp >> rawPixel);
        self.pixelBuffer[self.ly][self.scanlineX] = palletteShiftedPixel;
        self.scanlineX += 1;
    }

    // misc helper functions

    inline fn setMode(self: *PPU, mode: PPUMode) void {
        self.ppuMode = mode;
        self.stat &= 0xFC;
        switch (mode) {
            PPUMode.OAMSearch => {
                self.stat |= 2;
            },
            PPUMode.PixelTransfer => {
                self.stat |= 3;
            },
            PPUMode.HBlank => {
                self.stat |= 0;
            },
            PPUMode.VBlank => {
                self.stat |= 1;
            },
        }

        // interrupt handling

    }

    fn incrementLy(self: *PPU) void {
        self.ly += 1;
        if (self.bgFifo.incrementWindowY) {
            self.bgFifo.windowY += 1;
        }

        // check LYC = LY coincidence and fire interupt
        if (self.ly == self.lyc) {
            self.stat |= (1 << 2);
            if (self.stat & (1 << 6) != 0) {
                self.flagRegister.* |= (1 << 1);
            }
        } else {
            self.stat &= ~@as(u8, (1 << 2));
        }
    }

    // for memory

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
