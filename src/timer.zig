const std = @import("std");
const memory = @import("memory.zig");

const TIMER_PERIODS = [4]u16{ 1024, 16, 64, 256 };

pub const Timer = struct {
    divAcc: u32,
    timAcc: u32,
    memory: *memory.Memory,

    pub fn init(self: *Timer, mem: *memory.Memory) void {
        self.memory = mem;
        self.divAcc = 0;
        self.timAcc = 0;
        self.memory.write(0xFF04, 0);
        self.memory.write(0xFF05, 0);
        self.memory.write(0xFF06, 0);
        self.memory.write(0xFF07, 0);
    }

    pub fn tick(self: *Timer, mCycles: u32) void {
        self.timAcc += mCycles;
        self.divAcc += mCycles;

        self.incrementTima();
        self.incrementDiv();
    }

    fn incrementDiv(self: *Timer) void {
        while (self.divAcc >= 256) {
            self.divAcc -= 256;
            self.memory.write(0xFF04, self.memory.read(0xFF04) +% 1);
        }
    }

    fn incrementTima(self: *Timer) void {
        const TAC: u8 = self.memory.read(0xFF07);
        const enable: bool = (TAC & 0b100) > 0;
        const clockSelect: u2 = @truncate(TAC);

        if (enable) {
            const incrementEvery = TIMER_PERIODS[clockSelect];

            while (self.timAcc >= incrementEvery) {
                self.timAcc -= incrementEvery;

                // read the current time
                const currentValue: u8 = self.memory.read(0xFF05);

                // check for overflow
                if (currentValue == 0xFF) {
                    self.handleOverflow();
                } else {
                    self.memory.write(0xFF05, currentValue + 1);
                }
            }
        }
    }

    fn handleOverflow(self: *Timer) void {
        // set TIMA to TMA
        self.memory.write(0xFF05, self.memory.read(0xFF06));

        // request timer interupt
        self.memory.write(0xFF0F, self.memory.read(0xFF0F) | 0b100);
    }
};
