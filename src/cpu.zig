const std = @import("std");
const memory = @import("memory.zig");
const math = std.math;

pub const OP_CYCLES = [_]u8{
    // 1  2  3  4  5  6  7  8  9  A  B  C  D  E  F
    1, 3, 2, 2, 1, 1, 2, 1, 5, 2, 2, 2, 1, 1, 2, 1, // 0
    0, 3, 2, 2, 1, 1, 2, 1, 3, 2, 2, 2, 1, 1, 2, 1, // 1
    2, 3, 2, 2, 1, 1, 2, 1, 2, 2, 2, 2, 1, 1, 2, 1, // 2
    2, 3, 2, 2, 3, 3, 3, 1, 2, 2, 2, 2, 1, 1, 2, 1, // 3
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1, // 4
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1, // 5
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1, // 6
    2, 2, 2, 2, 2, 2, 0, 2, 1, 1, 1, 1, 1, 1, 2, 1, // 7
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1, // 8
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1, // 9
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1, // A
    1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 2, 1, // B
    2, 3, 3, 4, 3, 4, 2, 4, 2, 4, 3, 0, 3, 6, 2, 4, // C
    2, 3, 3, 0, 3, 4, 2, 4, 2, 4, 3, 0, 3, 0, 2, 4, // D
    3, 3, 2, 0, 0, 4, 2, 4, 4, 1, 4, 0, 0, 0, 2, 4, // E
    3, 3, 2, 1, 0, 4, 2, 4, 3, 2, 4, 1, 0, 0, 2, 4, // F
};

pub const OP_CB_CYCLES = [_]u8{
    // 1  2  3  4  5  6  7  8  9  A  B  C  D  E  F
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2, // 0
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2, // 1
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2, // 2
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2, // 3
    2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 3, 2, // 4
    2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 3, 2, // 5
    2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 3, 2, // 6
    2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 3, 2, // 7
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2, // 8
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2, // 9
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2, // A
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2, // B
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2, // C
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2, // D
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2, // E
    2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 4, 2, // F
};

const Flag = enum(u8) {
    c = 4,
    h = 5,
    n = 6,
    z = 7,
};

pub const Cpu = struct {
    // CPU Registers

    a: u8,
    f: u8,
    b: u8,
    c: u8,
    d: u8,
    e: u8,
    h: u8,
    l: u8,
    sp: u16,
    pc: u16,
    memory: *memory.Memory,
    ime: bool,

    pub fn init(self: *Cpu, allocator: *std.mem.Allocator) !void {
        const memPtr = try allocator.create(memory.Memory);
        memPtr.*.init();
        self.memory = memPtr;

        self.a = 0;
        self.f = 0;
        self.b = 0;
        self.c = 0;
        self.d = 0;
        self.e = 0;
        self.h = 0;
        self.l = 0;
        self.pc = 0;
        self.sp = 0;
        self.ime = false;
    }

    pub fn deinit(self: *Cpu, allocator: *std.mem.Allocator) void {
        allocator.destroy(self.memory);
        self.memory = undefined;
    }

    pub fn tick(self: *Cpu) u8 {
        // TODO - implement interupt handling

        const opcode: u8 = self.memory.read(self.pc);

        // std.debug.print("reading opcode: {d}, at memory: {d}\n", .{ opcode, self.pc });

        self.pc +%= 1;

        const cycles = self.executeOpcode(opcode);
        return cycles;
    }

    // executes opcode returns the ammount of cycles
    fn executeOpcode(self: *Cpu, opcode: u8) u8 {
        const opCycles = if (opcode != 0xCB) OP_CYCLES[opcode] else OP_CB_CYCLES[self.memory.read(self.pc)];
        // std.debug.print("executing opcode: {d}\n", .{opcode});

        switch (opcode) {
            // NOP
            0x00 => {},
            // LD r16, n16
            0x01 => {
                self.LD_r16_n16(&self.b, &self.c);
            },
            0x11 => {
                self.LD_r16_n16(&self.d, &self.e);
            },
            0x21 => {
                self.LD_r16_n16(&self.h, &self.l);
            },
            0x31 => {
                // load register SP
                const lo: u8 = self.memory.read(self.pc);
                const hi: u8 = self.memory.read(self.pc + 1);
                self.pc +%= 2;

                const value: u16 = (@as(u16, hi) << 8) | lo;

                self.sp = value;
            },
            // LD r16, A
            0x02 => {
                self.LD_r16_A(&self.b, &self.c);
            },
            0x12 => {
                self.LD_r16_A(&self.d, &self.e);
            },
            0x22 => {
                self.LD_r16_A(&self.h, &self.l);

                var hl = combine8BitValues(self.h, self.l);
                hl = hl +% 1;

                const decomposedValues = decompose16BitValue(hl);
                self.h = decomposedValues[0];
                self.l = decomposedValues[1];
            },
            0x32 => {
                self.LD_r16_A(&self.h, &self.l);

                // decrement hl
                var hl = combine8BitValues(self.h, self.l);
                hl = hl -% 1;

                const decomposedValues = decompose16BitValue(hl);
                self.h = decomposedValues[0];
                self.l = decomposedValues[1];
            },
            // LD n16, A
            0xE0 => {
                const value: u16 = @intCast(self.memory.read(self.pc));
                self.pc +%= 1;
                const address = value +% 0xFF00;
                self.LD_n16_A(address);
            },
            0xE2 => {
                const address: u16 = @as(u16, self.c) +% 0xFF00;
                self.LD_n16_A(address);
            },
            0xEA => {
                const lo: u8 = self.memory.read(self.pc);
                const hi: u8 = self.memory.read(self.pc + 1);
                self.pc +%= 2;

                const address = combine8BitValues(hi, lo);

                self.LD_n16_A(address);
            },
            // LD A, n16
            0xF0 => {
                const value: u16 = @intCast(self.memory.read(self.pc));
                self.pc +%= 1;
                const address = value +% 0xFF00;
                self.LD_A_n16(address);
            },
            0xF2 => {
                const address: u16 = @as(u16, self.c) +% 0xFF00;
                self.LD_A_n16(address);
            },
            0xFA => {
                const lo: u8 = self.memory.read(self.pc);
                const hi: u8 = self.memory.read(self.pc + 1);
                self.pc +%= 2;

                const address = combine8BitValues(hi, lo);

                self.LD_A_n16(address);
            },
            // INC r16
            0x03 => {
                INC_r16(&self.b, &self.c);
            },
            0x13 => {
                INC_r16(&self.d, &self.e);
            },
            0x23 => {
                INC_r16(&self.h, &self.l);
            },
            0x33 => {
                // increment register sp
                self.sp +%= 1;
            },
            // INC r8
            0x04 => {
                self.INC_r8(&self.b);
            },
            0x14 => {
                self.INC_r8(&self.d);
            },
            0x24 => {
                self.INC_r8(&self.h);
            },
            0x34 => {
                // increment register HL

                const address: u16 = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);

                const halfCarry = checkHalfCarry8(value, 1);

                if (halfCarry) {
                    self.setFlag(Flag.h);
                } else {
                    self.clearFlag(Flag.h);
                }

                value += 1;

                if (value == 0) {
                    self.setFlag(Flag.z);
                } else {
                    self.clearFlag(Flag.z);
                }

                self.clearFlag(Flag.n);

                self.memory.write(address, value);
            },
            0x0C => {
                self.INC_r8(&self.c);
            },
            0x1C => {
                self.INC_r8(&self.e);
            },
            0x2C => {
                self.INC_r8(&self.l);
            },
            0x3C => {
                self.INC_r8(&self.a);
            },
            // DEC r8
            0x05 => {
                self.DEC_r8(&self.b);
            },
            0x15 => {
                self.DEC_r8(&self.d);
            },
            0x25 => {
                self.DEC_r8(&self.h);
            },
            0x35 => {
                // decrement register HL

                const address: u16 = @as(u16, self.h) << 8 | self.l;
                var value = self.memory.read(address);

                const halfCarry = checkHalfBorrow8(value, 1);

                if (halfCarry) {
                    self.setFlag(Flag.h);
                } else {
                    self.clearFlag(Flag.h);
                }

                value -= 1;

                if (value == 0) {
                    self.setFlag(Flag.z);
                } else {
                    self.clearFlag(Flag.z);
                }

                self.setFlag(Flag.n);

                self.memory.write(address, value);
            },
            0x0D => {
                self.DEC_r8(&self.c);
            },

            0x1D => {
                self.DEC_r8(&self.e);
            },

            0x2D => {
                self.DEC_r8(&self.l);
            },

            0x3D => {
                self.DEC_r8(&self.a);
            },

            // LD r8n8
            0x06 => {
                self.LD_r8_n8(&self.b);
            },
            0x16 => {
                self.LD_r8_n8(&self.d);
            },
            0x26 => {
                self.LD_r8_n8(&self.h);
            },
            0x36 => {
                const address: u16 = @as(u16, self.h) << 8 | self.l;
                const value = self.memory.read(self.pc);
                self.pc +%= 1;

                self.memory.write(address, value);
            },
            // Rotations
            0x0F => {
                self.RRCA();
            },
            0x1F => {
                self.RRA();
            },
            0x07 => {
                self.RLCA();
            },
            0x17 => {
                self.RLA();
            },
            // DAA
            0x27 => {
                var adjustment: u8 = 0;
                var carryOut = self.flagIsSet(Flag.c) == 1;

                if (self.flagIsSet(Flag.n) == 1) {
                    if (self.flagIsSet(Flag.h) == 1) {
                        adjustment += 0x06;
                    }

                    if (self.flagIsSet(Flag.c) == 1) {
                        adjustment += 0x60;
                    }

                    self.a -%= adjustment;
                } else {
                    if (self.flagIsSet(Flag.h) == 1 or (self.a & 0x0F) > 0x9) {
                        adjustment += 0x06;
                    }

                    if (self.flagIsSet(Flag.c) == 1 or self.a > 0x99) {
                        adjustment += 0x60;
                        carryOut = true;
                    }

                    self.a +%= adjustment;
                }

                if (self.a == 0) {
                    self.setFlag(Flag.z);
                } else {
                    self.clearFlag(Flag.z);
                }

                if (carryOut == true) {
                    self.setFlag(Flag.c);
                } else {
                    self.clearFlag(Flag.c);
                }

                self.clearFlag(Flag.h);
            },
            // SCF
            0x37 => {
                self.clearFlag(Flag.n);
                self.clearFlag(Flag.h);
                self.setFlag(Flag.c);
            },
            // CPL
            0x2F => {
                self.a = ~(self.a);
                self.setFlag(Flag.n);
                self.setFlag(Flag.h);
            },
            // CCF
            0x3F => {
                const flagSet: u8 = self.flagIsSet(Flag.c);
                if (flagSet == 1) {
                    self.clearFlag(Flag.c);
                } else {
                    self.setFlag(Flag.c);
                }
                self.clearFlag(Flag.n);
                self.clearFlag(Flag.h);
            },
            // LD [n16], SP
            0x08 => {
                const lo: u8 = self.memory.read(self.pc);
                const hi: u8 = self.memory.read(self.pc + 1);
                self.pc +%= 2;
                const address = combine8BitValues(hi, lo);

                const decomposedSp = decompose16BitValue(self.sp);
                self.memory.write(address, decomposedSp[1]);
                self.memory.write(address + 1, decomposedSp[0]);
            },
            // ADD HL r16
            0x09 => {
                self.ADD_HL_r16(self.b, self.c);
            },
            0x19 => {
                self.ADD_HL_r16(self.d, self.e);
            },
            0x29 => {
                self.ADD_HL_r16(self.h, self.l);
            },
            0x39 => {
                // add hl sp
                var hl = combine8BitValues(self.h, self.l);

                const halfCarry = checkHalfCarry16(hl, self.sp);
                if (halfCarry) {
                    self.setFlag(Flag.h);
                } else {
                    self.clearFlag(Flag.h);
                }

                const carry = checkCarry16(hl, self.sp);
                if (carry) {
                    self.setFlag(Flag.c);
                } else {
                    self.clearFlag(Flag.c);
                }

                hl = hl +% self.sp;

                // store as two 8 bit ints in registers
                const decomposedValues = decompose16BitValue(hl);

                self.h = decomposedValues[0];
                self.l = decomposedValues[1];

                self.clearFlag(Flag.n);
            },
            // LD A r16
            0x0A => {
                self.LD_A_r16(&self.b, &self.c);
            },
            0x1A => {
                self.LD_A_r16(&self.d, &self.e);
            },
            0x2A => {
                self.LD_A_r16(&self.h, &self.l);

                // increment hl
                var hl = combine8BitValues(self.h, self.l);
                hl = hl +% 1;

                const decomposedValues = decompose16BitValue(hl);
                self.h = decomposedValues[0];
                self.l = decomposedValues[1];
            },
            0x3A => {
                self.LD_A_r16(&self.h, &self.l);

                // decrement hl
                var hl = combine8BitValues(self.h, self.l);
                hl = hl -% 1;

                const decomposedValues = decompose16BitValue(hl);
                self.h = decomposedValues[0];
                self.l = decomposedValues[1];
            },
            // DEC r16
            0x0B => {
                DEC_r16(&self.b, &self.c);
            },
            0x1B => {
                DEC_r16(&self.d, &self.e);
            },
            0x2B => {
                DEC_r16(&self.h, &self.l);
            },
            0x3B => {
                self.sp = self.sp -% 1;
            },
            // LD r8, n8
            0x0E => {
                self.LD_r8_n8(&self.c);
            },
            0x1E => {
                self.LD_r8_n8(&self.e);
            },
            0x2E => {
                self.LD_r8_n8(&self.l);
            },
            0x3E => {
                self.LD_r8_n8(&self.a);
            },
            // LD r8, r8
            0x40 => {
                LD_r8_r8(&self.b, &self.b);
            },
            0x41 => {
                LD_r8_r8(&self.b, &self.c);
            },
            0x42 => {
                LD_r8_r8(&self.b, &self.d);
            },
            0x43 => {
                LD_r8_r8(&self.b, &self.e);
            },
            0x44 => {
                LD_r8_r8(&self.b, &self.h);
            },
            0x45 => {
                LD_r8_r8(&self.b, &self.l);
            },
            0x46 => {
                self.LD_r8_HL(&self.b);
            },
            0x47 => {
                LD_r8_r8(&self.b, &self.a);
            },
            0x48 => {
                LD_r8_r8(&self.c, &self.b);
            },
            0x49 => {
                LD_r8_r8(&self.c, &self.c);
            },
            0x4A => {
                LD_r8_r8(&self.c, &self.d);
            },
            0x4B => {
                LD_r8_r8(&self.c, &self.e);
            },
            0x4C => {
                LD_r8_r8(&self.c, &self.h);
            },
            0x4D => {
                LD_r8_r8(&self.c, &self.l);
            },
            0x4E => {
                self.LD_r8_HL(&self.c);
            },
            0x4F => {
                LD_r8_r8(&self.c, &self.a);
            },
            0x50 => {
                LD_r8_r8(&self.d, &self.b);
            },
            0x51 => {
                LD_r8_r8(&self.d, &self.c);
            },
            0x52 => {
                LD_r8_r8(&self.d, &self.d);
            },
            0x53 => {
                LD_r8_r8(&self.d, &self.e);
            },
            0x54 => {
                LD_r8_r8(&self.d, &self.h);
            },
            0x55 => {
                LD_r8_r8(&self.d, &self.l);
            },
            0x56 => {
                self.LD_r8_HL(&self.d);
            },
            0x57 => {
                LD_r8_r8(&self.d, &self.a);
            },
            0x58 => {
                LD_r8_r8(&self.e, &self.b);
            },
            0x59 => {
                LD_r8_r8(&self.e, &self.c);
            },
            0x5A => {
                LD_r8_r8(&self.e, &self.d);
            },
            0x5B => {
                LD_r8_r8(&self.e, &self.e);
            },
            0x5C => {
                LD_r8_r8(&self.e, &self.h);
            },
            0x5D => {
                LD_r8_r8(&self.e, &self.l);
            },
            0x5E => {
                self.LD_r8_HL(&self.e);
            },
            0x5F => {
                LD_r8_r8(&self.e, &self.a);
            },
            0x60 => {
                LD_r8_r8(&self.h, &self.b);
            },
            0x61 => {
                LD_r8_r8(&self.h, &self.c);
            },
            0x62 => {
                LD_r8_r8(&self.h, &self.d);
            },
            0x63 => {
                LD_r8_r8(&self.h, &self.e);
            },
            0x64 => {
                LD_r8_r8(&self.h, &self.h);
            },
            0x65 => {
                LD_r8_r8(&self.h, &self.l);
            },
            0x66 => {
                self.LD_r8_HL(&self.h);
            },
            0x67 => {
                LD_r8_r8(&self.h, &self.a);
            },
            0x68 => {
                LD_r8_r8(&self.l, &self.b);
            },
            0x69 => {
                LD_r8_r8(&self.l, &self.c);
            },
            0x6a => {
                LD_r8_r8(&self.l, &self.d);
            },
            0x6b => {
                LD_r8_r8(&self.l, &self.e);
            },
            0x6c => {
                LD_r8_r8(&self.l, &self.h);
            },
            0x6d => {
                LD_r8_r8(&self.l, &self.l);
            },
            0x6e => {
                self.LD_r8_HL(&self.l);
            },
            0x6f => {
                LD_r8_r8(&self.l, &self.a);
            },
            // LD HL r8
            0x70 => {
                self.LD_HL_r8(&self.b);
            },
            0x71 => {
                self.LD_HL_r8(&self.c);
            },
            0x72 => {
                self.LD_HL_r8(&self.d);
            },
            0x73 => {
                self.LD_HL_r8(&self.e);
            },
            0x74 => {
                self.LD_HL_r8(&self.h);
            },
            0x75 => {
                self.LD_HL_r8(&self.l);
            },
            0x76 => {
                // TODO implement halt here
            },
            0x77 => {
                self.LD_HL_r8(&self.a);
            },
            0x78 => {
                LD_r8_r8(&self.a, &self.b);
            },
            0x79 => {
                LD_r8_r8(&self.a, &self.c);
            },
            0x7a => {
                LD_r8_r8(&self.a, &self.d);
            },
            0x7b => {
                LD_r8_r8(&self.a, &self.e);
            },
            0x7c => {
                LD_r8_r8(&self.a, &self.h);
            },
            0x7d => {
                LD_r8_r8(&self.a, &self.l);
            },
            0x7e => {
                self.LD_r8_HL(&self.a);
            },
            0x7f => {
                LD_r8_r8(&self.a, &self.a);
            },
            // ADD A, r8
            0x80 => {
                self.ADD_A_r8(self.b);
            },
            0x81 => {
                self.ADD_A_r8(self.c);
            },
            0x82 => {
                self.ADD_A_r8(self.d);
            },
            0x83 => {
                self.ADD_A_r8(self.e);
            },
            0x84 => {
                self.ADD_A_r8(self.h);
            },
            0x85 => {
                self.ADD_A_r8(self.l);
            },
            0x86 => {
                // ADD A, [HL]

                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.ADD_A_r8(value);
            },
            0x87 => {
                self.ADD_A_r8(self.a);
            },
            // ADC A, r8
            0x88 => {
                self.ADC_A_r8(self.b);
            },
            0x89 => {
                self.ADC_A_r8(self.c);
            },
            0x8A => {
                self.ADC_A_r8(self.d);
            },
            0x8B => {
                self.ADC_A_r8(self.e);
            },
            0x8C => {
                self.ADC_A_r8(self.h);
            },
            0x8D => {
                self.ADC_A_r8(self.l);
            },
            0x8E => {
                // ADC A, [HL]

                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.ADC_A_r8(value);
            },
            0x8F => {
                self.ADC_A_r8(self.a);
            },
            // SUB A, r9
            0x90 => {
                self.SUB_A_r8(self.b);
            },
            0x91 => {
                self.SUB_A_r8(self.c);
            },
            0x92 => {
                self.SUB_A_r8(self.d);
            },
            0x93 => {
                self.SUB_A_r8(self.e);
            },
            0x94 => {
                self.SUB_A_r8(self.h);
            },
            0x95 => {
                self.SUB_A_r8(self.l);
            },
            0x96 => {
                // SUB A, [HL]

                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.SUB_A_r8(value);
            },
            0x97 => {
                self.SUB_A_r8(self.a);
            },
            // SBC A, r8
            0x98 => {
                self.SBC_A_r8(self.b);
            },
            0x99 => {
                self.SBC_A_r8(self.c);
            },
            0x9A => {
                self.SBC_A_r8(self.d);
            },
            0x9B => {
                self.SBC_A_r8(self.e);
            },
            0x9C => {
                self.SBC_A_r8(self.h);
            },
            0x9D => {
                self.SBC_A_r8(self.l);
            },
            0x9E => {
                // SBC A, [HL]

                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.SBC_A_r8(value);
            },
            0x9F => {
                self.SBC_A_r8(self.a);
            },
            // AND A, r8
            0xA0 => {
                self.AND_A_r8(self.b);
            },
            0xA1 => {
                self.AND_A_r8(self.c);
            },
            0xA2 => {
                self.AND_A_r8(self.d);
            },
            0xA3 => {
                self.AND_A_r8(self.e);
            },
            0xA4 => {
                self.AND_A_r8(self.h);
            },
            0xA5 => {
                self.AND_A_r8(self.l);
            },
            0xA6 => {
                // AND A, [HL]

                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.AND_A_r8(value);
            },
            0xA7 => {
                self.AND_A_r8(self.a);
            },
            // XOR A, r8
            0xA8 => {
                self.XOR_A_r8(self.b);
            },
            0xA9 => {
                self.XOR_A_r8(self.c);
            },
            0xAA => {
                self.XOR_A_r8(self.d);
            },
            0xAB => {
                self.XOR_A_r8(self.e);
            },
            0xAC => {
                self.XOR_A_r8(self.h);
            },
            0xAD => {
                self.XOR_A_r8(self.l);
            },
            0xAE => {
                // XOR A, [HL]

                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.XOR_A_r8(value);
            },
            0xAF => {
                self.XOR_A_r8(self.a);
            },
            0xB0 => {
                self.OR_A_r8(self.b);
            },
            0xB1 => {
                self.OR_A_r8(self.c);
            },
            0xB2 => {
                self.OR_A_r8(self.d);
            },
            0xB3 => {
                self.OR_A_r8(self.e);
            },
            0xB4 => {
                self.OR_A_r8(self.h);
            },
            0xB5 => {
                self.OR_A_r8(self.l);
            },
            0xB6 => {
                // OR A, [HL]

                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.OR_A_r8(value);
            },
            0xB7 => {
                self.OR_A_r8(self.a);
            },
            // CP A, r8
            0xB8 => {
                self.CP_A_r8(self.b);
            },
            0xB9 => {
                self.CP_A_r8(self.c);
            },
            0xBA => {
                self.CP_A_r8(self.d);
            },
            0xBB => {
                self.CP_A_r8(self.e);
            },
            0xBC => {
                self.CP_A_r8(self.h);
            },
            0xBD => {
                self.CP_A_r8(self.l);
            },
            0xBE => {
                // CP A, [HL]

                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.CP_A_r8(value);
            },
            0xBF => {
                self.CP_A_r8(self.a);
            },
            // JR cc
            0x20 => {
                if (self.flagIsSet(Flag.z) == 0) {
                    self.JR();
                } else {
                    self.pc +%= 1;
                }
            },
            0x30 => {
                if (self.flagIsSet(Flag.c) == 0) {
                    self.JR();
                } else {
                    self.pc +%= 1;
                }
            },
            0x18 => {
                self.JR();
            },
            0x28 => {
                if (self.flagIsSet(Flag.z) == 1) {
                    self.JR();
                } else {
                    self.pc +%= 1;
                }
            },
            0x38 => {
                if (self.flagIsSet(Flag.c) == 1) {
                    self.JR();
                } else {
                    self.pc +%= 1;
                }
            },
            // POP r16
            0xC1 => {
                self.POP_r16(&self.b, &self.c);
            },
            0xD1 => {
                self.POP_r16(&self.d, &self.e);
            },
            0xE1 => {
                self.POP_r16(&self.h, &self.l);
            },
            0xF1 => {
                // POP AF
                const lo: u8 = self.memory.read(self.sp);
                const hi: u8 = self.memory.read(self.sp + 1);
                self.sp +%= 2;

                self.a = hi;
                // lowest 3 bits always stay at zero in the flag register
                self.f = lo & 0xF0;
            },
            // JP n16
            0xC2 => {
                if (self.flagIsSet(Flag.z) == 0) {
                    self.JP_n16();
                } else {
                    self.pc +%= 2;
                }
            },
            0xD2 => {
                if (self.flagIsSet(Flag.c) == 0) {
                    self.JP_n16();
                } else {
                    self.pc +%= 2;
                }
            },
            0xC3 => {
                self.JP_n16();
            },
            0xCA => {
                if (self.flagIsSet(Flag.z) == 1) {
                    self.JP_n16();
                } else {
                    self.pc +%= 2;
                }
            },
            0xDA => {
                if (self.flagIsSet(Flag.c) == 1) {
                    self.JP_n16();
                } else {
                    self.pc +%= 2;
                }
            },
            0xE9 => {
                // JP HL
                const hl: u16 = combine8BitValues(self.h, self.l);
                self.pc = hl;
            },
            // CALL n16
            0xC4 => {
                if (self.flagIsSet(Flag.z) == 0) {
                    self.CALL_n16();
                } else {
                    self.pc +%= 2;
                }
            },
            0xD4 => {
                if (self.flagIsSet(Flag.c) == 0) {
                    self.CALL_n16();
                } else {
                    self.pc +%= 2;
                }
            },
            0xCC => {
                if (self.flagIsSet(Flag.z) == 1) {
                    self.CALL_n16();
                } else {
                    self.pc +%= 2;
                }
            },
            0xDC => {
                if (self.flagIsSet(Flag.c) == 1) {
                    self.CALL_n16();
                } else {
                    self.pc +%= 2;
                }
            },
            0xCD => {
                self.CALL_n16();
            },
            // PUSH r16
            0xC5 => {
                self.PUSH_r16(self.b, self.c);
            },
            0xD5 => {
                self.PUSH_r16(self.d, self.e);
            },
            0xE5 => {
                self.PUSH_r16(self.h, self.l);
            },
            0xF5 => {
                self.PUSH_r16(self.a, self.f);
            },
            0xC6 => {
                // ADD A, n8
                const value = self.memory.read(self.pc);
                self.pc +%= 1;

                self.ADD_A_r8(value);
            },
            0xD6 => {
                // SUB A, n8
                const value = self.memory.read(self.pc);
                self.pc +%= 1;

                self.SUB_A_r8(value);
            },
            0xE6 => {
                // AND A, n8
                const value = self.memory.read(self.pc);
                self.pc +%= 1;

                self.AND_A_r8(value);
            },
            0xF6 => {
                // OR A, n8
                const value = self.memory.read(self.pc);
                self.pc +%= 1;

                self.OR_A_r8(value);
            },
            // RST
            0xC7 => {
                self.RST(0x00);
            },
            0xD7 => {
                self.RST(0x10);
            },
            0xE7 => {
                self.RST(0x20);
            },
            0xF7 => {
                self.RST(0x30);
            },
            0xCF => {
                self.RST(0x08);
            },
            0xDF => {
                self.RST(0x18);
            },
            0xEF => {
                self.RST(0x28);
            },
            0xFF => {
                self.RST(0x38);
            },
            // RET cc
            0xC0 => {
                if (self.flagIsSet(Flag.z) == 0) {
                    self.RET();
                }
            },
            0xD0 => {
                if (self.flagIsSet(Flag.c) == 0) {
                    self.RET();
                }
            },
            0xC8 => {
                if (self.flagIsSet(Flag.z) == 1) {
                    self.RET();
                }
            },
            0xC9 => {
                self.RET();
            },
            // RETI
            0xD9 => {
                self.RET();
                self.ime = true;
            },
            0xD8 => {
                if (self.flagIsSet(Flag.c) == 1) {
                    self.RET();
                }
            },
            0xCE => {
                // ADC A, n8
                const value = self.memory.read(self.pc);
                self.pc +%= 1;

                self.ADC_A_r8(value);
            },
            0xDE => {
                // SBC A, n8
                const value = self.memory.read(self.pc);
                self.pc +%= 1;

                self.SBC_A_r8(value);
            },
            0xEE => {
                // XOR A, n8
                const value = self.memory.read(self.pc);
                self.pc +%= 1;

                self.XOR_A_r8(value);
            },
            0xFE => {
                // CP A, n8
                const value = self.memory.read(self.pc);
                self.pc +%= 1;

                self.CP_A_r8(value);
            },
            // ADD SP, i8
            0xE8 => {
                self.sp = self.ADD_SP_i8();
            },
            // LD HL, SP + i8
            0xF8 => {
                const newValue = decompose16BitValue(self.ADD_SP_i8());
                self.h = newValue[0];
                self.l = newValue[1];
            },
            0xF9 => {
                self.sp = combine8BitValues(self.h, self.l);
            },
            // Disable interupts
            0xF3 => {
                self.ime = false;
            },
            // Enable interupts
            0xFB => {
                self.ime = true;
            },
            0xCB => {
                const cbOpcode = self.memory.read(self.pc);
                self.pc +%= 1;

                self.executeOpcodeCb(cbOpcode);
            },

            // TODO might have to implement stop and halt instructions later

            else => {},
        }

        return opCycles;
    }

    fn executeOpcodeCb(self: *Cpu, opcode: u8) void {
        switch (opcode) {
            // RLC r8
            0x00 => {
                self.b = self.RLC(self.b);
            },
            0x01 => {
                self.c = self.RLC(self.c);
            },
            0x02 => {
                self.d = self.RLC(self.d);
            },
            0x03 => {
                self.e = self.RLC(self.e);
            },
            0x04 => {
                self.h = self.RLC(self.h);
            },
            0x05 => {
                self.l = self.RLC(self.l);
            },
            0x06 => {
                // RLC [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = self.RLC(value);
                self.memory.write(address, value);
            },
            0x07 => {
                self.a = self.RLC(self.a);
            },
            // RRC r8
            0x08 => {
                self.b = self.RRC(self.b);
            },
            0x09 => {
                self.c = self.RRC(self.c);
            },
            0x0A => {
                self.d = self.RRC(self.d);
            },
            0x0B => {
                self.e = self.RRC(self.e);
            },
            0x0C => {
                self.h = self.RRC(self.h);
            },
            0x0D => {
                self.l = self.RRC(self.l);
            },
            0x0E => {
                // RRC [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = self.RRC(value);
                self.memory.write(address, value);
            },
            0x0F => {
                self.a = self.RRC(self.a);
            },
            // RL r8
            0x10 => {
                self.b = self.RL(self.b);
            },
            0x11 => {
                self.c = self.RL(self.c);
            },
            0x12 => {
                self.d = self.RL(self.d);
            },
            0x13 => {
                self.e = self.RL(self.e);
            },
            0x14 => {
                self.h = self.RL(self.h);
            },
            0x15 => {
                self.l = self.RL(self.l);
            },
            0x16 => {
                // RL [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = self.RL(value);
                self.memory.write(address, value);
            },
            0x17 => {
                self.a = self.RL(self.a);
            },
            // RR r8
            0x18 => {
                self.b = self.RR(self.b);
            },
            0x19 => {
                self.c = self.RR(self.c);
            },
            0x1A => {
                self.d = self.RR(self.d);
            },
            0x1B => {
                self.e = self.RR(self.e);
            },
            0x1C => {
                self.h = self.RR(self.h);
            },
            0x1D => {
                self.l = self.RR(self.l);
            },
            0x1E => {
                // RR [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = self.RR(value);
                self.memory.write(address, value);
            },
            0x1F => {
                self.a = self.RR(self.a);
            },
            // SLA r8
            0x20 => {
                self.b = self.SLA(self.b);
            },
            0x21 => {
                self.c = self.SLA(self.c);
            },
            0x22 => {
                self.d = self.SLA(self.d);
            },
            0x23 => {
                self.e = self.SLA(self.e);
            },
            0x24 => {
                self.h = self.SLA(self.h);
            },
            0x25 => {
                self.l = self.SLA(self.l);
            },
            0x26 => {
                // SLA [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = self.SLA(value);
                self.memory.write(address, value);
            },
            0x27 => {
                self.a = self.SLA(self.a);
            },
            // SRA r8
            0x28 => {
                self.b = self.SRA(self.b);
            },
            0x29 => {
                self.c = self.SRA(self.c);
            },
            0x2A => {
                self.d = self.SRA(self.d);
            },
            0x2B => {
                self.e = self.SRA(self.e);
            },
            0x2C => {
                self.h = self.SRA(self.h);
            },
            0x2D => {
                self.l = self.SRA(self.l);
            },
            0x2E => {
                // SRA [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = self.SRA(value);
                self.memory.write(address, value);
            },
            0x2F => {
                self.a = self.SRA(self.a);
            },
            // SRL r8
            0x38 => {
                self.b = self.SRL(self.b);
            },
            0x39 => {
                self.c = self.SRL(self.c);
            },
            0x3A => {
                self.d = self.SRL(self.d);
            },
            0x3B => {
                self.e = self.SRL(self.e);
            },
            0x3C => {
                self.h = self.SRL(self.h);
            },
            0x3D => {
                self.l = self.SRL(self.l);
            },
            0x3E => {
                // SRL [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = self.SRL(value);
                self.memory.write(address, value);
            },
            0x3F => {
                self.a = self.SRL(self.a);
            },
            // SWAP r8
            0x30 => {
                self.b = self.SWAP(self.b);
            },
            0x31 => {
                self.c = self.SWAP(self.c);
            },
            0x32 => {
                self.d = self.SWAP(self.d);
            },
            0x33 => {
                self.e = self.SWAP(self.e);
            },
            0x34 => {
                self.h = self.SWAP(self.h);
            },
            0x35 => {
                self.l = self.SWAP(self.l);
            },
            0x36 => {
                // SWAP [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = self.SWAP(value);
                self.memory.write(address, value);
            },
            0x37 => {
                self.a = self.SWAP(self.a);
            },
            // BIT 0 r8
            0x40 => {
                self.BIT(self.b, 0);
            },
            0x41 => {
                self.BIT(self.c, 0);
            },
            0x42 => {
                self.BIT(self.d, 0);
            },
            0x43 => {
                self.BIT(self.e, 0);
            },
            0x44 => {
                self.BIT(self.h, 0);
            },
            0x45 => {
                self.BIT(self.l, 0);
            },
            0x46 => {
                // BIT 0 [HL]
                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.BIT(value, 0);
            },
            0x47 => {
                self.BIT(self.a, 0);
            },
            // BIT 1 r8
            0x48 => {
                self.BIT(self.b, 1);
            },
            0x49 => {
                self.BIT(self.c, 1);
            },
            0x4A => {
                self.BIT(self.d, 1);
            },
            0x4B => {
                self.BIT(self.e, 1);
            },
            0x4C => {
                self.BIT(self.h, 1);
            },
            0x4D => {
                self.BIT(self.l, 1);
            },
            0x4E => {
                // BIT 1 [HL]
                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.BIT(value, 1);
            },
            0x4F => {
                self.BIT(self.a, 1);
            },
            // BIT 2 r8
            0x50 => {
                self.BIT(self.b, 2);
            },
            0x51 => {
                self.BIT(self.c, 2);
            },
            0x52 => {
                self.BIT(self.d, 2);
            },
            0x53 => {
                self.BIT(self.e, 2);
            },
            0x54 => {
                self.BIT(self.h, 2);
            },
            0x55 => {
                self.BIT(self.l, 2);
            },
            0x56 => {
                // BIT 2 [HL]
                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.BIT(value, 2);
            },
            0x57 => {
                self.BIT(self.a, 2);
            },
            // BIT 3 r8
            0x58 => {
                self.BIT(self.b, 3);
            },
            0x59 => {
                self.BIT(self.c, 3);
            },
            0x5A => {
                self.BIT(self.d, 3);
            },
            0x5B => {
                self.BIT(self.e, 3);
            },
            0x5C => {
                self.BIT(self.h, 3);
            },
            0x5D => {
                self.BIT(self.l, 3);
            },
            0x5E => {
                // BIT 3 [HL]
                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.BIT(value, 3);
            },
            0x5F => {
                self.BIT(self.a, 3);
            },
            // BIT 4 r8
            0x60 => {
                self.BIT(self.b, 4);
            },
            0x61 => {
                self.BIT(self.c, 4);
            },
            0x62 => {
                self.BIT(self.d, 4);
            },
            0x63 => {
                self.BIT(self.e, 4);
            },
            0x64 => {
                self.BIT(self.h, 4);
            },
            0x65 => {
                self.BIT(self.l, 4);
            },
            0x66 => {
                // BIT 4 [HL]
                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.BIT(value, 4);
            },
            0x67 => {
                self.BIT(self.a, 4);
            },
            // BIT 5 r8
            0x68 => {
                self.BIT(self.b, 5);
            },
            0x69 => {
                self.BIT(self.c, 5);
            },
            0x6A => {
                self.BIT(self.d, 5);
            },
            0x6B => {
                self.BIT(self.e, 5);
            },
            0x6C => {
                self.BIT(self.h, 5);
            },
            0x6D => {
                self.BIT(self.l, 5);
            },
            0x6E => {
                // BIT 5 [HL]
                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.BIT(value, 5);
            },
            0x6F => {
                self.BIT(self.a, 5);
            },
            // BIT 6 r8
            0x70 => {
                self.BIT(self.b, 6);
            },
            0x71 => {
                self.BIT(self.c, 6);
            },
            0x72 => {
                self.BIT(self.d, 6);
            },
            0x73 => {
                self.BIT(self.e, 6);
            },
            0x74 => {
                self.BIT(self.h, 6);
            },
            0x75 => {
                self.BIT(self.l, 6);
            },
            0x76 => {
                // BIT 6 [HL]
                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.BIT(value, 6);
            },
            0x77 => {
                self.BIT(self.a, 6);
            },
            // BIT 7 r8
            0x78 => {
                self.BIT(self.b, 7);
            },
            0x79 => {
                self.BIT(self.c, 7);
            },
            0x7A => {
                self.BIT(self.d, 7);
            },
            0x7B => {
                self.BIT(self.e, 7);
            },
            0x7C => {
                self.BIT(self.h, 7);
            },
            0x7D => {
                self.BIT(self.l, 7);
            },
            0x7E => {
                // BIT 7 [HL]
                const address = combine8BitValues(self.h, self.l);
                const value = self.memory.read(address);
                self.BIT(value, 7);
            },
            0x7F => {
                self.BIT(self.a, 7);
            },
            // RES 0 r8
            0x80 => {
                self.b = RES(self.b, 0);
            },
            0x81 => {
                self.c = RES(self.c, 0);
            },
            0x82 => {
                self.d = RES(self.d, 0);
            },
            0x83 => {
                self.e = RES(self.e, 0);
            },
            0x84 => {
                self.h = RES(self.h, 0);
            },
            0x85 => {
                self.l = RES(self.l, 0);
            },
            0x86 => {
                // RES 0 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = RES(value, 0);
                self.memory.write(address, value);
            },
            0x87 => {
                self.a = RES(self.a, 0);
            },
            // RES 1 r8
            0x88 => {
                self.b = RES(self.b, 1);
            },
            0x89 => {
                self.c = RES(self.c, 1);
            },
            0x8A => {
                self.d = RES(self.d, 1);
            },
            0x8B => {
                self.e = RES(self.e, 1);
            },
            0x8C => {
                self.h = RES(self.h, 1);
            },
            0x8D => {
                self.l = RES(self.l, 1);
            },
            0x8E => {
                // RES 1 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = RES(value, 1);
                self.memory.write(address, value);
            },
            0x8F => {
                self.a = RES(self.a, 1);
            },
            // RES 2 r8
            0x90 => {
                self.b = RES(self.b, 2);
            },
            0x91 => {
                self.c = RES(self.c, 2);
            },
            0x92 => {
                self.d = RES(self.d, 2);
            },
            0x93 => {
                self.e = RES(self.e, 2);
            },
            0x94 => {
                self.h = RES(self.h, 2);
            },
            0x95 => {
                self.l = RES(self.l, 2);
            },
            0x96 => {
                // RES 2 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = RES(value, 2);
                self.memory.write(address, value);
            },
            0x97 => {
                self.a = RES(self.a, 2);
            },
            // RES 1 r8
            0x98 => {
                self.b = RES(self.b, 3);
            },
            0x99 => {
                self.c = RES(self.c, 3);
            },
            0x9A => {
                self.d = RES(self.d, 3);
            },
            0x9B => {
                self.e = RES(self.e, 3);
            },
            0x9C => {
                self.h = RES(self.h, 3);
            },
            0x9D => {
                self.l = RES(self.l, 3);
            },
            0x9E => {
                // RES 3 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = RES(value, 3);
                self.memory.write(address, value);
            },
            0x9F => {
                self.a = RES(self.a, 3);
            },
            // RES 4 r8
            0xA0 => {
                self.b = RES(self.b, 4);
            },
            0xA1 => {
                self.c = RES(self.c, 4);
            },
            0xA2 => {
                self.d = RES(self.d, 4);
            },
            0xA3 => {
                self.e = RES(self.e, 4);
            },
            0xA4 => {
                self.h = RES(self.h, 4);
            },
            0xA5 => {
                self.l = RES(self.l, 4);
            },
            0xA6 => {
                // RES 4 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = RES(value, 4);
                self.memory.write(address, value);
            },
            0xA7 => {
                self.a = RES(self.a, 4);
            },
            // RES 5 r8
            0xA8 => {
                self.b = RES(self.b, 5);
            },
            0xA9 => {
                self.c = RES(self.c, 5);
            },
            0xAA => {
                self.d = RES(self.d, 5);
            },
            0xAB => {
                self.e = RES(self.e, 5);
            },
            0xAC => {
                self.h = RES(self.h, 5);
            },
            0xAD => {
                self.l = RES(self.l, 5);
            },
            0xAE => {
                // RES 5 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = RES(value, 5);
                self.memory.write(address, value);
            },
            0xAF => {
                self.a = RES(self.a, 5);
            },
            // RES 6 r8
            0xb0 => {
                self.b = RES(self.b, 6);
            },
            0xB1 => {
                self.c = RES(self.c, 6);
            },
            0xB2 => {
                self.d = RES(self.d, 6);
            },
            0xB3 => {
                self.e = RES(self.e, 6);
            },
            0xB4 => {
                self.h = RES(self.h, 6);
            },
            0xB5 => {
                self.l = RES(self.l, 6);
            },
            0xB6 => {
                // RES 6 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = RES(value, 6);
                self.memory.write(address, value);
            },
            0xB7 => {
                self.a = RES(self.a, 6);
            },
            // RES 9 r8
            0xB8 => {
                self.b = RES(self.b, 7);
            },
            0xB9 => {
                self.c = RES(self.c, 7);
            },
            0xBA => {
                self.d = RES(self.d, 7);
            },
            0xBB => {
                self.e = RES(self.e, 7);
            },
            0xBC => {
                self.h = RES(self.h, 7);
            },
            0xBD => {
                self.l = RES(self.l, 7);
            },
            0xBE => {
                // RES 7 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = RES(value, 7);
                self.memory.write(address, value);
            },
            0xBF => {
                self.a = RES(self.a, 7);
            },
            // SET 0 r8
            0xC0 => {
                self.b = SET(self.b, 0);
            },
            0xC1 => {
                self.c = SET(self.c, 0);
            },
            0xC2 => {
                self.d = SET(self.d, 0);
            },
            0xC3 => {
                self.e = SET(self.e, 0);
            },
            0xC4 => {
                self.h = SET(self.h, 0);
            },
            0xC5 => {
                self.l = SET(self.l, 0);
            },
            0xC6 => {
                // SET 0 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = SET(value, 0);
                self.memory.write(address, value);
            },
            0xC7 => {
                self.a = SET(self.a, 0);
            },
            // SET 1 r8
            0xC8 => {
                self.b = SET(self.b, 1);
            },
            0xC9 => {
                self.c = SET(self.c, 1);
            },
            0xCA => {
                self.d = SET(self.d, 1);
            },
            0xCB => {
                self.e = SET(self.e, 1);
            },
            0xCC => {
                self.h = SET(self.h, 1);
            },
            0xCD => {
                self.l = SET(self.l, 1);
            },
            0xCE => {
                // SET 1 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = SET(value, 1);
                self.memory.write(address, value);
            },
            0xCF => {
                self.a = SET(self.a, 1);
            },
            // SET 2 r8
            0xD0 => {
                self.b = SET(self.b, 2);
            },
            0xD1 => {
                self.c = SET(self.c, 2);
            },
            0xD2 => {
                self.d = SET(self.d, 2);
            },
            0xD3 => {
                self.e = SET(self.e, 2);
            },
            0xD4 => {
                self.h = SET(self.h, 2);
            },
            0xD5 => {
                self.l = SET(self.l, 2);
            },
            0xD6 => {
                // SET 2 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = SET(value, 2);
                self.memory.write(address, value);
            },
            0xD7 => {
                self.a = SET(self.a, 2);
            },
            // SET 1 r8
            0xD8 => {
                self.b = SET(self.b, 3);
            },
            0xD9 => {
                self.c = SET(self.c, 3);
            },
            0xDA => {
                self.d = SET(self.d, 3);
            },
            0xDB => {
                self.e = SET(self.e, 3);
            },
            0xDC => {
                self.h = SET(self.h, 3);
            },
            0xDD => {
                self.l = SET(self.l, 3);
            },
            0xDE => {
                // SET 3 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = SET(value, 3);
                self.memory.write(address, value);
            },
            0xDF => {
                self.a = SET(self.a, 3);
            },
            // SET 4 r8
            0xE0 => {
                self.b = SET(self.b, 4);
            },
            0xE1 => {
                self.c = SET(self.c, 4);
            },
            0xE2 => {
                self.d = SET(self.d, 4);
            },
            0xE3 => {
                self.e = SET(self.e, 4);
            },
            0xE4 => {
                self.h = SET(self.h, 4);
            },
            0xE5 => {
                self.l = SET(self.l, 4);
            },
            0xE6 => {
                // SET 4 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = SET(value, 4);
                self.memory.write(address, value);
            },
            0xE7 => {
                self.a = SET(self.a, 4);
            },
            // SET 5 r8
            0xE8 => {
                self.b = SET(self.b, 5);
            },
            0xE9 => {
                self.c = SET(self.c, 5);
            },
            0xEA => {
                self.d = SET(self.d, 5);
            },
            0xEB => {
                self.e = SET(self.e, 5);
            },
            0xEC => {
                self.h = SET(self.h, 5);
            },
            0xED => {
                self.l = SET(self.l, 5);
            },
            0xEE => {
                // SET 5 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = SET(value, 5);
                self.memory.write(address, value);
            },
            0xEF => {
                self.a = SET(self.a, 5);
            },
            // SET 6 r8
            0xf0 => {
                self.b = SET(self.b, 6);
            },
            0xF1 => {
                self.c = SET(self.c, 6);
            },
            0xF2 => {
                self.d = SET(self.d, 6);
            },
            0xF3 => {
                self.e = SET(self.e, 6);
            },
            0xF4 => {
                self.h = SET(self.h, 6);
            },
            0xF5 => {
                self.l = SET(self.l, 6);
            },
            0xF6 => {
                // SET 6 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = SET(value, 6);
                self.memory.write(address, value);
            },
            0xF7 => {
                self.a = SET(self.a, 6);
            },
            // SET 9 r8
            0xF8 => {
                self.b = SET(self.b, 7);
            },
            0xF9 => {
                self.c = SET(self.c, 7);
            },
            0xFA => {
                self.d = SET(self.d, 7);
            },
            0xFB => {
                self.e = SET(self.e, 7);
            },
            0xFC => {
                self.h = SET(self.h, 7);
            },
            0xFD => {
                self.l = SET(self.l, 7);
            },
            0xFE => {
                // SET 7 [HL]
                const address = combine8BitValues(self.h, self.l);
                var value = self.memory.read(address);
                value = SET(value, 7);
                self.memory.write(address, value);
            },
            0xFF => {
                self.a = SET(self.a, 7);
            },
        }
    }

    // Flag functions
    fn setFlag(self: *Cpu, flag: Flag) void {
        switch (flag) {
            Flag.c => {
                self.f |= 1 << 4;
            },
            Flag.h => {
                self.f |= 1 << 5;
            },
            Flag.n => {
                self.f |= 1 << 6;
            },
            Flag.z => {
                self.f |= 1 << 7;
            },
        }
    }

    fn clearFlag(self: *Cpu, flag: Flag) void {
        switch (flag) {
            Flag.c => {
                self.f &= ~(@as(u8, 1) << 4);
            },
            Flag.h => {
                self.f &= ~(@as(u8, 1) << 5);
            },
            Flag.n => {
                self.f &= ~(@as(u8, 1) << 6);
            },
            Flag.z => {
                self.f &= ~(@as(u8, 1) << 7);
            },
        }
    }

    fn flagIsSet(self: *Cpu, flag: Flag) u8 {
        var isSet: bool = false;
        switch (flag) {
            Flag.c => {
                if ((self.f & (1 << 4)) != 0) {
                    isSet = true;
                }
            },
            Flag.h => {
                if ((self.f & (1 << 5)) != 0) {
                    isSet = true;
                }
            },
            Flag.n => {
                if ((self.f & (1 << 6)) != 0) {
                    isSet = true;
                }
            },
            Flag.z => {
                if ((self.f & (1 << 7)) != 0) {
                    isSet = true;
                }
            },
        }
        if (isSet) {
            return 1;
        } else {
            return 0;
        }
    }

    // helper functions

    fn combine8BitValues(hiValue: u8, loValue: u8) u16 {
        const newValue: u16 = @as(u16, hiValue) << 8 | loValue;
        return newValue;
    }

    fn decompose16BitValue(value: u16) [2]u8 {
        // store as two 8 bit ints in registers
        const hiValue: u8 = @truncate(value >> 8);
        const loValue: u8 = @truncate(value);

        return .{ hiValue, loValue };
    }

    fn checkHalfCarry16(a: u16, b: u16) bool {
        return ((a & 0x0FFF) + (b & 0x0FFF)) > 0x0FFF;
    }

    fn checkCarry16(a: u16, b: u16) bool {
        return (@as(u32, a) + @as(u32, b)) > 0xFFFF;
    }

    fn checkHalfCarry8(a: u8, b: u8) bool {
        return ((a & 0x0F) + (b & 0x0F)) & 0x10 == 0x10;
    }

    fn checkHalfCarry8WithCarry(a: u8, b: u8, c: u8) bool {
        return ((a & 0x0F) + (b & 0x0F) + (c & 0x0F)) & 0x10 == 0x10;
    }

    fn checkCarry8(a: u8, b: u8) bool {
        const result: u16 = @as(u16, a) + @as(u16, b);
        return result > 0xFF;
    }

    fn checkCarry8WithCarry(a: u8, b: u8, c: u8) bool {
        const result: u16 = @as(u16, a) + @as(u16, b) + @as(u16, c);
        return result > 0xFF;
    }

    fn checkBorrow8(a: u8, b: u8) bool {
        return b > a;
    }

    fn checkBorrow8WithCarry(a: u8, b: u8, c: u8) bool {
        if (a < b) return true;
        if (a == b and c > 0) return true;
        return (a -% b) < c;
    }

    fn checkHalfBorrow8(a: u8, b: u8) bool {
        return (a & 0x0F) < (b & 0x0F);
    }

    fn checkHalfBorrow8WithCarry(a: u8, b: u8, c: u8) bool {
        const lowerA = a & 0x0F;
        const lowerB = b & 0x0F;
        const lowerC = c & 0x0F;

        if (lowerA < lowerB) return true;
        if (lowerA == lowerB and lowerC > 0) return true;
        return (lowerA -% lowerB) < lowerC;
    }

    // instruction implementation

    fn LD_r16_n16(self: *Cpu, hiRegister: *u8, loRegister: *u8) void {
        const lo: u8 = self.memory.read(self.pc);
        const hi: u8 = self.memory.read(self.pc + 1);
        self.pc +%= 2;

        hiRegister.* = hi;
        loRegister.* = lo;
    }

    fn LD_r8_n8(self: *Cpu, register: *u8) void {
        const value: u8 = self.memory.read(self.pc);
        self.pc +%= 1;
        register.* = value;
    }

    fn LD_r8_r8(loadRegister: *u8, copyRegister: *u8) void {
        loadRegister.* = copyRegister.*;
    }

    fn LD_r8_HL(self: *Cpu, register: *u8) void {
        const address = combine8BitValues(self.h, self.l);
        register.* = self.memory.read(address);
    }

    fn LD_HL_r8(self: *Cpu, register: *u8) void {
        const address = combine8BitValues(self.h, self.l);
        self.memory.write(address, register.*);
    }

    fn LD_r16_A(self: *Cpu, hiRegister: *u8, loRegister: *u8) void {
        const address: u16 = combine8BitValues(hiRegister.*, loRegister.*);
        self.memory.write(address, self.a);
    }

    fn LD_n16_A(self: *Cpu, address: u16) void {
        self.memory.write(address, self.a);
    }

    fn LD_A_r16(self: *Cpu, hiRegister: *u8, loRegister: *u8) void {
        const address: u16 = combine8BitValues(hiRegister.*, loRegister.*);
        self.a = self.memory.read(address);
    }

    fn LD_A_n16(self: *Cpu, address: u16) void {
        self.a = self.memory.read(address);
    }

    fn INC_r16(hiRegister: *u8, loRegister: *u8) void {
        var newValue: u16 = combine8BitValues(hiRegister.*, loRegister.*);
        newValue = newValue +% 1;

        const decomposedValues = decompose16BitValue(newValue);

        hiRegister.* = decomposedValues[0];
        loRegister.* = decomposedValues[1];
    }

    fn DEC_r16(hiRegister: *u8, loRegister: *u8) void {
        var newValue: u16 = combine8BitValues(hiRegister.*, loRegister.*);
        newValue = newValue -% 1;

        const decomposedValues = decompose16BitValue(newValue);

        hiRegister.* = decomposedValues[0];
        loRegister.* = decomposedValues[1];
    }

    fn INC_r8(self: *Cpu, register: *u8) void {
        const halfCarry = checkHalfCarry8(register.*, 1);

        if (halfCarry) {
            self.setFlag(Flag.h);
        } else {
            self.clearFlag(Flag.h);
        }

        register.* = register.* +% 1;

        if (register.* == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        self.clearFlag(Flag.n);
    }

    fn DEC_r8(self: *Cpu, register: *u8) void {
        const halfBorrow = checkHalfBorrow8(register.*, 1);

        if (halfBorrow) {
            self.setFlag(Flag.h);
        } else {
            self.clearFlag(Flag.h);
        }

        register.* = register.* -% 1;

        if (register.* == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        self.setFlag(Flag.n);
    }

    fn ADD_HL_r16(self: *Cpu, hiRegister: u8, loRegister: u8) void {
        var hl: u16 = combine8BitValues(self.h, self.l);
        const valueToAdd: u16 = combine8BitValues(hiRegister, loRegister);

        const halfCarry = checkHalfCarry16(hl, valueToAdd);
        if (halfCarry) {
            self.setFlag(Flag.h);
        } else {
            self.clearFlag(Flag.h);
        }

        const carry = checkCarry16(hl, valueToAdd);
        if (carry) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        hl = hl +% valueToAdd;

        const decomposedValues = decompose16BitValue(hl);

        self.h = decomposedValues[0];
        self.l = decomposedValues[1];

        self.clearFlag(Flag.n);
    }

    fn ADD_A_r8(self: *Cpu, register: u8) void {
        const halfCarry = checkHalfCarry8(self.a, register);
        const carry = checkCarry8(self.a, register);

        self.a = self.a +% register;

        if (self.a == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        if (halfCarry) {
            self.setFlag(Flag.h);
        } else {
            self.clearFlag(Flag.h);
        }

        if (carry) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        self.clearFlag(Flag.n);
    }

    fn ADC_A_r8(self: *Cpu, register: u8) void {
        const carrySet: u8 = self.flagIsSet(Flag.c);
        const halfCarry = checkHalfCarry8WithCarry(self.a, register, carrySet);
        const carry = checkCarry8WithCarry(self.a, register, carrySet);

        self.a = self.a +% register +% carrySet;

        if (self.a == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        if (halfCarry) {
            self.setFlag(Flag.h);
        } else {
            self.clearFlag(Flag.h);
        }

        if (carry) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        self.clearFlag(Flag.n);
    }

    fn SUB_A_r8(self: *Cpu, register: u8) void {
        const halfBorrow = checkHalfBorrow8(self.a, register);
        const borrow = checkBorrow8(self.a, register);

        self.a = self.a -% register;

        if (self.a == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        if (halfBorrow) {
            self.setFlag(Flag.h);
        } else {
            self.clearFlag(Flag.h);
        }

        if (borrow) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        self.setFlag(Flag.n);
    }

    fn SBC_A_r8(self: *Cpu, register: u8) void {
        const carrySet: u8 = self.flagIsSet(Flag.c);
        const halfBorrow = checkHalfBorrow8WithCarry(self.a, register, carrySet);
        const borrow = checkBorrow8WithCarry(self.a, register, carrySet);

        self.a = self.a -% register -% carrySet;

        if (self.a == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        if (halfBorrow) {
            self.setFlag(Flag.h);
        } else {
            self.clearFlag(Flag.h);
        }

        if (borrow) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        self.setFlag(Flag.n);
    }

    fn AND_A_r8(self: *Cpu, register: u8) void {
        self.a &= register;

        if (self.a == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        self.clearFlag(Flag.n);
        self.setFlag(Flag.h);
        self.clearFlag(Flag.c);
    }

    fn XOR_A_r8(self: *Cpu, register: u8) void {
        self.a ^= register;

        if (self.a == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        self.clearFlag(Flag.n);
        self.clearFlag(Flag.h);
        self.clearFlag(Flag.c);
    }

    fn OR_A_r8(self: *Cpu, register: u8) void {
        self.a |= register;

        if (self.a == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        self.clearFlag(Flag.n);
        self.clearFlag(Flag.h);
        self.clearFlag(Flag.c);
    }

    fn CP_A_r8(self: *Cpu, register: u8) void {
        var aCopy = self.a;

        const halfBorrow = checkHalfBorrow8(aCopy, register);
        const borrow = checkBorrow8(aCopy, register);

        aCopy -%= register;

        if (aCopy == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        if (halfBorrow) {
            self.setFlag(Flag.h);
        } else {
            self.clearFlag(Flag.h);
        }

        if (borrow) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        self.setFlag(Flag.n);
    }

    fn JR(self: *Cpu) void {
        const offset: i8 = @bitCast(self.memory.read(self.pc));
        self.pc +%= 1;

        var pcCopy: i32 = @intCast(self.pc);
        pcCopy += offset;

        const newPc: u16 = @intCast(pcCopy);

        self.pc = newPc;
    }

    fn JP_n16(self: *Cpu) void {
        const lo: u8 = self.memory.read(self.pc);
        const hi: u8 = self.memory.read(self.pc + 1);
        const address = combine8BitValues(hi, lo);

        self.pc = address;
    }

    fn POP_r16(self: *Cpu, hiRegister: *u8, loRegister: *u8) void {
        const lo: u8 = self.memory.read(self.sp);
        const hi: u8 = self.memory.read(self.sp + 1);
        self.sp +%= 2;

        hiRegister.* = hi;
        loRegister.* = lo;
    }

    fn PUSH_r16(self: *Cpu, hiRegister: u8, loRegister: u8) void {
        self.sp -%= 1;
        self.memory.write(self.sp, hiRegister);
        self.sp -%= 1;
        self.memory.write(self.sp, loRegister);
    }

    fn RET(self: *Cpu) void {
        const lo: u8 = self.memory.read(self.sp);
        const hi: u8 = self.memory.read(self.sp + 1);
        self.sp +%= 2;

        const address = combine8BitValues(hi, lo);

        self.pc = address;
    }

    fn CALL_n16(self: *Cpu) void {
        const lo: u8 = self.memory.read(self.pc);
        const hi: u8 = self.memory.read(self.pc + 1);
        const address = combine8BitValues(hi, lo);

        const returnAddress = self.pc +% 2;
        const decomposedPc = decompose16BitValue(returnAddress);

        self.sp -%= 1;
        self.memory.write(self.sp, decomposedPc[0]);
        self.sp -%= 1;
        self.memory.write(self.sp, decomposedPc[1]);

        self.pc = address;
    }

    fn RST(self: *Cpu, vec: u16) void {
        const decomposedPc = decompose16BitValue(self.pc);

        self.sp -%= 1;
        self.memory.write(self.sp, decomposedPc[0]);
        self.sp -%= 1;
        self.memory.write(self.sp, decomposedPc[1]);

        self.pc = vec;
    }

    fn ADD_SP_i8(self: *Cpu) u16 {
        const valueU8: u8 = self.memory.read(self.pc);
        const value: i8 = @bitCast(valueU8);
        self.pc +%= 1;

        const lowBits: u8 = @truncate(self.sp);

        const halfCarry = checkHalfCarry8(lowBits, valueU8);
        const carry = checkCarry8(lowBits, valueU8);

        if (halfCarry) {
            self.setFlag(Flag.h);
        } else {
            self.clearFlag(Flag.h);
        }

        if (carry) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        self.clearFlag(Flag.z);
        self.clearFlag(Flag.n);

        var spCopy: i16 = @bitCast(self.sp);
        spCopy +%= value;

        const newSp: u16 = @bitCast(spCopy);
        return newSp;
    }

    // Bit shift instructions

    fn RRC(self: *Cpu, value: u8) u8 {
        const oldBit0: bool = (value & 0x1) != 0;

        if (oldBit0) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        const rotatedValue = math.rotr(u8, value, 1);

        if (rotatedValue == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        self.clearFlag(Flag.n);
        self.clearFlag(Flag.h);

        return rotatedValue;
    }

    fn RRCA(self: *Cpu) void {
        const oldBit0: bool = (self.a & 0x1) != 0;

        if (oldBit0) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        self.a = math.rotr(u8, self.a, 1);

        self.clearFlag(Flag.z);
        self.clearFlag(Flag.n);
        self.clearFlag(Flag.h);
    }

    fn RR(self: *Cpu, value: u8) u8 {
        const carryFlagBit: u1 = @intCast(self.flagIsSet(Flag.c));
        const valueCarry: u9 = @as(u9, value) << 1 | carryFlagBit;

        const rotatedValue = math.rotr(u9, valueCarry, 1);
        const newRegister: u8 = @truncate(rotatedValue >> 1);

        const cFlagSet = rotatedValue & 1;

        if (cFlagSet == 1) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        if (newRegister == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }
        self.clearFlag(Flag.n);
        self.clearFlag(Flag.h);

        return newRegister;
    }

    fn RRA(self: *Cpu) void {
        const carryFlagBit: u1 = @intCast(self.flagIsSet(Flag.c));
        const aCarry: u9 = @as(u9, self.a) << 1 | carryFlagBit;

        const rotatedValue = math.rotr(u9, aCarry, 1);
        self.a = @truncate(rotatedValue >> 1);

        const cFlagSet = rotatedValue & 1;

        if (cFlagSet == 1) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        self.clearFlag(Flag.z);
        self.clearFlag(Flag.n);
        self.clearFlag(Flag.h);
    }

    fn RLC(self: *Cpu, value: u8) u8 {
        const oldBit7: bool = (value & 0b10000000) != 0;

        if (oldBit7) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        const rotatedValue = math.rotl(u8, value, 1);

        if (rotatedValue == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        self.clearFlag(Flag.n);
        self.clearFlag(Flag.h);

        return rotatedValue;
    }

    fn RLCA(self: *Cpu) void {
        const oldBit7: bool = (self.a & 0b10000000) != 0;

        if (oldBit7) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        self.a = math.rotl(u8, self.a, 1);

        self.clearFlag(Flag.z);
        self.clearFlag(Flag.n);
        self.clearFlag(Flag.h);
    }

    fn RL(self: *Cpu, value: u8) u8 {
        const carryFlagBit: u1 = @intCast(self.flagIsSet(Flag.c));
        const valueCarry: u9 = @as(u9, value) << 1 | carryFlagBit;

        const rotatedValue = math.rotl(u9, valueCarry, 1);
        const newRegister: u8 = @truncate(rotatedValue >> 1);

        const cFlagSet = rotatedValue & 1;

        if (cFlagSet == 1) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        if (newRegister == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }
        self.clearFlag(Flag.n);
        self.clearFlag(Flag.h);

        return newRegister;
    }

    fn RLA(self: *Cpu) void {
        const carryFlagBit: u1 = @intCast(self.flagIsSet(Flag.c));
        const aCarry: u9 = @as(u9, self.a) << 1 | carryFlagBit;

        const rotatedValue = math.rotl(u9, aCarry, 1);
        self.a = @truncate(rotatedValue >> 1);

        const cFlagSet = rotatedValue & 1;

        if (cFlagSet == 1) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        self.clearFlag(Flag.z);
        self.clearFlag(Flag.n);
        self.clearFlag(Flag.h);
    }

    fn SRA(self: *Cpu, value: u8) u8 {
        const oldBit0: bool = (value & 0x1) != 0;

        if (oldBit0) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        const shiftedValue: u8 = @truncate(value >> 1 | (value & 1 << 7));

        if (shiftedValue == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        self.clearFlag(Flag.n);
        self.clearFlag(Flag.h);

        return shiftedValue;
    }

    fn SRL(self: *Cpu, value: u8) u8 {
        const oldBit0: bool = (value & 0x1) != 0;

        if (oldBit0) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        const shiftedValue: u8 = @truncate(value >> 1);

        if (shiftedValue == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        self.clearFlag(Flag.n);
        self.clearFlag(Flag.h);

        return shiftedValue;
    }

    fn SLA(self: *Cpu, value: u8) u8 {
        const oldBit7: bool = (value & (1 << 7)) != 0;

        if (oldBit7) {
            self.setFlag(Flag.c);
        } else {
            self.clearFlag(Flag.c);
        }

        const shiftedValue: u8 = @truncate(value << 1);

        if (shiftedValue == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        self.clearFlag(Flag.n);
        self.clearFlag(Flag.h);

        return shiftedValue;
    }

    fn SWAP(self: *Cpu, value: u8) u8 {
        const swappedValue: u8 = (value << 4) | (value >> 4);

        if (swappedValue == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        self.clearFlag(Flag.c);
        self.clearFlag(Flag.n);
        self.clearFlag(Flag.h);

        return swappedValue;
    }

    // Bit flag instructions

    fn BIT(self: *Cpu, value: u8, bit: u3) void {
        const bitSet = (value & (math.shl(u8, 1, bit))) != 0;

        if (!bitSet) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        self.clearFlag(Flag.n);
        self.setFlag(Flag.h);
    }

    fn RES(value: u8, bit: u3) u8 {
        const mask = ~(math.shl(u8, 1, bit));
        return value & mask;
    }

    fn SET(value: u8, bit: u3) u8 {
        return value | math.shl(u8, 1, bit);
    }
};
