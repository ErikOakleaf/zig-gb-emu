const std = @import("std");
pub const BITS: [4]u8 = .{ 9, 3, 5, 7 };

pub const Timer = struct {
    enabled: bool,
    cycles: u16,
    previousCycles: u16,
    overflow: bool,
    overflowCycles: u8,
    div: u8, // 0xFF04
    tima: u8, // 0xFF05
    tma: u8, // 0xFF06
    tac: u8, // 0xFF07
    flagRegister: *u8,

    pub fn init(self: *Timer) void {
        self.enabled = false;
        self.cycles = 0;
        self.previousCycles = 0;
        self.overflow = false;
        self.overflowCycles = 0;
        self.div = 0;
        self.tima = 0;
        self.tma = 0;
        self.tac = 0;
    }

    pub fn tick(self: *Timer) void {
        self.cycles +%= 1;
        self.updateDiv();

        // if there is a overflow increment overflowcycles and handle overflow
        if (self.overflow or self.overflowCycles > 0) {
            self.overflowCycles += 1;

            if (self.overflowCycles == 4) {
                // set TIMA to TMA
                self.tima = self.tma;
                //request interrupt
                self.flagRegister.* |= 0b100;

                self.overflow = false;
            }

            if (self.overflowCycles == 8) {
                self.overflowCycles = 0;
            }
        }

        if (self.enabled and !self.overflow) {
            const fallingEdge = self.checkFallingEdge();
            if (fallingEdge) {
                self.incrementTima();
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
            self.overflow = true;
            self.overflowCycles = 0;
            self.tima = 0; // TIMA reads as 0 during this delay period
        }
    }

    pub fn checkFallingEdge(self: *Timer) bool {
        const clockSelect: u2 = @truncate(self.tac);
        const bit = BITS[@as(usize, clockSelect)];

        const mask: u32 = std.math.shl(u32, 1, bit);
        const oldBit = (self.previousCycles & mask) != 0;
        const newBit = (self.cycles & mask) != 0;

        return oldBit and !newBit;
    }

    pub fn writeDiv(self: *Timer) void {
        self.div = 0;
        self.cycles = 0;
        if (self.checkFallingEdge()) {
            self.incrementTima();
        }
        self.previousCycles = 0;
    }

    pub fn writeTima(self: *Timer, value: u8) void {
        if (self.overflow) {
            if (self.overflowCycles < 4) {
                self.tima = value;
                self.overflow = false;
                self.overflowCycles = 0;
            }
        } else {
            self.tima = value;
        }
    }

    pub fn writeTma(self: *Timer, value: u8) void {
        self.tma = value;
        if (self.overflow and self.overflowCycles >= 4) {
            self.tima = value;
        }
    }

    pub fn writeTac(self: *Timer, value: u8) void {
        const oldTac = self.tac;
        const oldEnable = (oldTac & (1 << 2)) != 0;
        const oldClockSelect: u2 = @truncate(oldTac);
        const oldMask = std.math.shl(u32, 1, BITS[@as(usize, oldClockSelect)]);
        const oldEdge = self.cycles & oldMask != 0;

        const newTac = value;
        const newEnable = (newTac & (1 << 2)) != 0;
        const newClockSelect: u2 = @truncate(newTac);
        const newMask = std.math.shl(u32, 1, BITS[@as(usize, newClockSelect)]);
        const newEdge = self.cycles & newMask != 0;

        // check if timer get's disabled and if we might increment tima
        if (oldEnable and oldEdge and !newEnable) {
            self.incrementTima();
        }

        // check if the new clock select value is 0 and the current one is 1 if this is the case increment tima
        if (oldEnable and newEnable and oldEdge and !newEdge) {
            self.incrementTima();
        }

        // enable / disable timer based on 3 bit of tac register
        self.enabled = newEnable;

        self.tac = value;
    }
};
