const std = @import("std");

pub const Timer = struct {
    sysCount: u32,
    overflowDelay: u8,
};
