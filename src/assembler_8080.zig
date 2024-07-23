const std = @import("std");
const print = std.debug.print;

const m = @import("main.zig");
const d = @import("disassembler.zig");

const State8080 = m.State8080;
const MemorySize = m.MemorySize;

const InstructionErrors = error{ Unimplemented, IDK };

const FlagErrors = error{
    AnswerInvalid,
    Zero,
    Sign,
    Parity,
    Carry,
};

pub const EmulationResult = enum { Continue, Halt, Unimplemented };

pub fn unimplementedInstruction(state: *State8080) EmulationResult {
    // _ = state;
    state.pc -= 1;
    print("Error: Unimplemented instruction \n", .{});
    return .Unimplemented;
}

inline fn parity(x: u8, size: usize) bool {
    var p: u8 = 0;

    var x_new = (x & ((1 << size) - 1));

    for (0..size) |_| {
        if ((x_new & 0x1) == 0) p += 1;
        x_new = x_new >> 1;
    }
    return 0 == (p & 0x1);
}

fn logicFlagsA(state: *State8080, ans: *const u8) FlagErrors!void {
    // INFO: Zero flag: if the result is 0:
    //
    //  - set the flag to true (1)
    //  - else, clear the flag (false || 0)
    state.cc.z = ((ans.* & 0xff) == 0);

    // INFO: Sign Flag: if bit 7 (MSB) is 1:
    //
    //  - set the flag to true (1)
    //  - else, clear the flag (false || 0)
    state.cc.s = ((ans.* & 0x80) != 0);

    // INFO: Carry Flag:
    //
    // when the instruction in a carry out or borrow
    // is larget than 0xff (which resulted in a higher order bit)
    state.cc.cy = ans.* > 0xff;

    // INFO: Parity:
    //
    //  - set to true (1) if ans has even parity
    //  - set to false (0) if anse has odd parity
    state.cc.p = parity((ans.* & 0xff), 8);

    // INFO: Auxillary Carry (AC)
    //
    // Not used in Space Invaders so we will just
    // ignore this
    // state.*.a = ans & 0xff;
}

pub fn emulate8080P(state: *State8080) EmulationResult {
    const opcode = &state.memory[state.pc]; // Fetching the opcode
    const cycles: u8 = 4;
    _ = cycles;

    print("-----------------------------------\n", .{});
    print("State: \n", .{});
    print(" A: {x:0>4} B: {x:0>4} C: {x:0>4} D: {x:0>4} E: {x:0>4} H: {x:0>4} L: {x:0>4}\n", .{ state.a, state.b, state.*.c, state.*.d, state.*.e, state.*.h, state.*.l });
    print(" SP: {x:0>4} PC: {x:0>4}\n", .{ state.*.sp, state.*.pc });

    d.deassemblerP(state, &state.memory, &state.pc) catch |err| {
        print("Disassembler error: {any}\n", .{err});
        return .Unimplemented;
    };

    // NOTE: Since we are incrementing the PC before the switch statement
    // be aware that when we need to get, for example, byte 3 of the instruction
    // we need to get the byte at state.pc + 2 instead of state.pc + 3
    state.pc += 1;

    const result = switch (opcode.*) {
        // NOP
        // - No operation is performed
        0x00 => .Continue,
        // --- LXI B,D16 ---
        // - Load register pair immediate
        // - (rh) <- byte 3, (rl) <- byte 2
        // - Byte 3 of the instruction is loaded into the high-order register (rh)
        //      of the register pair rp. Byte 2 of the instruction is moved into
        //      the low-order register (rl) of the register pair rp.
        0x01 => {
            state.*.b = state.memory[state.pc + 2]; // rh (Byte 3)
            state.*.c = state.memory[state.pc + 1]; // rl (Byte 2)
            state.*.pc += 2;
            return .Continue;
        },
        0x02 => unimplementedInstruction(state),
        0x03 => unimplementedInstruction(state),
        0x04 => unimplementedInstruction(state),
        // DCR B
        0x05 => {
            // const res: u8 = state.b - @as(u8, 1);
            const res_struct = @subWithOverflow(state.b, @as(u8, 1));
            const fields = @typeInfo(@TypeOf(res_struct)).Struct.fields;
            // var res: u8 = 0;
            const res: u8 = @field(res_struct, fields[0].name);
            // inline for (fields) |field| {
            //     print("field: {s}\n", .{field.name});
            //     // if (field.name == '0') {
            //     //     res = @field(res_struct, field.name);
            //     // }
            // }
            // print("res: {any}\n", .{res});
            state.cc.z = (res == 0);
            state.cc.s = (0x80 == (res & 0x80));
            state.cc.p = parity(res, 8);
            state.b = res;
            return .Continue;
        },
        // MVI B,bytes
        0x06 => {
            state.*.b = state.memory[state.pc];
            state.pc += 1;
            return .Continue;
        },
        0x07 => unimplementedInstruction(state),
        0x08 => unimplementedInstruction(state),
        // DAD B
        0x09 => {
            const hl: u32 = (@as(u32, state.*.h) << 8) | state.*.l;
            const bc: u32 = (@as(u32, state.*.b) << 8) | state.*.c;
            const res: u32 = hl +% bc;
            state.*.h = @truncate(res >> 8);
            state.*.l = @truncate(res & 0xff);
            state.*.cc.cy = ((res & 0xffff0000) != 0);
            return .Continue;
        },
        0x0a => unimplementedInstruction(state),
        0x0b => unimplementedInstruction(state),
        0x0c => unimplementedInstruction(state),
        0x0d => {
            const res: u8 = state.*.c - 1;
            state.*.cc.z = (res == 0);
            state.*.cc.s = (0x80 == (res & 0x80));
            state.*.cc.p = parity(res, 8);
            state.*.c = res;
            return .Continue;
        },
        0x0e => {
            state.*.c = state.memory[state.pc + 1];
            state.*.pc += 1;
            return .Continue;
        },
        0x0f => {
            const x: u8 = state.*.a;
            state.*.a = ((x & 1) << 7) | (x >> 1);
            state.*.cc.cy = (1 == (x & 1));
            return .Continue;
        },
        0x10 => unimplementedInstruction(state),
        0x11 => {
            state.*.e = state.memory[state.pc + 1];
            state.*.d = state.memory[state.pc + 2];
            state.*.pc += 2;
            return .Continue;
        },
        0x12 => unimplementedInstruction(state),
        0x13 => {
            const res_struct = @addWithOverflow(state.e, 1);
            const fields = @typeInfo(@TypeOf(res_struct)).Struct.fields;
            const res: u8 = @field(res_struct, fields[0].name);
            state.e = res;
            if (state.e == 0) {
                state.d += 1;
            }
            return .Continue;
        },
        0x14 => unimplementedInstruction(state),
        0x15 => unimplementedInstruction(state),
        0x16 => unimplementedInstruction(state),
        0x17 => unimplementedInstruction(state),
        0x18 => unimplementedInstruction(state),
        0x19 => unimplementedInstruction(state),
        // LDAX D
        // - Load accumulator indirect
        // - The content of the memory location, whose address is in the register pair rp,
        //      D, is moved to register (accumulator) A.
        0x1a => {
            const addr: u16 = (@as(u16, state.*.d) << 8) | state.*.e;
            state.a = state.memory[addr];
            return .Continue;
        },
        0x1b => unimplementedInstruction(state),
        0x1c => unimplementedInstruction(state),
        0x1d => unimplementedInstruction(state),
        0x1e => unimplementedInstruction(state),
        0x1f => unimplementedInstruction(state),
        0x20 => unimplementedInstruction(state),
        // LXI H,D16
        0x21 => {
            state.l = state.memory[state.pc + 1];
            state.h = state.memory[state.pc + 2];
            state.pc += 2;
            return .Continue;
        },
        0x22 => unimplementedInstruction(state),
        // INX H
        // - Increment register pair
        // - The content of the register pair H is incremented by one.
        // - (rh)
        0x23 => {
            // state.l += 1;
            const res_struct = @addWithOverflow(state.*.l, 1);
            const fields = @typeInfo(@TypeOf(res_struct)).Struct.fields;
            const res: u8 = @field(res_struct, fields[0].name);
            state.*.l = res;
            if (state.l == 0) {
                state.h += 1;
            }
            return .Continue;
        },
        0x24 => unimplementedInstruction(state),
        0x25 => unimplementedInstruction(state),
        0x26 => unimplementedInstruction(state),
        0x27 => unimplementedInstruction(state),
        0x28 => unimplementedInstruction(state),
        0x29 => unimplementedInstruction(state),
        0x2a => unimplementedInstruction(state),
        0x2b => unimplementedInstruction(state),
        0x2c => unimplementedInstruction(state),
        0x2d => unimplementedInstruction(state),
        0x2e => unimplementedInstruction(state),
        0x2f => unimplementedInstruction(state),
        0x30 => unimplementedInstruction(state),
        // --- LXI SP,D16 ---
        // - Load register pair immediate
        // - (rh) <- byte 3, (rl) <- byte 2
        // - In this case, the pair is the 16-bit stack pointer register
        //      - thus, thus the rh is the higher order byte and
        //      the rl is the lower order byte
        // - Byte 3 of the instruction is loaded into the high-order register (rh)
        //     of the register pair rp. Byte 2 of the instruction is moved into
        //     the low-order register (rl) of the register pair rp.
        0x31 => {
            const sp: u16 = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            state.*.sp = sp;
            state.*.pc += 2;
            return .Continue;
        },
        0x32 => unimplementedInstruction(state),
        0x33 => unimplementedInstruction(state),
        0x34 => unimplementedInstruction(state),
        0x35 => unimplementedInstruction(state),
        // MVI M,D8
        // - Move to memory immediate
        // - The content of byte 2 of the instruction is moved to the memory
        //    location whose address is in the register pair H and L.
        0x36 => {
            const addr: u16 = (@as(u16, state.h) << 8) | state.l;
            state.memory[addr] = state.memory[state.pc];
            state.pc += 1;
            // print("Memory at {x:0>4}: {x:0>2}\n", .{ addr, state.memory[addr] });
            return .Continue;
        },
        0x37 => unimplementedInstruction(state),
        0x38 => unimplementedInstruction(state),
        0x39 => unimplementedInstruction(state),
        0x3a => unimplementedInstruction(state),
        0x3b => unimplementedInstruction(state),
        0x3c => unimplementedInstruction(state),
        0x3d => unimplementedInstruction(state),
        0x3e => unimplementedInstruction(state),
        0x3f => unimplementedInstruction(state),
        0x40 => unimplementedInstruction(state),
        0x41 => unimplementedInstruction(state),
        0x42 => unimplementedInstruction(state),
        0x43 => unimplementedInstruction(state),
        0x44 => unimplementedInstruction(state),
        0x45 => unimplementedInstruction(state),
        0x46 => unimplementedInstruction(state),
        0x47 => unimplementedInstruction(state),
        0x48 => unimplementedInstruction(state),
        0x49 => unimplementedInstruction(state),
        0x4a => unimplementedInstruction(state),
        0x4b => unimplementedInstruction(state),
        0x4c => unimplementedInstruction(state),
        0x4d => unimplementedInstruction(state),
        0x4e => unimplementedInstruction(state),
        0x4f => unimplementedInstruction(state),
        0x50 => unimplementedInstruction(state),
        0x51 => unimplementedInstruction(state),
        0x52 => unimplementedInstruction(state),
        0x53 => unimplementedInstruction(state),
        0x54 => unimplementedInstruction(state),
        0x55 => unimplementedInstruction(state),
        0x56 => unimplementedInstruction(state),
        0x57 => unimplementedInstruction(state),
        0x58 => unimplementedInstruction(state),
        0x59 => unimplementedInstruction(state),
        0x5a => unimplementedInstruction(state),
        0x5b => unimplementedInstruction(state),
        0x5c => unimplementedInstruction(state),
        0x5d => unimplementedInstruction(state),
        0x5e => unimplementedInstruction(state),
        0x5f => unimplementedInstruction(state),
        0x60 => unimplementedInstruction(state),
        0x61 => unimplementedInstruction(state),
        0x62 => unimplementedInstruction(state),
        0x63 => unimplementedInstruction(state),
        0x64 => unimplementedInstruction(state),
        0x65 => unimplementedInstruction(state),
        0x66 => unimplementedInstruction(state),
        0x67 => unimplementedInstruction(state),
        0x68 => {
            return .Halt;
        },
        0x69 => unimplementedInstruction(state),
        0x6a => unimplementedInstruction(state),
        0x6b => unimplementedInstruction(state),
        0x6c => unimplementedInstruction(state),
        0x6d => unimplementedInstruction(state),
        0x6e => unimplementedInstruction(state),
        0x6f => unimplementedInstruction(state),
        0x70 => unimplementedInstruction(state),
        0x71 => unimplementedInstruction(state),
        0x72 => unimplementedInstruction(state),
        0x73 => unimplementedInstruction(state),
        0x74 => unimplementedInstruction(state),
        0x75 => unimplementedInstruction(state),
        0x76 => unimplementedInstruction(state),
        // MOV M(HL),A
        // - Move register A to memory
        // - The content of register A is moved to the memory location
        //      whose address is in registers H and L.
        0x77 => {
            const addr: u16 = (@as(u16, state.*.h) << 8) | state.*.l;
            state.memory[addr] = state.a;
            return .Continue;
        },
        0x78 => unimplementedInstruction(state),
        0x79 => unimplementedInstruction(state),
        0x7a => unimplementedInstruction(state),
        0x7b => unimplementedInstruction(state),
        // MOV A,M(HL)
        // - Move memory to register
        // - (r) <- ( (H) (L) )
        // - The content of the memory location, whose address is in registers H and L,
        //    is moved to register A.
        0x7c => {
            const addr: u16 = (@as(u16, state.h) << 8) | state.l;
            state.a = state.memory[addr];
            // state.a = state.h;
            return .Continue;
        },
        0x7d => unimplementedInstruction(state),
        0x7e => unimplementedInstruction(state),
        0x7f => unimplementedInstruction(state),
        0x80 => unimplementedInstruction(state),
        0x81 => unimplementedInstruction(state),
        0x82 => unimplementedInstruction(state),
        0x83 => unimplementedInstruction(state),
        0x84 => unimplementedInstruction(state),
        0x85 => unimplementedInstruction(state),
        0x86 => unimplementedInstruction(state),
        0x87 => unimplementedInstruction(state),
        0x88 => unimplementedInstruction(state),
        0x89 => unimplementedInstruction(state),
        0x8a => unimplementedInstruction(state),
        0x8b => unimplementedInstruction(state),
        0x8c => unimplementedInstruction(state),
        0x8d => unimplementedInstruction(state),
        0x8e => unimplementedInstruction(state),
        0x8f => unimplementedInstruction(state),
        0x90 => unimplementedInstruction(state),
        0x91 => unimplementedInstruction(state),
        0x92 => unimplementedInstruction(state),
        0x93 => unimplementedInstruction(state),
        0x94 => unimplementedInstruction(state),
        0x95 => unimplementedInstruction(state),
        0x96 => unimplementedInstruction(state),
        0x97 => unimplementedInstruction(state),
        0x98 => unimplementedInstruction(state),
        0x99 => unimplementedInstruction(state),
        0x9a => unimplementedInstruction(state),
        0x9b => unimplementedInstruction(state),
        0x9c => unimplementedInstruction(state),
        0x9d => unimplementedInstruction(state),
        0x9e => unimplementedInstruction(state),
        0x9f => unimplementedInstruction(state),
        0xa0 => unimplementedInstruction(state),
        0xa1 => unimplementedInstruction(state),
        0xa2 => unimplementedInstruction(state),
        0xa3 => unimplementedInstruction(state),
        0xa4 => unimplementedInstruction(state),
        0xa5 => unimplementedInstruction(state),
        0xa6 => unimplementedInstruction(state),
        0xa7 => unimplementedInstruction(state),
        0xa8 => unimplementedInstruction(state),
        0xa9 => unimplementedInstruction(state),
        0xaa => unimplementedInstruction(state),
        0xab => unimplementedInstruction(state),
        0xac => unimplementedInstruction(state),
        0xad => unimplementedInstruction(state),
        0xae => unimplementedInstruction(state),
        0xaf => unimplementedInstruction(state),
        0xb0 => unimplementedInstruction(state),
        0xb1 => unimplementedInstruction(state),
        0xb2 => unimplementedInstruction(state),
        0xb3 => unimplementedInstruction(state),
        0xb4 => unimplementedInstruction(state),
        0xb5 => unimplementedInstruction(state),
        0xb6 => unimplementedInstruction(state),
        0xb7 => unimplementedInstruction(state),
        0xb8 => unimplementedInstruction(state),
        0xb9 => unimplementedInstruction(state),
        0xba => unimplementedInstruction(state),
        0xbb => unimplementedInstruction(state),
        0xbc => unimplementedInstruction(state),
        0xbd => unimplementedInstruction(state),
        0xbe => unimplementedInstruction(state),
        0xbf => unimplementedInstruction(state),
        0xc0 => unimplementedInstruction(state),
        0xc1 => unimplementedInstruction(state),
        // JNZ adr
        // - Jump if not zero
        // - If the zero flag is not set, the program counter is loaded with the
        //     address of the instruction specified in the operand.
        // - If the zero flag is set, the program counter is incremented by 2.
        0xc2 => {
            if (!state.cc.z) {
                // const ret: u16 = state.pc + 2;
                // state.memory[state.sp - 1] = @truncate((ret >> 8) & 0xff);
                // state.memory[state.sp - 2] = @truncate(ret & 0xff);
                // state.sp -= 2;
                // state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | @as(u16, state.memory[state.pc]);
                call_instruction(state);
            } else {
                state.pc += 2;
            }

            return .Continue;
        },
        0xc3 => {
            // state.*.pc = @
            // print("state.memory[state.pc]: {x:0>2}\n", .{state.memory[state.pc]});
            // print("state.memory[state.pc + 1]: {x:0>2}\n", .{state.memory[state.pc + 1]});
            state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | @as(u16, state.memory[state.pc]);
            // print("Jumping to {x:0>4}\n", .{state.pc});
            return .Continue;
        },
        0xc4 => unimplementedInstruction(state),
        0xc5 => unimplementedInstruction(state),
        0xc6 => unimplementedInstruction(state),
        0xc7 => unimplementedInstruction(state),
        0xc8 => unimplementedInstruction(state),
        // RET (Return)
        // - The content of the memory location whose address is specified in
        //    the register pair SP (stack pointer) is moved to the low-order
        //    eight bits of register PC (program counter).
        0xc9 => {
            state.pc = (@as(u16, state.memory[state.sp + 1]) << 8) | @as(u16, state.memory[state.sp]);
            state.sp += 2;
            return .Continue;
        },
        0xca => unimplementedInstruction(state),
        0xcb => unimplementedInstruction(state),
        0xcc => unimplementedInstruction(state),
        // CALL adr
        // - The high-order byte of the next instruction address are moved to
        //  the memory location whose address is one less than the content of the
        //  register SP (stack pointer).
        0xcd => {
            const ret: u16 = state.pc + 2;
            state.memory[state.sp - 1] = @truncate((ret >> 8) & 0xff);
            state.memory[state.sp - 2] = @truncate(ret & 0xff);
            state.sp -= 2;
            state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | @as(u16, state.memory[state.pc]);
            return .Continue;
        },
        0xce => unimplementedInstruction(state),
        0xcf => unimplementedInstruction(state),
        0xd0 => unimplementedInstruction(state),
        0xd1 => unimplementedInstruction(state),
        0xd2 => unimplementedInstruction(state),
        0xd3 => unimplementedInstruction(state),
        0xd4 => unimplementedInstruction(state),
        0xd5 => unimplementedInstruction(state),
        0xd6 => unimplementedInstruction(state),
        0xd7 => unimplementedInstruction(state),
        0xd8 => unimplementedInstruction(state),
        0xd9 => unimplementedInstruction(state),
        0xda => unimplementedInstruction(state),
        0xdb => unimplementedInstruction(state),
        0xdc => unimplementedInstruction(state),
        0xdd => unimplementedInstruction(state),
        0xde => unimplementedInstruction(state),
        0xdf => unimplementedInstruction(state),
        0xe0 => unimplementedInstruction(state),
        0xe1 => unimplementedInstruction(state),
        0xe2 => unimplementedInstruction(state),
        0xe3 => unimplementedInstruction(state),
        0xe4 => unimplementedInstruction(state),
        0xe5 => unimplementedInstruction(state),
        0xe6 => unimplementedInstruction(state),
        0xe7 => unimplementedInstruction(state),
        0xe8 => unimplementedInstruction(state),
        0xe9 => unimplementedInstruction(state),
        0xea => unimplementedInstruction(state),
        0xeb => unimplementedInstruction(state),
        0xec => unimplementedInstruction(state),
        0xed => unimplementedInstruction(state),
        0xee => unimplementedInstruction(state),
        0xef => unimplementedInstruction(state),
        0xf0 => unimplementedInstruction(state),
        0xf1 => unimplementedInstruction(state),
        0xf2 => unimplementedInstruction(state),
        0xf3 => unimplementedInstruction(state),
        0xf4 => unimplementedInstruction(state),
        0xf5 => unimplementedInstruction(state),
        0xf6 => unimplementedInstruction(state),
        0xf7 => unimplementedInstruction(state),
        0xf8 => unimplementedInstruction(state),
        0xf9 => unimplementedInstruction(state),
        0xfa => unimplementedInstruction(state),
        0xfb => unimplementedInstruction(state),
        0xfc => unimplementedInstruction(state),
        0xfd => unimplementedInstruction(state),
        // CPI D8
        // - Compare immediate
        // - (A) -- (byte 2)
        // - The content of the second byte of the instruction is subtracted
        //      from the accumulator (register A). The condition flags are set
        //      by the result of the subtraction. The Z flag is set 1 (true) if
        //      (A) = (byte 2), otherwise it is set to 0 (false). The CY flag is
        //      set to 1 (true) if (A) < (byte 2), otherwise its 0 (false).
        0xfe => {
            const res_struct = @subWithOverflow(state.a, state.memory[state.pc]);
            const fields = @typeInfo(@TypeOf(res_struct)).Struct.fields;
            const res: u8 = @field(res_struct, fields[0].name);
            // state.a = res;
            // logicFlagsA(state, &res) catch |err| {
            //     print("Error: {any}\n", .{err});
            //     return .Unimplemented;
            // };
            state.cc.z = (res == state.memory[state.pc]);
            state.cc.s = (0x80 == (res & 0x80));
            state.cc.p = parity(res, 8);
            state.cc.cy = (state.a < state.memory[state.pc]);
            state.pc += 1;
            // state->cc.z = (x == 0);
            // state->cc.s = (0x80 == (x & 0x80));
            // state->cc.p = parity(x, 8);
            // state->cc.cy = (state->a < opcode[1]);
            // state->pc++;
            return .Continue;
        },
        0xff => unimplementedInstruction(state),
    };

    // print("PC: {x:0>4}\n", .{state.*.pc});
    // if (result == .Continue) {
    //     state.*.pc += 1;
    // }
    // print("PC: {x:0>4}\n", .{state.*.pc});

    return result;
}

fn call_instruction(state: *State8080) void {
    const ret: u16 = state.pc + 2;
    state.memory[state.sp - 1] = @truncate((ret >> 8) & 0xff);
    state.memory[state.sp - 2] = @truncate(ret & 0xff);
    state.sp -= 2;
    state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | @as(u16, state.memory[state.pc]);
}
