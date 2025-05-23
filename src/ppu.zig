const std = @import("std");
const Renderer = @import("renderer.zig").Renderer;

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

    // ppu fields
    cyclesAccumilator: u32,
    pixelBuffer: [144][160]u2,

    // dma fields
    dmaActive: bool,
    dmaCycles: u8,
    dmaSource: u16,

    // renderer
    renderer: *Renderer,

    pub fn init(self: *PPU, renderer: *Renderer) void {
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

        self.cyclesAccumilator = 0;
        self.pixelBuffer = undefined;

        self.dmaActive = false;
        self.dmaCycles = 0;
        self.dmaSource = 0;

        self.renderer = renderer;
    }

    pub fn tick(self: *PPU, tCycles: u32) void {
        self.cyclesAccumilator += tCycles;

        while (self.cyclesAccumilator > 456) {
            self.cyclesAccumilator -= 456;

            if (self.ly == 143) {
                // request interrupt
                self.flagRegister.* |= 1;
            }

            if (self.ly < 144) {
                self.renderBackgroundLine();
                self.renderWindowLine();
            }

            if (self.ly == 154) {
                self.ly = 0;
                self.renderer.renderPixelBuffer(self.pixelBuffer);
            } else {
                self.ly += 1;
            }
        }
    }

    pub fn renderBackgroundLine(self: *PPU) void {
        // current position in the tile map pixel cordinate
        var tempSum: u16 = @as(u16, self.ly) + @as(u16, self.scy);
        const tileMapY: u8 = @intCast(tempSum % 256);

        // current tile row and what corresponding row we are in that tile
        const tileRow = tileMapY / 8;
        const pixelRowInTile = tileMapY % 8;

        // check lcd bit 3 to see where the bg tile map is in memory
        const tileMapBase: u16 = if (self.lcdc & 0b1000 == 0) 0x1800 else 0x1C00;
        // check ldc bit 4 to see what adressing mode should be used for tiles
        const addressingModeSigned = (self.lcdc & 0b10000 == 0);

        for (0..160) |screenX| {
            tempSum = @intCast(screenX + @as(usize, self.scx));
            const tileMapX: u8 = @intCast(tempSum % 256);

            const tileColumn = tileMapX / 8;
            const pixelColumnInTile = tileMapX % 8;

            // get the index of where the tile is in the tile data
            const tileMapIndex: usize = @as(usize, tileRow) * 32 + @as(usize, tileColumn);
            const tileId = self.vram[tileMapBase + tileMapIndex];

            // get the memory adress of the tile we want to render
            const tileDataAddress: u16 = getTileDataAdress(tileId, addressingModeSigned);

            // add the offset of what row in the tile we are in to the address
            const tileRowAddress: u16 = tileDataAddress + (pixelRowInTile * 2);
            const pixel = self.getPixel(tileRowAddress, pixelColumnInTile);

            self.pixelBuffer[self.ly][screenX] = pixel;
        }
    }

    pub fn renderWindowLine(self: *PPU) void {
        // return if bit 5 is not set in lcdc
        if (self.lcdc & 0b100000 == 0) {
            return;
        }

        // if the current scanline is not at the window position return
        if (self.ly < self.wy) {
            return;
        }

        std.debug.print("rendering window line\n", .{});

        // current window line we are rendering
        const windowLine = self.ly - self.wy;

        const tileRow = windowLine / 8;
        const pixelRowInTile = windowLine % 8;

        // check lcdc bit 6 to see where window tile maps start
        var tileMapBase: u16 = undefined;
        if (self.lcdc & 0b1000000 == 0) {
            tileMapBase = 0x1800;
        } else {
            tileMapBase = 0x1C00;
        }

        // check ldc bit 4 to see what adressing mode should be used for tiles
        const addressingModeSigned = (self.lcdc & 0b10000 == 0);

        // Window X coordinate is WX - 7 (hardware quirk)
        const startX: u16 = @as(u16, self.wx) -| 7;

        for (startX..160) |screenX| {
            const windowX = screenX - startX;

            const tileColumn = windowX / 8;
            const pixelColumnInTile = windowX % 8;

            const tileMapIndex: usize = tileRow * 32 + tileColumn;
            const tileId = self.vram[tileMapBase + tileMapIndex];

            // get the memory adress of the tile we want to render
            const tileDataAddress: u16 = getTileDataAdress(tileId, addressingModeSigned);

            // add the offset of what row in the tile we are in to the address
            const tileRowAddress: u16 = tileDataAddress + (pixelRowInTile * 2);
            const pixel = self.getPixel(tileRowAddress, pixelColumnInTile);

            self.pixelBuffer[self.ly][screenX] = pixel;
        }
    }

    fn getTileDataAdress(tileId: u8, addressingModeSigned: bool) u16 {
        // get the memory adress of the tile we want to render
        var tileDataAddress: u16 = undefined;
        if (addressingModeSigned) {
            const signed8: i8 = @bitCast(tileId);
            const signedOffset: i16 = @intCast(signed8);
            tileDataAddress = @intCast(0x1000 + signedOffset * 16);
        } else {
            tileDataAddress = @as(u16, tileId) * 16;
        }

        return tileDataAddress;
    }

    fn getPixel(self: *PPU, tileRowAddress: u16, pixelColumnInTile: usize) u2 {
        const lowByte = self.vram[tileRowAddress];
        const highByte = self.vram[tileRowAddress + 1];

        // get the position of the pixel we are going to render
        const bitPosition = 7 - pixelColumnInTile;
        const bitPositionU3: u3 = @intCast(bitPosition);
        const lowBit: u1 = @truncate(lowByte >> bitPositionU3);
        const highBit: u1 = @truncate(highByte >> bitPositionU3);
        const pixel: u2 = @as(u2, highBit) << 1 | lowBit;

        // palette shift pixel
        const paletteShift = @as(u8, pixel) * 2;
        const paletteShiftU3: u3 = @intCast(paletteShift);
        const mappedPixel: u2 = @truncate(self.bgp >> paletteShiftU3);

        return mappedPixel;
    }
};
