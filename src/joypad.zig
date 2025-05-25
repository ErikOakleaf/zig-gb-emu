const std = @import("std");
const c = @cImport({
    @cInclude("SDL3/SDL.h");
});

const JoypadState = packed struct {
    dpadState: u4,
    buttonState: u4,
};

pub const Joypad = struct {
    joypadState: JoypadState,
    p1: u8,

    flagRegister: *u8,

    pub fn init(self: *Joypad) void {
        self.joypadState.dpadState = 0xF;
        self.joypadState.buttonState = 0xF;
        self.p1 = 0xFF;
    }

    pub fn updateJoypadRegister(self: *Joypad) void {
        const dpadMode = ((self.p1 & (1 << 4)) == 0);
        const buttonMode = ((self.p1 & (1 << 5)) == 0);

        const prevLower = self.p1 & 0x0F;

        if (dpadMode) {
            self.p1 = (self.p1 & 0xF0) | self.joypadState.dpadState;
        } else if (buttonMode) {
            self.p1 = (self.p1 & 0xF0) | self.joypadState.buttonState;
        }

        // fire interrupt on any 1->0 transition in the lower nibble
        const currLower = self.p1 & 0x0F;
        if ((prevLower & ~currLower) != 0) {
            self.flagRegister.* |= (1 << 4);
        }
    }

    pub fn updateJoypadState(self: *Joypad, key: c.SDL_Scancode, pressed: bool) void {
        switch (key) {
            c.SDL_SCANCODE_RIGHT => {
                if (pressed) {
                    self.joypadState.dpadState &= 0b1110;
                } else {
                    self.joypadState.dpadState |= 0b0001;
                }
            },
            c.SDL_SCANCODE_LEFT => {
                if (pressed) {
                    self.joypadState.dpadState &= 0b1101;
                } else {
                    self.joypadState.dpadState |= 0b0010;
                }
            },
            c.SDL_SCANCODE_UP => {
                if (pressed) {
                    self.joypadState.dpadState &= 0b1011;
                } else {
                    self.joypadState.dpadState |= 0b0100;
                }
            },
            c.SDL_SCANCODE_DOWN => {
                if (pressed) {
                    self.joypadState.dpadState &= 0b0111;
                } else {
                    self.joypadState.dpadState |= 0b1000;
                }
            },
            c.SDL_SCANCODE_Z => {
                if (pressed) {
                    self.joypadState.buttonState &= 0b1110;
                } else {
                    self.joypadState.buttonState |= 0b0001;
                }
            },
            c.SDL_SCANCODE_X => {
                if (pressed) {
                    self.joypadState.buttonState &= 0b1101;
                } else {
                    self.joypadState.buttonState |= 0b0010;
                }
            },
            c.SDL_SCANCODE_Q => {
                if (pressed) {
                    self.joypadState.buttonState &= 0b1011;
                } else {
                    self.joypadState.buttonState |= 0b0100;
                }
            },
            c.SDL_SCANCODE_W => {
                if (pressed) {
                    self.joypadState.buttonState &= 0b0111;
                } else {
                    self.joypadState.buttonState |= 0b1000;
                }
            },
            else => {},
        }
    }
};
