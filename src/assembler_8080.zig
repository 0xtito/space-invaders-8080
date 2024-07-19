const std = @import("std");
const print = std.debug.print;

const m = @import("main.zig");

const State8080 = m.State8080;
const InstructionErrors = error{ Unimplemented, IDK };

const FlagErrors = error{
    AnswerInvalid,
    Zero,
    Sign,
    Parity,
    Carry,
};

pub fn unimplementedInstruction(state: *State8080) InstructionErrors!void {
    // _ = state;
    state.*.pc -= 1;
    print("Error: Unimplemented instruction \n");
    return InstructionErrors.Unimplemented;
}

fn parity(x: u8, size: usize) bool {
    var p: u8 = 0;

    x = (x & ((1 << size) - 1));

    for (0..size) |_| {
        if (x & 0x1) p += 1;
        x = x >> 1;
    }
    return @intCast(0 == (p & 0x1));
}

fn logicFlagsA(state: *State8080, ans: *u8) FlagErrors!void {
    // INFO: Zero flag: if the result is 0:
    //
    //  - set the flag to true (1)
    //  - else, clear the flag (false || 0)
    state.*.cc.z = ((ans & 0xff) == 0);

    // INFO: Sign Flag: if bit 7 is set:
    //
    //  - set the flag to true (1)
    //  - else, clear the flag (false || 0)
    state.*.cc.s = ((ans & 0x80) != 0);

    // INFO: Carry Flag:
    //
    // when the instruction in a carry out or borrow
    // is larget than 0xff (which resulted in a higher order bit)
    state.*.cc.cy = ans > 0xff;

    // INFO: Parity:
    //
    //  - set to true (1) if ans has even parity
    //  - set to false (0) if anse has odd parity
    state.*.cc.p = parity((ans & 0xff), 8);

    // INFO: Auxillary Carry (AC)
    //
    // Not used in Space Invaders so we will just
    // ignore this
    state.*.a = ans & 0xff;
}

pub fn emulate8080P(state: *State8080) !void {
    const opcode: *const u8 = &state.memory;
    print("opcode {x:0>4}", .{opcode});

    switch (*opcode) {
        0x00 => null,
        // LXI B,word
        0x01 => {
            state.*.c = opcode[1];
            state.*.b = opcode[2];
            state.*.pc += 2;
        },
        0x02 => try unimplementedInstruction(state),
        0x03 => try unimplementedInstruction(state),
        0x04 => try unimplementedInstruction(state),
        // DCR B
        0x05 => {
            const res: u8 = state.*.b - 1;
            state.*.cc.z = (res == 0);
            state.*.cc.s = (0x80 == (res & 0x80));
            state.*.cc.p = parity(res, 8);
            state.*.b = res;
        },
        // MVI B,bytes
        0x06 => {
            state.*.b = opcode[1];
            state.pc += 1;
        },
        0x07 => try unimplementedInstruction(state),
        0x08 => try unimplementedInstruction(state),
        // DAD B
        0x09 => {
            const hl: u32 = (state.*.h << 8) | state.*.l;
            const bc: u32 = (state.*.b << 8) | state.*.c;
            const res: u32 = hl + bc;
            state.*.h = (res & 0xff00) >> 8;
            state.*.l = res & 0xff;
            state.*.cc.cy = ((res & 0xffff0000) > 0);
        },
        0x0a => try unimplementedInstruction(state),
        0x0b => try unimplementedInstruction(state),
        0x0c => try unimplementedInstruction(state),
        0x0d => {
            const res: u8 = state.*.c - 1;
            state.*.cc.z = (res == 0);
            state.*.cc.s = (0x80 == (res & 0x80));
            state.*.cc.p = parity(res, 8);
            state.*.c = res;
        },
        0x0e => {
            state.*.c = opcode[1];
            state.*.pc += 1;
        },
        0x0f => {
            const x: u8 = state.*.a;
            state.*.a = ((x & 1) << 7) | (x >> 1);
            state.*.cc.cy = (1 == (x & 1));
        },
        0x10 => try unimplementedInstruction(state),
        0x11 => {
            state.*.e = opcode[1];
            state.*.d = opcode[2];
            state.*.pc += 2;
        },
        0x12 => try unimplementedInstruction(state),
        0x13 => {
            state.*.e += 1;
            if (state.*.e == 0) {
                state.*.d += 1;
            }
        },
        0x14 => try unimplementedInstruction(state),
        0x15 => try unimplementedInstruction(state),
        0x16 => try unimplementedInstruction(state),
        0x17 => try unimplementedInstruction(state),
        0x18 => try unimplementedInstruction(state),
        0x19 => try unimplementedInstruction(state),
        0x1a => try unimplementedInstruction(state),
        0x1b => try unimplementedInstruction(state),
        0x1c => try unimplementedInstruction(state),
        0x1d => try unimplementedInstruction(state),
        0x1e => try unimplementedInstruction(state),
        0x1f => try unimplementedInstruction(state),
        0x20 => try unimplementedInstruction(state),
        0x21 => try unimplementedInstruction(state),
        0x22 => try unimplementedInstruction(state),
        0x23 => try unimplementedInstruction(state),
        0x24 => try unimplementedInstruction(state),
        0x25 => try unimplementedInstruction(state),
        0x26 => try unimplementedInstruction(state),
        0x27 => try unimplementedInstruction(state),
        0x28 => try unimplementedInstruction(state),
        0x29 => try unimplementedInstruction(state),
        0x2a => try unimplementedInstruction(state),
        0x2b => try unimplementedInstruction(state),
        0x2c => try unimplementedInstruction(state),
        0x2d => try unimplementedInstruction(state),
        0x2e => try unimplementedInstruction(state),
        0x2f => try unimplementedInstruction(state),
        0x30 => try unimplementedInstruction(state),
        0x31 => try unimplementedInstruction(state),
        0x32 => try unimplementedInstruction(state),
        0x33 => try unimplementedInstruction(state),
        0x34 => try unimplementedInstruction(state),
        0x35 => try unimplementedInstruction(state),
        0x36 => try unimplementedInstruction(state),
        0x37 => try unimplementedInstruction(state),
        0x38 => try unimplementedInstruction(state),
        0x39 => try unimplementedInstruction(state),
        0x3a => try unimplementedInstruction(state),
        0x3b => try unimplementedInstruction(state),
        0x3c => try unimplementedInstruction(state),
        0x3d => try unimplementedInstruction(state),
        0x3e => try unimplementedInstruction(state),
        0x3f => try unimplementedInstruction(state),
        0x40 => try unimplementedInstruction(state),
        0x41 => try unimplementedInstruction(state),
        0x42 => try unimplementedInstruction(state),
        0x43 => try unimplementedInstruction(state),
        0x44 => try unimplementedInstruction(state),
        0x45 => try unimplementedInstruction(state),
        0x46 => try unimplementedInstruction(state),
        0x47 => try unimplementedInstruction(state),
        0x48 => try unimplementedInstruction(state),
        0x49 => try unimplementedInstruction(state),
        0x4a => try unimplementedInstruction(state),
        0x4b => try unimplementedInstruction(state),
        0x4c => try unimplementedInstruction(state),
        0x4d => try unimplementedInstruction(state),
        0x4e => try unimplementedInstruction(state),
        0x4f => try unimplementedInstruction(state),
        0x50 => try unimplementedInstruction(state),
        0x51 => try unimplementedInstruction(state),
        0x52 => try unimplementedInstruction(state),
        0x53 => try unimplementedInstruction(state),
        0x54 => try unimplementedInstruction(state),
        0x55 => try unimplementedInstruction(state),
        0x56 => try unimplementedInstruction(state),
        0x57 => try unimplementedInstruction(state),
        0x58 => try unimplementedInstruction(state),
        0x59 => try unimplementedInstruction(state),
        0x5a => try unimplementedInstruction(state),
        0x5b => try unimplementedInstruction(state),
        0x5c => try unimplementedInstruction(state),
        0x5d => try unimplementedInstruction(state),
        0x5e => try unimplementedInstruction(state),
        0x5f => try unimplementedInstruction(state),
        0x60 => try unimplementedInstruction(state),
        0x61 => try unimplementedInstruction(state),
        0x62 => try unimplementedInstruction(state),
        0x63 => try unimplementedInstruction(state),
        0x64 => try unimplementedInstruction(state),
        0x65 => try unimplementedInstruction(state),
        0x66 => try unimplementedInstruction(state),
        0x67 => try unimplementedInstruction(state),
        0x68 => try unimplementedInstruction(state),
        0x69 => try unimplementedInstruction(state),
        0x6a => try unimplementedInstruction(state),
        0x6b => try unimplementedInstruction(state),
        0x6c => try unimplementedInstruction(state),
        0x6d => try unimplementedInstruction(state),
        0x6e => try unimplementedInstruction(state),
        0x6f => try unimplementedInstruction(state),
        0x70 => try unimplementedInstruction(state),
        0x71 => try unimplementedInstruction(state),
        0x72 => try unimplementedInstruction(state),
        0x73 => try unimplementedInstruction(state),
        0x74 => try unimplementedInstruction(state),
        0x75 => try unimplementedInstruction(state),
        0x76 => try unimplementedInstruction(state),
        0x77 => try unimplementedInstruction(state),
        0x78 => try unimplementedInstruction(state),
        0x79 => try unimplementedInstruction(state),
        0x7a => try unimplementedInstruction(state),
        0x7b => try unimplementedInstruction(state),
        0x7c => try unimplementedInstruction(state),
        0x7d => try unimplementedInstruction(state),
        0x7e => try unimplementedInstruction(state),
        0x7f => try unimplementedInstruction(state),
        0x80 => try unimplementedInstruction(state),
        0x81 => try unimplementedInstruction(state),
        0x82 => try unimplementedInstruction(state),
        0x83 => try unimplementedInstruction(state),
        0x84 => try unimplementedInstruction(state),
        0x85 => try unimplementedInstruction(state),
        0x86 => try unimplementedInstruction(state),
        0x87 => try unimplementedInstruction(state),
        0x88 => try unimplementedInstruction(state),
        0x89 => try unimplementedInstruction(state),
        0x8a => try unimplementedInstruction(state),
        0x8b => try unimplementedInstruction(state),
        0x8c => try unimplementedInstruction(state),
        0x8d => try unimplementedInstruction(state),
        0x8e => try unimplementedInstruction(state),
        0x8f => try unimplementedInstruction(state),
        0x90 => try unimplementedInstruction(state),
        0x91 => try unimplementedInstruction(state),
        0x92 => try unimplementedInstruction(state),
        0x93 => try unimplementedInstruction(state),
        0x94 => try unimplementedInstruction(state),
        0x95 => try unimplementedInstruction(state),
        0x96 => try unimplementedInstruction(state),
        0x97 => try unimplementedInstruction(state),
        0x98 => try unimplementedInstruction(state),
        0x99 => try unimplementedInstruction(state),
        0x9a => try unimplementedInstruction(state),
        0x9b => try unimplementedInstruction(state),
        0x9c => try unimplementedInstruction(state),
        0x9d => try unimplementedInstruction(state),
        0x9e => try unimplementedInstruction(state),
        0x9f => try unimplementedInstruction(state),
        0xa0 => try unimplementedInstruction(state),
        0xa1 => try unimplementedInstruction(state),
        0xa2 => try unimplementedInstruction(state),
        0xa3 => try unimplementedInstruction(state),
        0xa4 => try unimplementedInstruction(state),
        0xa5 => try unimplementedInstruction(state),
        0xa6 => try unimplementedInstruction(state),
        0xa7 => try unimplementedInstruction(state),
        0xa8 => try unimplementedInstruction(state),
        0xa9 => try unimplementedInstruction(state),
        0xaa => try unimplementedInstruction(state),
        0xab => try unimplementedInstruction(state),
        0xac => try unimplementedInstruction(state),
        0xad => try unimplementedInstruction(state),
        0xae => try unimplementedInstruction(state),
        0xaf => try unimplementedInstruction(state),
        0xb0 => try unimplementedInstruction(state),
        0xb1 => try unimplementedInstruction(state),
        0xb2 => try unimplementedInstruction(state),
        0xb3 => try unimplementedInstruction(state),
        0xb4 => try unimplementedInstruction(state),
        0xb5 => try unimplementedInstruction(state),
        0xb6 => try unimplementedInstruction(state),
        0xb7 => try unimplementedInstruction(state),
        0xb8 => try unimplementedInstruction(state),
        0xb9 => try unimplementedInstruction(state),
        0xba => try unimplementedInstruction(state),
        0xbb => try unimplementedInstruction(state),
        0xbc => try unimplementedInstruction(state),
        0xbd => try unimplementedInstruction(state),
        0xbe => try unimplementedInstruction(state),
        0xbf => try unimplementedInstruction(state),
        0xc0 => try unimplementedInstruction(state),
        0xc1 => try unimplementedInstruction(state),
        0xc2 => try unimplementedInstruction(state),
        0xc3 => try unimplementedInstruction(state),
        0xc4 => try unimplementedInstruction(state),
        0xc5 => try unimplementedInstruction(state),
        0xc6 => try unimplementedInstruction(state),
        0xc7 => try unimplementedInstruction(state),
        0xc8 => try unimplementedInstruction(state),
        0xc9 => try unimplementedInstruction(state),
        0xca => try unimplementedInstruction(state),
        0xcb => try unimplementedInstruction(state),
        0xcc => try unimplementedInstruction(state),
        0xcd => try unimplementedInstruction(state),
        0xce => try unimplementedInstruction(state),
        0xcf => try unimplementedInstruction(state),
        0xd0 => try unimplementedInstruction(state),
        0xd1 => try unimplementedInstruction(state),
        0xd2 => try unimplementedInstruction(state),
        0xd3 => try unimplementedInstruction(state),
        0xd4 => try unimplementedInstruction(state),
        0xd5 => try unimplementedInstruction(state),
        0xd6 => try unimplementedInstruction(state),
        0xd7 => try unimplementedInstruction(state),
        0xd8 => try unimplementedInstruction(state),
        0xd9 => try unimplementedInstruction(state),
        0xda => try unimplementedInstruction(state),
        0xdb => try unimplementedInstruction(state),
        0xdc => try unimplementedInstruction(state),
        0xdd => try unimplementedInstruction(state),
        0xde => try unimplementedInstruction(state),
        0xdf => try unimplementedInstruction(state),
        0xe0 => try unimplementedInstruction(state),
        0xe1 => try unimplementedInstruction(state),
        0xe2 => try unimplementedInstruction(state),
        0xe3 => try unimplementedInstruction(state),
        0xe4 => try unimplementedInstruction(state),
        0xe5 => try unimplementedInstruction(state),
        0xe6 => try unimplementedInstruction(state),
        0xe7 => try unimplementedInstruction(state),
        0xe7 => try unimplementedInstruction(state),
        0xe8 => try unimplementedInstruction(state),
        0xe9 => try unimplementedInstruction(state),
        0xea => try unimplementedInstruction(state),
        0xeb => try unimplementedInstruction(state),
        0xec => try unimplementedInstruction(state),
        0xed => try unimplementedInstruction(state),
        0xee => try unimplementedInstruction(state),
        0xef => try unimplementedInstruction(state),
        0xf0 => try unimplementedInstruction(state),
        0xf1 => try unimplementedInstruction(state),
        0xf2 => try unimplementedInstruction(state),
        0xf3 => try unimplementedInstruction(state),
        0xf4 => try unimplementedInstruction(state),
        0xf5 => try unimplementedInstruction(state),
        0xf6 => try unimplementedInstruction(state),
        0xf7 => try unimplementedInstruction(state),
        0xf8 => try unimplementedInstruction(state),
        0xf9 => try unimplementedInstruction(state),
        0xfa => try unimplementedInstruction(state),
        0xfb => try unimplementedInstruction(state),
        0xfc => try unimplementedInstruction(state),
        0xfd => try unimplementedInstruction(state),
        0xfe => try unimplementedInstruction(state),
        0xff => try unimplementedInstruction(state),
    }
    state.*.pc += 1;
}
