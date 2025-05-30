const std = @import("std");
const BITS: [4]u8 = .{ 9, 3, 5, 7 };

pub const Timer = struct {
    sysCount: u32,
    overflowDelay: u8,
    div: u8, // 0xFF04
    tima: u8, // 0xFF05
    tma: u8, // 0xFF06
    tac: u8, // 0xFF07
    flagRegister: *u8,

    pub fn init(self: *Timer) void {
        self.sysCount = 0;
        self.overflowDelay = 0;
        self.div = 0;
        self.tima = 0;
        self.tma = 0;
        self.tac = 0;
    }

    pub fn tick(self: *Timer, tCycles: u32) void {
        self.sysCount +%= tCycles;
        self.updateDiv();

        // if there is a overflow delay decrement it and handle overflow
        if (self.overflowDelay > 0) {
            const toConsume = @min(self.overflowDelay, tCycles);
            self.overflowDelay -= toConsume;
            if (self.overflowDelay == 0) {
                self.handleOverflow();
                return;
            }
            return;
        }

        self.incrementTima(tCycles);
    }

    fn updateDiv(self: *Timer) void {
        // update the div register to be the high byte of the sysCount
        const newDiv: u8 = @truncate(self.sysCount >> 8);
        self.div = newDiv;
    }

    fn incrementTima(self: *Timer, tCycles: u32) void {
        const enable: bool = (self.tac & 0b100) > 0;
        const clockSelect: u2 = @truncate(self.tac);

        if (enable) {
            const bit = BITS[@as(usize, clockSelect)];

            const fallingEdges: u8 = checkFallingEdges(self.sysCount, tCycles, bit);

            // read the current time
            const currentValue: u8 = self.tima;

            // check for overflow
            if (currentValue >= 0xFF - fallingEdges) {
                // there is a 4‑cycle delay between TIMA overflow and interrupt
                self.overflowDelay = 4;
                self.tima = 0; // TIMA reads as 0 during this delay period
            } else {
                self.tima = currentValue + fallingEdges;
            }
        }
    }

    fn checkFallingEdges(old: u32, tCycles: u32, bit: u8) u8 {
        // this is equivalent to 2^(bit + 1)
        const period: u32 = std.math.shl(u32, 1, bit + 1); // one full cycle for the given bit
        const halfPeriod: u32 = std.math.shl(u32, 1, bit); // half a cycle for the given bit
        const oldPosition = old & (period - 1); // old % period. This is were we are right now in a cycle
        const total = oldPosition + tCycles;
        const newPosition = total & (period - 1);

        // calculate the full wraps. Simple enough just see how many times the total value fits in the period
        const fullWraps: u8 = @truncate(total / period);

        // if the old position is lagrer than a half period and the new position is smaller it means we have a partial
        // wrap around since they combined become >= one period
        var partialWraps: u8 = 0;
        if (oldPosition >= halfPeriod and newPosition < halfPeriod) {
            partialWraps = 1;
        }

        return fullWraps + partialWraps;
    }

    fn handleOverflow(self: *Timer) void {
        // set TIMA to TMA
        self.tima = self.tma;
        self.flagRegister.* |= 0b100;
    }
};
