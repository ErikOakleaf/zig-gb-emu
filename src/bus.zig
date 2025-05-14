const Memory = @import("memory.zig").Memory;
const Timer = @import("timer.zig").Timer;
const TIMER_PERIODS = @import("timer.zig").TIMER_PERIODS;

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
        self.timer.timAcc += mCycles;
        self.timer.divAcc += mCycles;

        self.incrementTima();
        self.incrementDiv();
    }

    fn incrementDiv(self: *Bus) void {
        while (self.timer.divAcc >= 256) {
            self.timer.divAcc -= 256;
            self.memory.write(0xFF04, self.memory.read(0xFF04) +% 1);
        }
    }

    fn incrementTima(self: *Bus) void {
        const TAC: u8 = self.memory.read(0xFF07);
        const enable: bool = (TAC & 0b100) > 0;
        const clockSelect: u2 = @truncate(TAC);

        if (enable) {
            const incrementEvery = TIMER_PERIODS[@as(usize, clockSelect)];

            while (self.timer.timAcc >= incrementEvery) {
                self.timer.timAcc -= incrementEvery;

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
