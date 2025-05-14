const std = @import("std");
const Memory = @import("memory.zig").Memory;
const Timer = @import("timer.zig").Timer;

// define constants
const BITS: [4]u8 = .{ 0, 3, 5, 7 };

pub const Bus = struct {
    memory: *Memory,
    timer: *Timer,

    // Init functions

    pub fn init(self: *Bus, memory: *Memory, timer: *Timer) void {
        self.memory = memory;
        self.timer = timer;
        self.memory.init();
        self.initTimer();
    }

    pub fn initTimer(self: *Bus) void {
        self.timer.divAcc = 0;
        self.timer.timAcc = 0;

        self.memory.write(0xFF04, 0);
        self.memory.write(0xFF05, 0);
        self.memory.write(0xFF06, 0);
        self.memory.write(0xFF07, 0);
    }

    // Timer functions

    pub fn tickTimer(self: *Bus, mCycles: u32) void {
        self.incrementTima(mCycles);
        self.timer.sysCount +%= mCycles;
        self.updateDiv();
    }

    fn updateDiv(self: *Bus) void {
        // update the div register to be the high byte of the sysCount
        const newDiv: u8 = @truncate(self.timer.sysCount >> 8);
        self.memory.write(0x0FF04, newDiv);
    }

    fn incrementTima(self: *Bus, mCycles: u8) void {
        const TAC: u8 = self.memory.read(0xFF07);
        const enable: bool = (TAC & 0b100) > 0;
        const clockSelect: u2 = @truncate(TAC);

        if (enable) {
            const bit = BITS[@as(usize, clockSelect)];

            const fallingEdges: u8 = checkFallingEdges(self.timer.sysCount, mCycles, bit);

            // read the current time
            const currentValue: u8 = self.memory.read(0xFF05);

            // check for overflow
            if (currentValue >= 0xFF - fallingEdges) {
                self.handleOverflow();
            } else {
                self.memory.write(0xFF05, currentValue + fallingEdges);
            }
        }
    }

    fn checkFallingEdges(old: u32, mCycles: u32, bit: u8) u8 {
        // this is equivalent to 2^(bit + 1)
        const period: u32 = std.math.shl(u32, 1, bit + 1); // one full cycle for the given bit
        const halfPeriod: u32 = std.math.shl(u32, 1, bit); // half a cycle for the given bit
        const oldPosition = old & (period - 1); // old % period. This is were we are right now in a cycle
        const total = oldPosition + mCycles;
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

    fn handleOverflow(self: *Bus) void {
        // set TIMA to TMA
        self.memory.write(0xFF05, self.memory.read(0xFF06));

        // request timer interupt
        self.memory.write(0xFF0F, self.memory.read(0xFF0F) | 0b100);
    }

    // MMU

    pub fn write(self: *Bus, address: u16, value: u8) void {
        // if write is done to div register [0xFF04] always reset it
        if (address == 0xFF04) {
            self.memory.write(0xFF04, 0);
            self.timer.divAcc = 0;
            return;
        }

        self.memory.write(address, value);
    }

    pub fn read(self: *Bus, address: u16) u8 {
        return self.memory.read(address);
    }
};
