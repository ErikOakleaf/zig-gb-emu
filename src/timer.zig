const std = @import("std");

pub const TIMER_PERIODS = [4]u16{ 1024, 16, 64, 256 };

pub const Timer = struct {
    divAcc: u32,
    timAcc: u32,
};
