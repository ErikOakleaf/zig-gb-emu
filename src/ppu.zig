const std = @import("std");
const Renderer = @import("renderer.zig").Renderer;

const MAX_SPRITES_PER_LINE = 10;

pub const PPUMode = enum {
    OAMSearch,
    PixelTransfer,
    HBlank,
    VBlank,
};

const FifoPhase = enum {
    FetchTile,
    GetTileDataLow,
    GetTileDataHigh,
    Sleep,
    PushPixels,
};

const FifoState = struct {
    phase: FifoPhase,
    fetcherX: u8,
    windowX: u8,
    windowY: u8,
    incrementWindowY: bool,
    currentTileAddress: u16,
    dataLow: u8,
    dataHigh: u8,
};

const Sprite = struct {
    xPosition: u8,
    attributes: u8,
    tileIndex: u8,
    tileRow: u8,
};

const SpriteBuffer = struct {
    spriteCount: u8,
    buffer: [10]Sprite,
};

const Queue = struct {
    data: [16]u2,
    head: u8,
    tail: u8,
    count: u8,

    fn push(self: *Queue, pixel: u2) void {
        if (self.count >= 16) {
            return;
        }
        self.data[self.tail] = pixel;
        self.tail = (self.tail + 1) % 16;
        self.count += 1;
    }

    fn pop(self: *Queue) u8 {
        if (self.count == 0) {
            return 0; // for now just return 0 as a placeholder for nothing maybe should return null in the future
        }
        const pixel = self.data[self.head];
        self.head = (self.head + 1) % 16;
        self.count -= 1;
        return pixel;
    }
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
    scanlineX: u8,

    // fifo fields
    bgFifo: Queue,
    objFifo: Queue,
    fifoState: FifoState,
    fifoCycles: u16,

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
        self.scanlineX = 0;

        self.bgFifo = Queue{ .data = undefined, .count = 0, .head = 0, .tail = 0 };
        self.objFifo = Queue{ .data = undefined, .count = 0, .head = 0, .tail = 0 };
        self.fifoState = FifoState{
            .phase = FifoPhase.FetchTile,
            .fetcherX = 0,
            .windowX = 0,
            .windowY = 0,
            .incrementWindowY = false,
            .currentTileAddress = undefined,
            .dataHigh = undefined,
            .dataLow = undefined,
        };
        self.fifoCycles = 0;

        self.dmaActive = false;
        self.dmaCycles = 160;
        self.dmaSource = 0;

        self.renderer = renderer;
    }

    pub fn tick(self: *PPU) void {
        if (!self.enabled) {
            return;
        }

        switch (self.ppuMode) {
            PPUMode.OAMSearch => {
                // TODO - maybe implement something to do with dma here.
                self.oamSearch();
            },
            PPUMode.PixelTransfer => {
                self.pixelTransfer();
            },
            PPUMode.HBlank => {},
            PPUMode.VBlank => {},
        }

        self.cycles +%= 1;
    }

    inline fn oamSearch(self: *PPU) void {
        if (self.cycles >= 80) {
            self.cycles -= 80;
            self.scanOamLine();
            self.ppuMode = PPUMode.PixelTransfer;
        }
    }

    fn pixelTransfer(self: *PPU) void {
        self.fifoCycles += 1;

        // fifo
        switch (self.fifoState.phase) {
            FifoPhase.FetchTile => {
                if (self.fifoCycles == 2) {
                    self.fetchTile();
                    self.fifoCycles -= 2;
                    self.fifoState.phase = FifoPhase.GetTileDataLow;
                }
            },
            FifoPhase.GetTileDataLow => {
                if (self.fifoCycles == 2) {
                    self.fifoState.dataLow = self.vram[self.fifoState.currentTileAddress];
                    self.fifoCycles -= 2;
                    self.fifoState.phase = FifoPhase.GetTileDataHigh;
                }
            },
            FifoPhase.GetTileDataHigh => {
                if (self.fifoCycles == 2) {
                    self.fifoState.dataHigh = self.vram[self.fifoState.currentTileAddress + 1];
                    self.fifoCycles -= 2;
                    self.fifoState.phase = FifoPhase.PushPixels;
                }
            },
            FifoPhase.PushPixels => {
                // try to do something every fifoCycle
            },
            FifoPhase.Sleep => {
                if (self.fifoCycles == 2) {
                    // do something here
                    self.fifoCycles -= 2;
                }
            },
        }
    }

    fn scanOamLine(self: *PPU) void {
        var spriteCount: u8 = 0;
        var i: u8 = 0;
        while (i < self.oam.len and spriteCount < 10) : (i += 4) {
            const spriteHeight: u8 = if (self.objSize) 16 else 8;

            const scanlineBelowOrAtTop = self.ly + 16 >= self.oam[i];
            const scanlineAboveBottom = self.ly + 16 < self.oam[i] + spriteHeight;
            const isVisible = self.oam[i + 1] > 0;

            if (scanlineBelowOrAtTop and scanlineAboveBottom and isVisible) {
                self.spriteBuffer.buffer[spriteCount] = Sprite{
                    .xPosition = self.oam[i + 1],
                    .attributes = self.oam[i + 3],
                    .tileIndex = self.oam[i + 2],
                    .tileRow = self.ly + 16 - self.oam[i],
                };
                spriteCount += 1;
            }
        }

        self.spriteBuffer.spriteCount = spriteCount;
    }

    // pixel fifo functions
    fn fetchTile(self: *PPU) void {
        const usingWindow = self.windowEnable and self.scanlineX >= (self.wx - 7) and self.ly >= self.wy;

        var tileColumn: u8 = undefined;
        var tileRow: u8 = undefined;
        var pixelRowInTile: u8 = undefined;

        if (usingWindow) {
            tileColumn = self.fifoState.windowX & 0x1F;
            tileRow = (self.fifoState.windowY / 8) & 0x1F;
            pixelRowInTile = self.fifoState.windowY & 0x07;
            self.fifoState.incrementWindowY = true;
        } else {
            tileColumn = ((self.scx / 8) +% self.fifoState.fetcherX) & 0x1F;
            tileRow = ((self.ly +% self.scy) / 8) & 0x1F;
            pixelRowInTile = (self.ly +% self.scy) & 0x07;
        }

        const tileMapBaseAddress: u16 = if (usingWindow)
            (if (self.windowTileMapArea) @as(u16, 0x1C00) else @as(u16, 0x1800))
        else
            (if (self.bgTileMapArea) @as(u16, 0x1C00) else @as(u16, 0x1800));

        const tileMapAddress = tileMapBaseAddress + (tileRow * 32) + tileColumn;
        const tileId = self.vram[tileMapAddress];

        const tileDataBaseAddress: u16 = if (self.bgWindowTileDataArea) 0x0000 else 0x0800;

        var address: u16 = undefined;
        if (self.bgWindowTileDataArea) {
            address = tileDataBaseAddress + (tileId * 16) + (pixelRowInTile * 2);
        } else {
            const signedTileId: i8 = @bitCast(tileId);
            const addressSigned: i32 = @as(i32, @intCast(tileDataBaseAddress)) + (signedTileId * 16) + (pixelRowInTile * 2);
            address = @intCast(addressSigned);
        }

        self.fifoState.currentTileAddress = address;
    }

    fn pushPixels(self: *PPU) bool {
        // push bg / window fifo pixels
        if (self.bgFifo.count <= 8) {
            for (0..8) |i| {
                const bitPosition: u3 = @intCast(7 - i);
                const highBit: u1 = @truncate(self.fifoState.dataHigh >> bitPosition);
                const lowBit: u1 = @truncate(self.fifoState.dataLow >> bitPosition);
                const pixel: u2 = @as(u2, highBit) << 1 | lowBit;
                self.bgFifo.push(pixel);
            }
        }
        return false;
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
