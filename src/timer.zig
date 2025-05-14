const std = @import("std");

const TIMER_PERIODS = [4]u16{ 1024, 16, 64, 256 };

pub const Timer = struct {
    divAcc: u32,
    timAcc: u32,

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
