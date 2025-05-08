const std = @import("std");
const mem = @import("memory.zig");

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
    memory: *mem.Memory,

    pub fn init(self: *Cpu, allocator: *std.mem.Allocator) !void {
        const memPtr = try allocator.create(mem.Memory);
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
    }

    pub fn deinit(self: *Cpu, allocator: *std.mem.Allocator) void {
        allocator.destroy(self.memory);
        self.memory = undefined;
    }

    pub fn tick(self: *Cpu) u8 {
        const opcode: u8 = self.memory.read(self.pc);

        // std.debug.print("reading opcode: {d}, at memory: {d}\n", .{ opcode, self.pc });

        self.pc += 1;

        const cycles = self.executeOpcode(opcode);
        return cycles;
    }

    // executes opcode returns the ammount of cycles
    fn executeOpcode(self: *Cpu, opcode: u8) u8 {
        const opCycles = OP_CYCLES[opcode];

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
                self.pc += 2;

                const value: u16 = (@as(u16, hi) << 8) | lo;

                self.sp = value;
            },
            // LD N16 A
            0x02 => {
                self.LD_r16_A(&self.b, &self.c);
            },
            0x12 => {
                self.LD_r16_A(&self.d, &self.e);
            },
            0x22 => {
                self.LD_r16_A(&self.h, &self.l);

                // increment hl
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
                self.sp += 1;
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

                const address: u16 = @as(u16, self.h) << 8 | self.l;
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
                self.pc += 1;

                self.memory.write(address, value);
            },
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
            else => {},
        }

        return opCycles;
    }

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

    fn checkHalfBorrow8(a: u8, b: u8) bool {
        return (a & 0x0F) < (b & 0x0F);
    }

    fn LD_r16_n16(self: *Cpu, hiRegister: *u8, loRegister: *u8) void {
        const lo: u8 = self.memory.read(self.pc);
        const hi: u8 = self.memory.read(self.pc + 1);
        self.pc += 2;

        hiRegister.* = hi;
        loRegister.* = lo;
    }

    fn LD_r8_n8(self: *Cpu, register: *u8) void {
        const value: u8 = self.memory.read(self.pc);
        self.pc += 1;
        register.* = value;
    }

    fn LD_r16_A(self: *Cpu, hiRegister: *u8, loRegister: *u8) void {
        const address: u16 = combine8BitValues(hiRegister.*, loRegister.*);
        self.memory.write(address, self.a);
    }

    fn INC_r16(hiRegister: *u8, loRegister: *u8) void {
        // load 8 bit registers as 16 bit int
        var newValue: u16 = combine8BitValues(hiRegister.*, loRegister.*);
        newValue += 1;

        // store as two 8 bit ints in registers
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
        const halfCarry = checkHalfBorrow8(register.*, 1);

        if (halfCarry) {
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
        // load 8 bit registers as 16 bit int
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

        // store as two 8 bit ints in registers
        const decomposedValues = decompose16BitValue(hl);

        self.h = decomposedValues[0];
        self.l = decomposedValues[1];

        self.clearFlag(Flag.n);
    }
};
