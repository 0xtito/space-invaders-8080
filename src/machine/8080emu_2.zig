const std = @import("std");

const main = @import("../main.zig");

const State8080 = main.State8080;

fn parity(x: u8, size: u8) bool {
    var _x: u8 = x;
    var p: u8 = 0;
    var i: u8 = 0;
    while (i < size) : (i += 1) {
        if (_x & 0x1 != 0) p += 1;
        _x = _x >> 1;
    }
    return (p & 0x1) == 0;
}

pub const cycles8080 = [_]u8{
    4,  10, 7,  5,  5,  5,  7,  4,  4,  10, 7,  5,  5,  5,  7, 4,
    4,  10, 7,  5,  5,  5,  7,  4,  4,  10, 7,  5,  5,  5,  7, 4,
    4,  10, 16, 5,  5,  5,  7,  4,  4,  10, 16, 5,  5,  5,  7, 4,
    4,  10, 13, 5,  10, 10, 10, 4,  4,  10, 13, 5,  5,  5,  7, 4,

    5,  5,  5,  5,  5,  5,  7,  5,  5,  5,  5,  5,  5,  5,  7, 5,
    5,  5,  5,  5,  5,  5,  7,  5,  5,  5,  5,  5,  5,  5,  7, 5,
    5,  5,  5,  5,  5,  5,  7,  5,  5,  5,  5,  5,  5,  5,  7, 5,
    7,  7,  7,  7,  7,  7,  7,  7,  5,  5,  5,  5,  5,  5,  7, 5,

    4,  4,  4,  4,  4,  4,  7,  4,  4,  4,  4,  4,  4,  4,  7, 4,
    4,  4,  4,  4,  4,  4,  7,  4,  4,  4,  4,  4,  4,  4,  7, 4,
    4,  4,  4,  4,  4,  4,  7,  4,  4,  4,  4,  4,  4,  4,  7, 4,
    4,  4,  4,  4,  4,  4,  7,  4,  4,  4,  4,  4,  4,  4,  7, 4,

    11, 10, 10, 10, 17, 11, 7,  11, 11, 10, 10, 10, 10, 17, 7, 11,
    11, 10, 10, 10, 17, 11, 7,  11, 11, 10, 10, 10, 10, 17, 7, 11,
    11, 10, 10, 18, 17, 11, 7,  11, 11, 5,  10, 5,  17, 17, 7, 11,
    11, 10, 10, 4,  17, 11, 7,  11, 11, 5,  10, 4,  17, 17, 7, 11,
};

pub fn logicFlagsA(state: *State8080) void {
    state.cc.cy = false;
    state.cc.ac = false;
    state.cc.z = (state.a == 0);
    state.cc.s = (state.a & 0x80 != 0);
    state.cc.p = parity(state.a, 8);
}

pub fn arithFlagsA(state: *State8080, res: u16) void {
    state.cc.cy = (res > 0xff);
    state.cc.z = ((res & 0xff) == 0);
    state.cc.s = (res & 0x80 != 0);
    const res_u8: u8 = @truncate(res & 0xff);
    // state.cc.p = parity(@as(u8, (res & 0xff)), 8);
    state.cc.p = parity(res_u8, 8);
}

pub fn unimplementedInstruction(state: *State8080) noreturn {
    std.debug.print("Error: Unimplemented instruction\n", .{});
    state.pc -= 1;
    // Disassemble8080Op(state.memory, state.pc);
    std.debug.print("\n", .{});
    unreachable;
}

pub fn writeMem(state: *State8080, address: u16, value: u8) void {
    if (address < 0x2000 or address >= 0x4000) {
        return;
    }
    state.memory[address] = value;
}

pub fn readFromHL(state: *State8080) u8 {
    // const offset = u16((state.h << 8) | state.l);
    const offset: u8 = @truncate((@as(u16, state.h) << 8) | state.l);
    return state.memory[offset];
}

pub fn writeToHL(state: *State8080, value: u8) void {
    // const offset = u16((state.h << 8) | state.l);
    // const offset: u8 = @truncate(@as(u16, (state.h << 8) | state.l));
    const offset: u8 = @truncate((@as(u16, state.h) << 8) | state.l);
    writeMem(state, offset, value);
}

pub fn push(state: *State8080, high: u8, low: u8) void {
    writeMem(state, state.sp - 1, high);
    writeMem(state, state.sp - 2, low);
    state.sp -= 2;
}

pub fn pop(state: *State8080, high: *u8, low: *u8) void {
    low.* = state.memory[state.sp];
    high.* = state.memory[state.sp + 1];
    state.sp += 2;
}

pub fn flagsZSP(state: *State8080, value: u8) void {
    state.cc.z = (value == 0);
    state.cc.s = (value & 0x80 != 0);
    state.cc.p = parity(value, 8);
}

pub fn emulate8080Op(state: *State8080) u8 {
    const opcode: u8 = state.memory[state.pc];

    // _ = state.memory;
    // _ = state.pc;

    state.pc += 1;

    switch (opcode) {
        // NOP
        0x00 => {},
        // LXI B,D16
        // - Load Register Pair Immediate
        0x01 => {
            state.c = state.memory[state.pc];
            state.b = state.memory[state.pc + 1];
            state.pc +%= 2;
        },
        // STAX B
        // - Store Accumullator Indirect
        // - The content of the accumulator (Register A) is moved to the memory location
        //      specified by the contents of the B and C registers.
        0x02 => {
            const offset = (@as(u16, state.b) << 8) | state.c;
            writeMem(state, offset, state.a);
        },
        // INX B
        // - Increment Register Pair
        0x03 => {
            state.c +%= 1;
            if (state.c == 0)
                state.b +%= 1;
        },
        // INR B
        0x04 => {
            state.b +%= 1;
            flagsZSP(state, state.b);
        },
        // DCR B
        0x05 => {
            state.b -%= 1;
            flagsZSP(state, state.b);
        },
        // MVI B,byte
        0x06 => {
            state.b = state.memory[state.pc];
            state.pc +%= 1;
        },
        // RLC
        0x07 => {
            const x: u8 = state.a;
            state.a = ((x & 0x80) >> 7) | (x << 1);
            state.cc.cy = (0x80 == (x & 0x80));
        },
        0x08 => unimplementedInstruction(state),
        // DAD B
        0x09 => {
            const hl: u32 = (@as(u32, state.*.h) << 8) | state.*.l;
            const bc: u32 = (@as(u32, state.*.b) << 8) | state.*.c;
            const res: u32 = hl +% bc;
            state.h = @truncate(res >> 8);
            state.l = @truncate(res & 0xff);
            state.cc.cy = ((res & 0xffff0000) != 0);
        },
        // LDAX   B
        0x0a => {
            const offset = (@as(u16, state.b) << 8) | state.c;
            state.a = state.memory[offset];
        },
        // DCX B
        // - Decrement Register B
        0x0b => {
            state.c -%= 1;
            if (state.c == 0xff)
                state.b -%= 1;
        },
        // INR C
        0x0c => {
            state.c +%= 1;
            flagsZSP(state, state.c);
        },
        // DCR C
        0x0d => {
            state.c -%= 1;
            flagsZSP(state, state.c);
        },
        // MVI C,byte
        0x0e => {
            state.c = state.memory[state.pc];
            state.pc +%= 1;
        },
        // RRC
        0x0f => {
            const x: u8 = state.a;
            state.a = ((x & 1) << 7) | (x >> 1);
            state.cc.cy = (1 == (x & 1));
        },
        0x10 => unimplementedInstruction(state),
        // LXI	D,word
        0x11 => {
            state.e = state.memory[state.pc];
            state.d = state.memory[state.pc + 1];
            state.pc +%= 2;
        },
        // STAX D
        0x12 => {
            const offset = (@as(u16, state.d) << 8) | state.e;
            writeMem(state, offset, state.a);
        },
        // INX    D
        0x13 => {
            state.e +%= 1;
            if (state.e == 0)
                state.d +%= 1;
        },
        // INR D
        0x14 => {
            state.d +%= 1;
            flagsZSP(state, state.d);
        },
        // DCR    D
        0x15 => {
            state.d -%= 1;
            flagsZSP(state, state.d);
        },
        // MVI D,byte
        0x16 => {
            state.d = state.memory[state.pc];
            state.pc +%= 1;
        },
        // RAL
        0x17 => {
            const x: u8 = state.a;
            const val: u8 = if (state.cc.cy) 1 else 0;
            state.a = val | (x << 1);
            state.cc.cy = (0x80 == (x & 0x80));
        },
        0x18 => unimplementedInstruction(state),
        // DAD    D
        0x19 => {
            const hl: u32 = (@as(u32, state.*.h) << 8) | state.*.l;
            const de: u32 = (@as(u32, state.*.d) << 8) | state.*.e;
            const res: u32 = hl +% de;
            state.h = @truncate((res & 0xff00) >> 8);
            state.l = @truncate(res & 0xff);
            state.cc.cy = ((res & 0xffff0000) != 0);
        },
        // LDAX	D
        0x1a => {
            const offset = (@as(u16, state.d) << 8) | state.e;
            state.a = state.memory[offset];
        },
        // DCX D
        // - Decrement Register D
        0x1b => {
            state.e -%= 1;
            if (state.e == 0xff)
                state.d -%= 1;
        },
        // INR E
        // - Increment Register E
        0x1c => {
            state.e +%= 1;
            flagsZSP(state, state.e);
        },
        // DCR E
        // - Decrement Register E
        0x1d => {
            state.e -%= 1;
            flagsZSP(state, state.e);
        },
        0x1e => { //MVI E,byte
            state.e = state.memory[state.pc];
            state.pc +%= 1;
        },
        // RAR
        0x1f => {
            const x: u8 = state.a;
            const val: u8 = if (state.cc.cy) 0x80 else 0;
            state.a = val | (x >> 1);
            // state.a = (state.cc.cy << 7) | (x >> 1);
            state.cc.cy = (1 == (x & 1));
        },
        0x20 => unimplementedInstruction(state),
        // LXI	H,word
        0x21 => {
            state.l = state.memory[state.pc];
            state.h = state.memory[state.pc + 1];
            state.pc += 2;
        },
        // SHLD
        0x22 => {
            const offset: u16 = state.memory[state.pc] | (@as(u16, state.memory[state.pc + 1]) << 8);
            writeMem(state, offset, state.l);
            writeMem(state, offset + 1, state.h);
            state.pc += 2;
        },
        //INX    H
        0x23 => {
            const l_struct = @addWithOverflow(state.l, 1);
            const l_fields = @typeInfo(@TypeOf(l_struct)).Struct.fields;
            const l_res: u8 = @field(l_struct, l_fields[0].name);
            state.l = l_res;
            if (state.l == 0) {
                const h_struct = @addWithOverflow(state.h, 1);
                const h_fields = @typeInfo(@TypeOf(h_struct)).Struct.fields;
                const h_res: u8 = @field(h_struct, h_fields[0].name);
                state.h = h_res;
            }
        },
        //INR	H
        0x24 => {
            const h_struct = @addWithOverflow(state.h, 1);
            const h_fields = @typeInfo(@TypeOf(h_struct)).Struct.fields;
            const h_res: u8 = @field(h_struct, h_fields[0].name);
            state.h = h_res;
            flagsZSP(state, state.h);
        },
        //DCR    H
        0x25 => {
            const h_struct = @subWithOverflow(state.h, 1);
            const h_fields = @typeInfo(@TypeOf(h_struct)).Struct.fields;
            const h_res: u8 = @field(h_struct, h_fields[0].name);
            state.h = h_res;
            flagsZSP(state, state.h);
        },
        //MVI H,byte
        0x26 => {
            state.h = state.memory[state.pc];
            state.pc += 1;
        },
        0x27 => {
            if ((state.a & 0xf) > 9) {
                const a_struct = @addWithOverflow(state.a, 1);
                const a_fields = @typeInfo(@TypeOf(a_struct)).Struct.fields;
                const a_res: u8 = @field(a_struct, a_fields[0].name);
                state.a = a_res;
            }
            if ((state.a & 0xf0) > 0x90) {
                const res: u16 = (@as(u16, state.a) + 0x60);
                state.a = @truncate(res);
                arithFlagsA(state, res);
            }
        },
        0x28 => unimplementedInstruction(state),
        //DAD    H
        0x29 => {
            const hl: u32 = (@as(u32, state.h) << 8) | state.l;

            const res: u32 = hl +% hl;

            state.h = @truncate(res >> 8);
            state.l = @truncate(res & 0xff);
            state.cc.cy = ((res & 0xffff0000) != 0);
        },
        //LHLD adr
        0x2a => {
            const offset: u16 = state.memory[state.pc] | (@as(u16, state.memory[state.pc + 1]) << 8);
            state.l = state.memory[offset];
            state.h = state.memory[offset + 1];
            state.pc += 2;
        },
        //DCX H
        0x2b => {
            state.l -%= 1;
            if (state.l == 0xff)
                state.h -%= 1;
        },
        //INR L
        0x2c => {
            state.l +%= 1;
            flagsZSP(state, state.l);
        },
        // DCR L
        0x2d => {
            state.l -%= 1;
            flagsZSP(state, state.l);
        },
        // MVI L,byte
        0x2e => {
            state.l = state.memory[state.pc];
            state.pc += 1;
        },
        // CMA
        0x2f => {
            state.a = ~state.a;
        },
        0x30 => {
            //UnimplementedInstruction
        },
        //LXI SP,word
        0x31 => {
            const sp: u16 = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            state.sp = sp;
            state.pc += 2;
        },
        //STA (word)
        0x32 => {
            const offset: u16 = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            writeMem(state, offset, state.a);
            state.pc += 2;
        },
        //INX SP
        0x33 => {
            // const addr: u16 = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            // state.memory[addr] = state.a;
            // state.pc += 2;
            state.pc += 1;
        },
        //INR M
        0x34 => {
            const res: u8 = readFromHL(state) + 1;
            flagsZSP(state, res);
            writeToHL(state, res);
        },
        //DCR M
        0x35 => {
            const res: u8 = readFromHL(state) - 1;
            flagsZSP(state, res);
            writeToHL(state, res);
        },
        //MVI M,byte
        0x36 => {
            writeToHL(state, state.memory[state.pc]);
            state.pc += 1;
        },
        0x37 => {
            state.cc.cy = true;
        },
        0x38 => { //UnimplementedInstruction
            // implement 0x38 instruction
        },
        //DAD SP
        0x39 => {
            const hl: u16 = (@as(u16, state.h) << 8) | state.l;
            const res: u32 = hl + state.sp;
            state.h = @truncate((res & 0xff00) >> 8);
            state.l = @truncate(res & 0xff);
            state.cc.cy = ((res & 0xffff0000) > 0);
        },
        //LDA (word)
        0x3a => {
            const offset: u16 = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            state.a = state.memory[offset];
            state.pc += 2;
        },
        //DCX SP
        0x3b => {
            state.sp -%= 1;
        },
        //INR A
        0x3c => {
            state.a +%= 1;
            flagsZSP(state, state.a);
        },
        //DCR A
        0x3d => {
            state.a -%= 1;
            flagsZSP(state, state.a);
        },
        //MVI A,byte
        0x3e => {
            state.a = state.memory[state.pc];
            state.pc +%= 1;
        },
        0x3f => {
            state.cc.cy = false;
        },
        0x40 => {
            state.b = state.b;
        },
        0x41 => {
            state.b = state.c;
        },
        0x42 => {
            state.b = state.d;
        },
        0x43 => {
            state.b = state.e;
        },
        0x44 => {
            state.b = state.h;
        },
        0x45 => {
            state.b = state.l;
        },
        0x46 => {
            state.b = readFromHL(state);
        },
        0x47 => {
            state.b = state.a;
        },
        0x48 => {
            state.c = state.b;
        },
        0x49 => {
            state.c = state.c;
        },
        0x4a => {
            state.c = state.d;
        },
        0x4b => {
            state.c = state.e;
        },
        0x4c => {
            state.c = state.h;
        },
        0x4d => {
            state.c = state.l;
        },
        0x4e => {
            state.c = readFromHL(state);
        },
        0x4f => {
            state.c = state.a;
        },
        0x50 => {
            state.d = state.b;
        },
        0x51 => {
            state.d = state.c;
        },
        0x52 => {
            state.d = state.d;
        },
        0x53 => {
            state.d = state.e;
        },
        0x54 => {
            state.d = state.h;
        },
        0x55 => {
            state.d = state.l;
        },
        0x56 => {
            state.d = readFromHL(state);
        },
        0x57 => {
            state.d = state.a;
        },
        0x58 => {
            state.e = state.b;
        },
        0x59 => {
            state.e = state.c;
        },
        0x5a => {
            state.e = state.d;
        },
        0x5b => {
            state.e = state.e;
        },
        0x5c => {
            state.e = state.h;
        },
        0x5d => {
            state.e = state.l;
        },
        0x5e => {
            state.e = readFromHL(state);
        },
        0x5f => {
            state.e = state.a;
        },
        0x60 => {
            state.h = state.b;
        },
        0x61 => {
            state.h = state.c;
        },
        0x62 => {
            state.h = state.d;
        },
        0x63 => {
            state.h = state.e;
        },
        0x64 => {
            state.h = state.h;
        },
        0x65 => {
            state.h = state.l;
        },
        0x66 => {
            state.h = readFromHL(state);
        },
        0x67 => {
            state.h = state.a;
        },
        0x68 => {
            state.l = state.b;
        },
        0x69 => {
            state.l = state.c;
        },
        0x6a => {
            state.l = state.d;
        },
        0x6b => {
            state.l = state.e;
        },
        0x6c => {
            state.l = state.h;
        },
        0x6d => {
            state.l = state.l;
        },
        0x6e => {
            state.l = readFromHL(state);
        },
        0x6f => {
            state.l = state.a;
        },
        0x70 => {
            writeToHL(state, state.b);
        },
        0x71 => {
            writeToHL(state, state.c);
        },
        0x72 => {
            writeToHL(state, state.d);
        },
        0x73 => {
            writeToHL(state, state.e);
        },
        0x74 => {
            writeToHL(state, state.h);
        },
        0x75 => {
            writeToHL(state, state.l);
        },
        0x76 => {
            std.debug.print("HALT\n", .{});
            // HLT
        },
        0x77 => {
            writeToHL(state, state.a);
        },
        0x78 => {
            state.a = state.b;
        },
        0x79 => {
            state.a = state.c;
        },
        0x7a => {
            state.a = state.d;
        },
        0x7b => {
            state.a = state.e;
        },
        0x7c => {
            state.a = state.h;
        },
        0x7d => {
            state.a = state.l;
        },
        0x7e => {
            state.a = readFromHL(state);
        },
        0x7f => {
            // UnimplementedInstruction
            unimplementedInstruction(state);
        },
        0x80 => {
            const res: u16 = @as(u16, state.a) + @as(u16, state.b);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        0x81 => {
            const res: u16 = @as(u16, state.a) + @as(u16, state.c);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        0x82 => {
            const res: u16 = @as(u16, state.a) + @as(u16, state.d);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        0x83 => {
            const res: u16 = @as(u16, state.a) + @as(u16, state.e);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        0x84 => {
            const res: u16 = @as(u16, state.a) + @as(u16, state.h);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        0x85 => {
            const res: u16 = @as(u16, state.a) + @as(u16, state.l);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        0x86 => {
            const res: u16 = @as(u16, state.a) + @as(u16, readFromHL(state));
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        0x87 => {
            const res: u16 = @as(u16, state.a) + @as(u16, state.a);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // ADC B
        0x88 => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) + @as(u16, state.b) + @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // ADC C
        0x89 => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) + @as(u16, state.c) + @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // ADC D
        0x8a => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) + @as(u16, state.d) + @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // ADC E
        0x8b => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) + @as(u16, state.e) + @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // ADC H
        0x8c => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) + @as(u16, state.h) + @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // ADC L
        0x8d => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) + @as(u16, state.l) + @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // ADC M
        0x8e => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) + @as(u16, readFromHL(state)) + @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // ADC A
        0x8f => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) + @as(u16, state.a) + @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SUB B
        0x90 => {
            const res: u16 = @as(u16, state.a) - @as(u16, state.b);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SUB C
        0x91 => {
            const res: u16 = @as(u16, state.a) - @as(u16, state.c);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SUB D
        0x92 => {
            const res: u16 = @as(u16, state.a) - @as(u16, state.d);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SUB E
        0x93 => {
            const res: u16 = @as(u16, state.a) - @as(u16, state.e);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SUB H
        0x94 => {
            const res: u16 = @as(u16, state.a) - @as(u16, state.h);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SUB L
        0x95 => {
            const res: u16 = @as(u16, state.a) - @as(u16, state.l);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SUB M
        0x96 => {
            const res: u16 = @as(u16, state.a) - @as(u16, readFromHL(state));
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SUB A
        0x97 => {
            const res: u16 = @as(u16, state.a) - @as(u16, state.a);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SBB B
        0x98 => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) - @as(u16, state.b) - @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SBB C
        0x99 => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) - @as(u16, state.c) - @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SBB D
        0x9a => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) - @as(u16, state.d) - @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SBB E
        0x9b => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) - @as(u16, state.e) - @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SBB H
        0x9c => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) - @as(u16, state.h) - @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SBB L
        0x9d => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) - @as(u16, state.l) - @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SBB M
        0x9e => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) - @as(u16, readFromHL(state)) - @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // SBB A
        0x9f => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const res: u16 = @as(u16, state.a) - @as(u16, state.a) - @as(u16, cy_int);
            arithFlagsA(state, res);
            state.a = @truncate(res & 0xff);
        },
        // ANA B
        0xa0 => {
            state.a = state.a & state.b;
            logicFlagsA(state);
        },
        // ANA C
        0xa1 => {
            state.a = state.a & state.c;
            logicFlagsA(state);
        },
        // ANA D
        0xa2 => {
            state.a = state.a & state.d;
            logicFlagsA(state);
        },
        // ANA E
        0xa3 => {
            state.a = state.a & state.e;
            logicFlagsA(state);
        },
        // ANA H
        0xa4 => {
            state.a = state.a & state.h;
            logicFlagsA(state);
        },
        // ANA L
        0xa5 => {
            state.a = state.a & state.l;
            logicFlagsA(state);
        },
        // ANA M
        0xa6 => {
            state.a = state.a & readFromHL(state);
            logicFlagsA(state);
        },
        // ANA A
        0xa7 => {
            state.a = state.a & state.a;
            logicFlagsA(state);
        },
        // XRA B
        0xa8 => {
            state.a = state.a ^ state.b;
            logicFlagsA(state);
        },
        // XRA C
        0xa9 => {
            state.a = state.a ^ state.c;
            logicFlagsA(state);
        },
        // XRA D
        0xaa => {
            state.a = state.a ^ state.d;
            logicFlagsA(state);
        },
        // XRA E
        0xab => {
            state.a = state.a ^ state.e;
            logicFlagsA(state);
        },
        // XRA H
        0xac => {
            state.a = state.a ^ state.h;
            logicFlagsA(state);
        },
        // XRA L
        0xad => {
            state.a = state.a ^ state.l;
            logicFlagsA(state);
        },
        // XRA M
        0xae => {
            state.a = state.a ^ readFromHL(state);
            logicFlagsA(state);
        },
        // XRA A
        0xaf => {
            state.a = state.a ^ state.a;
            logicFlagsA(state);
        },
        // ORA B
        0xb0 => {
            state.a = state.a | state.b;
            logicFlagsA(state);
        },
        // ORA C
        0xb1 => {
            state.a = state.a | state.c;
            logicFlagsA(state);
        },
        // ORA D
        0xb2 => {
            state.a = state.a | state.d;
            logicFlagsA(state);
        },
        // ORA E
        0xb3 => {
            state.a = state.a | state.e;
            logicFlagsA(state);
        },
        // ORA H
        0xb4 => {
            state.a = state.a | state.h;
            logicFlagsA(state);
        },
        // ORA L
        0xb5 => {
            state.a = state.a | state.l;
            logicFlagsA(state);
        },
        // ORA M
        0xb6 => {
            state.a = state.a | readFromHL(state);
            logicFlagsA(state);
        },
        // ORA A
        0xb7 => {
            state.a = state.a | state.a;
            logicFlagsA(state);
        },
        // CMP B
        0xb8 => {
            const res: u16 = @as(u16, state.a) - @as(u16, state.b);
            arithFlagsA(state, res);
        },
        // CMP C
        0xb9 => {
            const res: u16 = @as(u16, state.a) - @as(u16, state.c);
            arithFlagsA(state, res);
        },
        // CMP D
        0xba => {
            const res: u16 = @as(u16, state.a) - @as(u16, state.d);
            arithFlagsA(state, res);
        },
        // CMP E
        0xbb => {
            const res: u16 = @as(u16, state.a) - @as(u16, state.e);
            arithFlagsA(state, res);
        },
        // CMP H
        0xbc => {
            const res: u16 = @as(u16, state.a) - @as(u16, state.h);
            arithFlagsA(state, res);
        },
        // CMP L
        0xbd => {
            const res: u16 = @as(u16, state.a) - @as(u16, state.l);
            arithFlagsA(state, res);
        },
        // CMP M
        0xbe => {
            const res: u16 = @as(u16, state.a) - @as(u16, readFromHL(state));
            arithFlagsA(state, res);
        },
        // CMP A
        0xbf => {
            const res: u16 = @as(u16, state.a) - @as(u16, state.a);
            arithFlagsA(state, res);
        },
        // RNZ
        0xc0 => {
            if (!state.cc.z) {
                state.pc = state.memory[state.sp] | (@as(u16, state.memory[state.sp + 1]) << 8);
                state.sp += 2;
            }
        },
        // POP B
        0xc1 => {
            pop(state, &state.b, &state.c);
        },
        // JNZ adr
        0xc2 => {
            if (!state.cc.z) {
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        // JMP adr
        0xc3 => {
            state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
        },
        // CNZ adr
        0xc4 => {
            if (state.cc.z) {
                const ret: u16 = state.pc + 2;
                const val_1: u8 = @truncate((ret >> 8) & 0xff);
                const val_2: u8 = @truncate(ret & 0xff);
                writeMem(state, state.sp - 1, val_1);
                writeMem(state, state.sp - 2, val_2);
                state.sp -= 2;
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        // PUSH B
        0xc5 => {
            push(state, state.b, state.c);
        },
        // ADI byte
        0xc6 => {
            const x: u16 = @as(u16, state.a) + @as(u16, state.memory[state.pc + 1]);
            flagsZSP(state, @truncate(x));
            state.cc.cy = (x > 0xff);
            state.a = @truncate(x);
            state.pc += 1;
        },
        // RST 0
        0xc7 => {
            const ret: u16 = state.pc + 2;
            const val_1: u8 = @truncate((ret >> 8) & 0xff);
            const val_2: u8 = @truncate(ret & 0xff);
            writeMem(state, state.sp - 1, val_1);
            writeMem(state, state.sp - 2, val_2);
            state.sp -= 2;
            state.pc = 0x0000;
        },
        // RZ
        0xc8 => {
            if (state.cc.z) {
                state.pc = state.memory[state.sp] | (@as(u16, state.memory[state.sp + 1]) << 8);
                state.sp += 2;
            }
        },
        // RET
        0xc9 => {
            state.pc = state.memory[state.sp] | (@as(u16, state.memory[state.sp + 1]) << 8);
            state.sp += 2;
        },
        // JZ adr
        0xca => {
            if (state.cc.z) {
                state.pc = state.memory[state.pc] | (@as(u16, state.memory[state.pc + 1]) << 8);
            } else {
                state.pc += 2;
            }
        },
        0xcb => {
            // UnimplementedInstruction
            unimplementedInstruction(state);
        },
        // CZ adr
        0xcc => {
            if (state.cc.z) {
                const ret: u16 = state.pc + 2;
                const val_1: u8 = @truncate((ret >> 8) & 0xff);
                const val_2: u8 = @truncate(ret & 0xff);
                writeMem(state, state.sp - 1, val_1);
                writeMem(state, state.sp - 2, val_2);
                state.sp -= 2;
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        // CALL adr
        0xcd => {
            const ret: u16 = state.pc + 2;
            const val_1: u8 = @truncate((ret >> 8) & 0xff);
            const val_2: u8 = @truncate(ret & 0xff);
            writeMem(state, state.sp - 1, val_1);
            writeMem(state, state.sp - 2, val_2);
            state.sp -= 2;
            state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
        },
        // ACI byte
        0xce => {
            const cy_int: u8 = if (state.cc.cy) 1 else 0;
            const x: u16 = state.a + state.memory[state.pc + 1] + cy_int;
            flagsZSP(state, @truncate(x));
            state.cc.cy = (x > 0xff);
            state.a = @truncate(x);
            state.pc += 1;
        },
        // RST 1
        0xcf => {
            const ret: u16 = state.pc + 2;
            const val_1: u8 = @truncate((ret >> 8) & 0xff);
            const val_2: u8 = @truncate(ret & 0xff);
            writeMem(state, state.sp - 1, val_1);
            writeMem(state, state.sp - 2, val_2);
            state.sp -= 2;
            state.pc = 0x0008;
        },
        // RNC
        0xd0 => {
            if (!state.cc.cy) {
                state.pc = state.memory[state.sp] | (@as(u16, state.memory[state.sp + 1]) << 8);
                state.sp += 2;
            }
        },
        // POP D
        0xd1 => {
            pop(state, &state.d, &state.e);
        },
        // JNC
        0xd2 => {
            if (!state.cc.cy) {
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        // OUT d8
        0xd3 => {
            std.debug.print("OUT\n", .{});
            state.pc += 1;
        },
        // CNC adr
        0xd4 => {
            if (!state.cc.cy) {
                const ret: u16 = state.pc + 2;
                const val_1: u8 = @truncate((ret >> 8) & 0xff);
                const val_2: u8 = @truncate(ret & 0xff);
                writeMem(state, state.sp - 1, val_1);
                writeMem(state, state.sp - 2, val_2);
                state.sp -= 2;
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        // PUSH D
        0xd5 => {
            push(state, state.d, state.e);
        },
        // SUI byte
        0xd6 => {
            const x: u8 = state.a - state.memory[state.pc];
            flagsZSP(state, x & 0xff);
            state.cc.cy = (state.a < state.memory[state.pc]);
            state.a = x;
            state.pc += 1;
        },
        // RST 2
        0xd7 => {
            const ret: u16 = state.pc + 2;
            const val_1: u8 = @truncate((ret >> 8) & 0xff);
            const val_2: u8 = @truncate(ret & 0xff);
            writeMem(state, state.sp - 1, val_1);
            writeMem(state, state.sp - 2, val_2);
            state.sp -= 2;
            state.pc = 0x10;
        },
        // RC
        0xd8 => {
            if (state.cc.cy) {
                state.pc = state.memory[state.sp] | (@as(u16, state.memory[state.sp + 1]) << 8);
                state.sp += 2;
            }
        },
        0xd9 => {
            unimplementedInstruction(state);
            // std.debug.print("UnimplementedInstruction\n");
            // UnimplementedInstruction
        },
        // JC adr
        0xda => {
            if (state.cc.cy) {
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        // IN d8
        0xdb => {
            std.debug.print("IN\n", .{});
            state.pc += 1;
        },
        // CC adr
        0xdc => {
            if (state.cc.cy) {
                const ret: u16 = state.pc + 2;
                const val_1: u8 = @truncate((ret >> 8) & 0xff);
                const val_2: u8 = @truncate(ret & 0xff);
                writeMem(state, state.sp - 1, val_1);
                writeMem(state, state.sp - 2, val_2);
                state.sp -= 2;
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        0xdd => {
            // UnimplementedInstruction
            unimplementedInstruction(state);
        },
        // SBI byte
        0xde => {
            const int_cy: u8 = if (state.cc.cy) 1 else 0;
            const x: u16 = state.a - state.memory[state.pc + 1] - int_cy;
            flagsZSP(state, @truncate(x));
            state.cc.cy = (x > 0xff);
            state.a = @truncate(x & 0xff);
            state.pc += 1;
        },
        // RST 3
        0xdf => {
            const ret: u16 = state.pc + 2;
            const val_1: u8 = @truncate((ret >> 8) & 0xff);
            const val_2: u8 = @truncate(ret & 0xff);
            writeMem(state, state.sp - 1, val_1);
            writeMem(state, state.sp - 2, val_2);
            state.sp -= 2;
            state.pc = 0x18;
        },
        // RPO
        0xe0 => {
            if (!state.cc.p) {
                state.pc = state.memory[state.sp] | (@as(u16, state.memory[state.sp + 1]) << 8);
                state.sp += 2;
            }
        },
        // POP H
        0xe1 => {
            pop(state, &state.h, &state.l);
        },
        // JPO adr
        0xe2 => {
            if (!state.cc.p) {
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        // XTHL
        0xe3 => {
            const h: u8 = state.h;
            const l: u8 = state.l;
            state.l = state.memory[state.sp];
            state.h = state.memory[state.sp + 1];
            writeMem(state, state.sp, l);
            writeMem(state, state.sp + 1, h);
        },
        // CPO adr
        0xe4 => {
            if (!state.cc.p) {
                const ret: u16 = state.pc + 2;
                const val_1: u8 = @truncate((ret >> 8) & 0xff);
                const val_2: u8 = @truncate(ret & 0xff);
                writeMem(state, state.sp - 1, val_1);
                writeMem(state, state.sp - 2, val_2);
                state.sp -= 2;
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        // PUSH H
        0xe5 => {
            push(state, state.h, state.l);
        },
        // ANI byte
        0xe6 => {
            state.a = state.a & state.memory[state.pc];
            logicFlagsA(state);
            state.pc += 1;
        },
        0xe7 => {
            const ret: u16 = state.pc + 2;
            const val_1: u8 = @truncate((ret >> 8) & 0xff);
            const val_2: u8 = @truncate(ret & 0xff);
            writeMem(state, state.sp - 1, val_1);
            writeMem(state, state.sp - 2, val_2);
            state.sp -= 2;
            state.pc = 0x20;
        },
        // RPE
        0xe8 => {
            if (state.cc.p) {
                state.pc = state.memory[state.sp] | (@as(u16, state.memory[state.sp + 1]) << 8);
                state.sp += 2;
            }
        },
        // PCHL
        0xe9 => {
            state.pc = (@as(u16, state.h) << 8) | state.l;
        },
        // JPE
        0xea => {
            if (state.cc.p) {
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        // XCHG
        0xeb => {
            const save1 = state.d;
            const save2 = state.e;
            state.d = state.h;
            state.e = state.l;
            state.h = save1;
            state.l = save2;
        },
        // CPE adr
        0xec => {
            if (state.cc.p) {
                const ret: u16 = state.pc + 2;
                const val_1: u8 = @truncate((ret >> 8) & 0xff);
                const val_2: u8 = @truncate(ret & 0xff);
                writeMem(state, state.sp - 1, val_1);
                writeMem(state, state.sp - 2, val_2);
                state.sp -= 2;
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        0xed => unimplementedInstruction(state),
        // XRI data
        0xee => {
            // const x = state.a ^ opcode[1];
            const x = state.a ^ state.memory[state.pc];
            flagsZSP(state, x);
            state.cc.cy = false; // NOTE: data book (and emulator101) says clear cy
            state.a = x;
            state.pc += 1;
        },
        // RST 5
        0xef => {
            const ret: u16 = state.pc + 2;
            const val_1: u8 = @truncate((ret >> 8) & 0xff);
            const val_2: u8 = @truncate(ret & 0xff);
            writeMem(state, state.sp - 1, val_1);
            writeMem(state, state.sp - 2, val_2);
            state.sp -= 2;
            state.pc = 0x28;
        },
        // RP
        0xf0 => {
            if (!state.cc.s) {
                state.pc = state.memory[state.sp] | (@as(u16, state.memory[state.sp + 1]) << 8);
                state.sp += 2;
            }
        },
        // POP PSW
        // - Pop processor status word
        // - The content of the memory location whose address is specified by the content of the
        //      register SP is used to restore the condition flags
        //
        // FIX: Almost certainly wrong
        0xf1 => {
            const ptr_cast: *u8 = @ptrCast(&state.cc);
            std.debug.print("POP PSW\n", .{});
            // std.debug.print("state.sp: {}\n", .{state.sp});
            std.debug.print("ptr_cast: {any}\n", .{ptr_cast});
            // std.debug.print("@bitCast(state.cc): {any}\n", .{@bitCast(state.cc)});
            pop(state, &state.a, @ptrCast(&state.cc));
            // pop(state, &state.a, @bitCast(state.cc));
        },
        0xf2 => {
            if (!state.cc.s) {
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        0xf3 => {
            state.int_enabled = false;
        },
        // CP
        0xf4 => {
            if (!state.cc.s) {
                const ret: u16 = state.pc + 2;
                const val_1: u8 = @truncate((ret >> 8) & 0xff);
                const val_2: u8 = @truncate(ret & 0xff);
                writeMem(state, state.sp - 1, val_1);
                writeMem(state, state.sp - 2, val_2);
                state.sp -= 2;
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        // PUSH PSW
        0xf5 => {
            // const bit_cast: u8 = @bitCast(state.cc);
            push(state, state.a, state.cc.pack());
            // push(state, state.a, @intCast(state.cc));
        },
        // ORI byte
        0xf6 => {
            const x: u8 = state.a | state.memory[state.pc + 1];
            flagsZSP(state, x);
            state.cc.cy = false;
            state.a = x;
            state.pc += 1;
        },
        0xf7 => {
            const ret: u16 = state.pc + 2;
            const val_1: u8 = @truncate((ret >> 8) & 0xff);
            const val_2: u8 = @truncate(ret & 0xff);
            writeMem(state, state.sp - 1, val_1);
            writeMem(state, state.sp - 2, val_2);
            state.sp -= 2;
            state.pc = 0x30;
        },
        0xf8 => {
            if (state.cc.s) {
                state.pc = state.memory[state.sp] | (@as(u16, state.memory[state.sp + 1]) << 8);
                state.sp += 2;
            }
        },
        0xf9 => {
            state.sp = state.l | (@as(u16, state.h) << 8);
        },
        0xfa => {
            if (state.cc.s) {
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        0xfb => {
            state.int_enabled = true;
        },
        0xfc => {
            if (state.cc.s) {
                const ret: u16 = state.pc + 2;
                const val_1: u8 = @truncate((ret >> 8) & 0xff);
                const val_2: u8 = @truncate(ret & 0xff);
                writeMem(state, state.sp - 1, val_1);
                writeMem(state, state.sp - 2, val_2);
                state.sp -= 2;
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }
        },
        0xfd => {
            unimplementedInstruction(state);
            // UnimplementedInstruction
        },
        // CPI byte
        0xfe => {
            const x: u8 = state.a -% state.memory[state.pc + 1];
            flagsZSP(state, x);
            state.cc.cy = state.a < state.memory[state.pc + 1];
            state.pc += 1;
        },
        0xff => {
            const ret: u16 = state.pc + 2;
            const val_1: u8 = @truncate((ret >> 8) & 0xff);
            const val_2: u8 = @truncate(ret & 0xff);
            writeMem(state, state.sp - 1, val_1);
            writeMem(state, state.sp - 2, val_2);
            state.sp -= 2;
            state.pc = 0x38;
        },
        // else => unreachable,
        // else => {
        // UnimplementedInstruction
        // unimplementedInstruction(state);
        // },
    }

    return cycles8080[opcode];
}

pub fn generateInterrupt(state: *State8080, interruptNum: i32) void {
    push(state, @truncate((state.pc & 0xFF00) >> 8), @truncate(state.pc & 0xff));

    state.pc = @intCast(8 * interruptNum);

    state.intEnable = 0;
}
