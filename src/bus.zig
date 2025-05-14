const Memory = @import("memory.zig").Memory;
const Timer = @import("timer.zig").Timer;

pub const Bus = struct {
    memory: *Memory,
    timer: *Timer,

    // Init functions

    pub fn init(self: *Bus, memory: *Memory, timer: *Timer) void {
        self.memory = memory;
        self.timer = timer;
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

        self.timer.incrementTima();
        self.incrementDiv();
    }

    fn incrementDiv(self: *Bus) void {
        while (self.divAcc >= 256) {
            self.timer.divAcc -= 256;
            self.memory.io[0x04] +%= 1;
        }
    }

    // MMU

    pub fn write(self: *Bus, address: u16, value: u8) void {
        self.memory.write(address, value);
    }

    pub fn read(self: *Bus, address: u16) u8 {
        return self.memory.read(address);
    }
};
