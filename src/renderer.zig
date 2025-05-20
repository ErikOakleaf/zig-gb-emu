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
        self.window = c.SDL_CreateWindow("Gameboy Emulator", 166 * scale, 144 * scale, 0) orelse return SdlError.SdlInitFailed;

        // init renderer
        self.renderer = c.SDL_CreateRenderer(self.window, null) orelse return SdlError.SdlInitFailed;

        // init texture used to render the screen
        self.texture = c.SDL_CreateTexture(
            self.renderer,
            c.SDL_PIXELFORMAT_RGB24,
            c.SDL_TEXTUREACCESS_STREAMING,
            166,
            144,
        ) orelse return SdlError.SdlInitFailed;

        // make it so that the renderer streches the textures to the output resolution
        if (!c.SDL_SetRenderLogicalPresentation(self.renderer, 160, 144, c.SDL_LOGICAL_PRESENTATION_STRETCH)) {
            return SdlError.SdlInitFailed;
        }

        self.scale = scale;
    }

    pub fn deinit(self: *Renderer) void {
        c.SDL_Quit();
        c.SDL_DestroyWindow(self.window);
        c.SDL_DestroyRenderer(self.renderer);
    }
};
