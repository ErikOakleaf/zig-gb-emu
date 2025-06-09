const std = @import("std");
pub const BITS: [4]u8 = .{ 9, 3, 5, 7 };

pub const Timer = struct {
    cycles: u32,
    previousCycles: u32,
    overflowDelay: u8,
    div: u8, // 0xFF04
    tima: u8, // 0xFF05
    tma: u8, // 0xFF06
    tac: u8, // 0xFF07
    flagRegister: *u8,

    pub fn init(self: *Timer) void {
        self.cycles = 0;
        self.previousCycles = 0;
        self.overflowDelay = 0;
        self.div = 0;
        self.tima = 0;
        self.tma = 0;
        self.tac = 0;
    }

    pub fn tick(self: *Timer) void {
        self.cycles +%= 1;
        self.updateDiv();

        // if there is a overflow delay decrement it and handle overflow
        if (self.overflowDelay > 0) {
            self.overflowDelay -= 1;
            if (self.overflowDelay == 4) {
                // set TIMA to TMA
                self.tima = self.tma;
                //request interrupt
                self.flagRegister.* |= 0b100;
            }
        } else {
            const enable: bool = (self.tac & 0b100) > 0;
            if (enable) {
                const fallingEdge = self.checkFallingEdge();
                if (fallingEdge) {
                    self.incrementTima();
                }
            }
        }

        self.previousCycles = self.cycles;
    }

    fn updateDiv(self: *Timer) void {
        // update the div register to be the high byte of the cycles
        const newDiv: u8 = @truncate(self.cycles >> 8);
        self.div = newDiv;
    }

    pub fn incrementTima(self: *Timer) void {
        const newTima = @addWithOverflow(self.tima, @as(u8, 1));
        self.tima = newTima[0];

        // check for overflow
        if (newTima[1] == 1) {
            // there is a 4‑cycle delay between TIMA overflow and interrupt
            self.overflowDelay = 8;
            self.tima = 0; // TIMA reads as 0 during this delay period
        }
    }

    fn checkFallingEdge(self: *Timer) bool {
        const clockSelect: u2 = @truncate(self.tac);
        const bit = BITS[@as(usize, clockSelect)];

        const mask: u32 = std.math.shl(u32, 1, bit);
        const oldBit = (self.previousCycles & mask) != 0;
        const newBit = (self.cycles & mask) != 0;

        return oldBit and !newBit;
    }
};
