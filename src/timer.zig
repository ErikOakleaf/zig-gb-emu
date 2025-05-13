const std = @import("std");
const memory = @import("memory.zig");

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
};
