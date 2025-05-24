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

        self.cyclesAccumilator = 0;
        self.pixelBuffer = undefined;

        self.dmaActive = false;
        self.dmaCycles = 160;
        self.dmaSource = 0;

        self.renderer = renderer;
    }

    pub fn tick(self: *PPU, tCycles: u32) void {
        // check if LCD is enabled
        if (self.lcdc & 1 << 7 == 0) {
            return;
        }

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
                self.renderSpritesLine();
            }

            if (self.ly == 154) {
                self.ly = 0;
                self.renderer.renderPixelBuffer(self.pixelBuffer);
            } else {
                self.ly += 1;
            }
        }

        // self.ppuDebug();
    }

    fn renderBackgroundLine(self: *PPU) void {
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

    fn renderWindowLine(self: *PPU) void {
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
        const tileMapBase: u16 = if (self.lcdc & 0b1000000 == 0) 0x1800 else 0x1C00;

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

    fn renderSpritesLine(self: *PPU) void {
        if (self.lcdc & 0b10 == 0) {
            return;
        }

        const spriteHeight: u8 = if ((self.lcdc & 0b100) != 0) 16 else 8;

        // loop through all sprites in oam
        for (0..40) |i| {
            const spriteIndex = i * 4;

            const spriteY: i16 = @as(i16, @intCast(self.oam[spriteIndex])) - 16; // subtract 16 because y is stored + 16 in memory
            const spriteX: i16 = @as(i16, @intCast(self.oam[spriteIndex + 1])) - 8; // subtract 8 because x is stored + 8 in memory
            const tileIndex: u8 = self.oam[spriteIndex + 2];
            const attributes: u8 = self.oam[spriteIndex + 3];

            // Skip sprite if current scanline is not within vertical bounds
            if (self.ly < spriteY or self.ly >= spriteY + spriteHeight) {
                continue;
            }

            const yFlip = (attributes & 1 << 6) != 0;
            const xFlip = (attributes & 1 << 5) != 0;
            const palette = if ((attributes & 1 << 4) != 0) self.obp1 else self.obp0;

            const pixelRowInTile = if (yFlip) spriteHeight - 1 - (self.ly - spriteY) else (self.ly - spriteY);
            const tileRowAddress = @as(u16, tileIndex) * 16 + @as(u16, @intCast(pixelRowInTile)) * 2;
            const lowByte = self.vram[tileRowAddress];
            const highByte = self.vram[tileRowAddress + 1];

            for (0..8) |pixelX| {
                const screenX = spriteX + @as(i8, @intCast(pixelX));
                if (screenX >= 160 or screenX < 0) {
                    continue;
                }

                const bitIndex = if (xFlip) pixelX else 7 - pixelX;
                const bitIndexU3: u3 = @intCast(bitIndex);

                const lowBit: u1 = @truncate(lowByte >> bitIndexU3);
                const highBit: u1 = @truncate(highByte >> bitIndexU3);
                const pixel: u2 = @as(u2, highBit) << 1 | lowBit;

                if (pixel == 0) continue; // transparent pixel

                const paletteShift = @as(u8, pixel) * 2;
                const paletteShiftU3: u3 = @intCast(paletteShift);
                const mappedPixel: u2 = @truncate(palette >> paletteShiftU3);

                // Priority: always draw over background for now
                self.pixelBuffer[self.ly][@as(usize, @intCast(screenX))] = mappedPixel;
            }
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

    // TODO - remove this later when not needed
    fn ppuDebug(self: *PPU) void {
        for (self.vram) |element| {
            if (element != 0) {
                std.debug.print("vram has loaded bit\n", .{});
                return;
            }
        }
        std.debug.print("vram has not loaded any bits\n", .{});

        if (self.bgp == 0) {
            std.debug.print("bgp is blank\n", .{});
        }

        if (self.obp0 == 0) {
            std.debug.print("obp0 is blank\n", .{});
        }

        if (self.obp0 == 1) {
            std.debug.print("obp1 is blank\n", .{});
        }
    }
};
