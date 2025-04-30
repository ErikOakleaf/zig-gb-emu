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

const Cpu = struct {
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

    // executes opcode returns the ammount of cycles
    fn executeOpcode(self: *Cpu, opcode: u8) u8 {
        const opCycles = OP_CYCLES[opcode];

        switch (opcode) {
            0x00 => {},
            // LD r16n16
            0x01 => {
                self.loadRegister16(&self.b, &self.c);
            },
            0x11 => {
                self.loadRegister16(&self.d, &self.e);
            },
            0x21 => {
                self.loadRegister16(&self.h, &self.l);
            },
            0x31 => {
                self.loadRegisterSP();
            },
            // INC r8
            0x04 => {
                self.incrementRegister8(&self.b);
            },
            0x14 => {
                self.incrementRegister8(&self.d);
            },
            0x24 => {
                self.incrementRegister8(&self.h);
            },
        }

        return opCycles;
    }

    fn setFlag(self: *Cpu, flag: Flag) void {
        self.f |= 1 << @intFromEnum(flag);
    }

    fn clearFlag(self: *Cpu, flag: Flag) void {
        self.f &= ~(1 << @intFromEnum(flag));
    }

    fn loadRegister16(self: *Cpu, hiRegister: *u8, loRegister: *u8) void {
        const lo: u8 = self.memory.read(self.pc);
        const hi: u8 = self.memory.read(self.pc + 1);
        self.pc += 2;

        hiRegister.* = hi;
        loRegister.* = lo;
    }

    fn loadRegisterSP(self: *Cpu) void {
        const lo: u8 = self.memory.read(self.pc);
        const hi: u8 = self.memory.read(self.pc + 1);
        self.pc += 2;

        const value: u16 = (@as(u16, hi) << 8) | lo;

        self.sp = value;
    }

    fn incrementRegister8(self: *Cpu, register: *u8) void {
        // check for half carry

        const halfCarry = (((register.* & 0x0F) + (1 & 0x0F)) & 0x10) == 0x10;

        if (halfCarry) {
            self.setFlag(Flag.h);
        } else {
            self.clearFlag(Flag.h);
        }

        register.* += 1;

        if (register.* == 0) {
            self.setFlag(Flag.z);
        } else {
            self.clearFlag(Flag.z);
        }

        self.clearFlag(Flag.n);
    }
};
