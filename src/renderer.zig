const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub const SdlError = error{
    SdlInitFailed,
};

pub const Renderer = struct {
    window: *c.SDL_Window,
    renderer: *c.SDL_Renderer,
    texture: *c.SDL_Texture,
    scale: c_int,

    pub fn init(self: *Renderer, scale: c_int) !void {
        if (!c.SDL_Init(c.SDL_INIT_VIDEO)) {
            return SdlError.SdlInitFailed;
        }

        // init window
        self.window = c.SDL_CreateWindow("Gameboy Emulator", 160 * scale, 144 * scale, 0) orelse return SdlError.SdlInitFailed;

        // init renderer
        self.renderer = c.SDL_CreateRenderer(self.window, null) orelse return SdlError.SdlInitFailed;

        // init texture used to render the screen
        self.texture = c.SDL_CreateTexture(
            self.renderer,
            c.SDL_PIXELFORMAT_RGB24,
            c.SDL_TEXTUREACCESS_STREAMING,
            160,
            144,
        ) orelse return SdlError.SdlInitFailed;

        // make it so that the renderer streches the textures to the output resolution
        if (!c.SDL_SetRenderLogicalPresentation(self.renderer, 160, 144, c.SDL_LOGICAL_PRESENTATION_STRETCH)) {
            return SdlError.SdlInitFailed;
        }

        if (!c.SDL_SetTextureScaleMode(self.texture, c.SDL_SCALEMODE_NEAREST)) {
            return SdlError.SdlInitFailed;
        }

        self.scale = scale;
    }

    pub fn renderPixelBuffer(self: *Renderer, pixelBuffer: [144][160]u2) void {
        const palette = [4][3]u8{
            [3]u8{ 255, 255, 255 },
            [3]u8{ 191, 191, 191 },
            [3]u8{ 64, 64, 64 },
            [3]u8{ 0, 0, 0 },
        };

        // buffer to store the new rgb values in width * height * 3 (for rgb)
        var rgbBuffer: [160 * 144 * 3]u8 = undefined;

        var i: usize = 0;
        for (pixelBuffer) |row| {
            for (row) |pixel| {
                const color = palette[pixel];
                rgbBuffer[i + 0] = color[0];
                rgbBuffer[i + 1] = color[1];
                rgbBuffer[i + 2] = color[2];
                i += 3;
            }
        }

        // bytes per scanline
        const pitch: c_int = 160 * 3;

        // update texture and render it
        _ = c.SDL_UpdateTexture(self.texture, null, &rgbBuffer[0], pitch);
        _ = c.SDL_RenderClear(self.renderer);
        _ = c.SDL_RenderTexture(self.renderer, self.texture, null, null);
        _ = c.SDL_RenderPresent(self.renderer);
    }

    pub fn deinit(self: *Renderer) void {
        c.SDL_Quit();
        c.SDL_DestroyWindow(self.window);
        c.SDL_DestroyRenderer(self.renderer);
        c.SDL_DestroyTexture(self.texture);
    }
};
