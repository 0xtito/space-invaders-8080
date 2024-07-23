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
    state.cc.z = (ans.* == 0);

    // INFO: Sign Flag: if bit 7 (MSB) is 1:
    //
    //  - set the flag to true (1)
    //  - else, clear the flag (false || 0)
    state.cc.s = (0x80 == (ans.* & 0x80));

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
        // DAD D
        0x19 => {
            const hl: u32 = (@as(u32, state.*.h) << 8) | state.*.l;
            const de: u32 = (@as(u32, state.*.d) << 8) | state.*.e;
            const res: u32 = hl +% de;
            state.*.h = @truncate((res & 0xff00) >> 8);
            state.*.l = @truncate(res & 0xff);
            state.*.cc.cy = ((res & 0xffff0000) != 0);
            return .Continue;
        },
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
            const res_struct = @addWithOverflow(state.*.l, 1);
            const fields = @typeInfo(@TypeOf(res_struct)).Struct.fields;
            const res: u8 = @field(res_struct, fields[0].name);
            state.l = res;
            if (state.l == 0) {
                const h_struct = @addWithOverflow(state.*.h, 1);
                const h_fields = @typeInfo(@TypeOf(h_struct)).Struct.fields;
                state.h = @field(h_struct, h_fields[0].name);
            }
            return .Continue;
        },
        0x24 => unimplementedInstruction(state),
        0x25 => unimplementedInstruction(state),
        // MVI H,D8
        0x26 => {
            state.h = state.memory[state.pc];
            state.pc += 1;
            return .Continue;
        },
        0x27 => unimplementedInstruction(state),
        0x28 => unimplementedInstruction(state),
        // DAD H
        // - Add register pair H to H and L
        0x29 => {
            const hl: u32 = (@as(u32, state.h) << 8) | state.l;
            const res: u32 = hl +% hl;
            state.h = @truncate(res >> 8);
            state.l = @truncate(res & 0xff);
            state.cc.cy = ((res & 0xffff0000) != 0);
            return .Continue;
        },
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
        // STA adr
        // - Store accumulator direct
        // - ( (byte 3) (byte 2) ) <- (A)
        // - The content of the accumulator (register A) is moved
        //      to the memory location whose address is specified in
        //      byte 2 and byte 3 of the instruction.
        0x32 => {
            const addr: u16 = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            state.memory[addr] = state.a;
            state.pc += 2;
            return .Continue;
        },
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
        // LDA adr
        // - Load accumulator direct
        // - (A) <- ((byte 3) (byte 2))
        // - The content of the memory location, whose address
        //      is specified in byte 2 and byte 3 of the instruction,
        //      is moved to the accumulator (register A).
        0x3a => {
            const addr: u16 = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            state.a = state.memory[addr];
            state.pc += 2;
            return .Continue;
        },
        0x3b => unimplementedInstruction(state),
        0x3c => unimplementedInstruction(state),
        0x3d => unimplementedInstruction(state),
        // MVI A,D8
        0x3e => {
            state.a = state.memory[state.pc];
            state.pc += 1;
            return .Continue;
        },
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
        // MOV D,M
        0x56 => {
            const addr: u16 = (@as(u16, state.h) << 8) | state.l;
            state.d = state.memory[addr];
            return .Continue;
        },
        0x57 => unimplementedInstruction(state),
        0x58 => unimplementedInstruction(state),
        0x59 => unimplementedInstruction(state),
        0x5a => unimplementedInstruction(state),
        0x5b => unimplementedInstruction(state),
        0x5c => unimplementedInstruction(state),
        0x5d => unimplementedInstruction(state),
        // MOV E,H
        // - Move Register H to Register E
        0x5e => {
            state.e = state.h;
            return .Continue;
        },
        0x5f => unimplementedInstruction(state),
        0x60 => unimplementedInstruction(state),
        0x61 => unimplementedInstruction(state),
        0x62 => unimplementedInstruction(state),
        0x63 => unimplementedInstruction(state),
        0x64 => unimplementedInstruction(state),
        0x65 => unimplementedInstruction(state),
        // MOV H, M
        0x66 => {
            const addr: u16 = (@as(u16, state.h) << 8) | state.l;
            state.h = state.memory[addr];
            return .Continue;
        },
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
        // MOV L, A
        0x6f => {
            state.l = state.a;
            return .Continue;
        },
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
        // MOV D,A
        0x7a => {
            state.d = state.a;
            return .Continue;
        },
        // MOV E,A
        // - Move register A to register E
        0x7b => {
            state.e = state.a;
            return .Continue;
        },
        // MOV A,M(HL)
        // - Move memory to register
        // - (r) <- ( (H) (L) )
        // - The content of the memory location, whose address is in registers H and L,
        //    is moved to register A.
        0x7c => {
            const addr: u16 = (@as(u16, state.h) << 8) | state.l;
            state.a = state.memory[addr];
            return .Continue;
        },
        0x7d => unimplementedInstruction(state),
        // MOV A, M
        // - Move memory to register
        0x7e => {
            const addr: u16 = (@as(u16, state.h) << 8) | state.l;
            state.a = state.memory[addr];
            return .Continue;
        },
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
        // ANA D8
        // - AND immediate
        0xa7 => {
            const ans: u8 = state.a & state.a;
            state.cc.cy = false; // Hardcoding to false since AC is not used
            state.cc.z = (ans == 0);
            state.cc.s = (0x80 == (ans & 0x80));
            state.cc.p = parity(ans, 8);
            state.a = ans;
            return .Continue;
        },
        0xa8 => unimplementedInstruction(state),
        0xa9 => unimplementedInstruction(state),
        0xaa => unimplementedInstruction(state),
        0xab => unimplementedInstruction(state),
        0xac => unimplementedInstruction(state),
        0xad => unimplementedInstruction(state),
        0xae => unimplementedInstruction(state),
        // XRA A
        // - Exclusive OR with register A
        0xaf => {
            const ans: u8 = state.a ^ state.a;
            state.cc.cy = false; // Hardcoding to false since AC is not used
            state.cc.z = (ans == 0);
            state.cc.s = (0x80 == (ans & 0x80));
            state.cc.p = parity(ans, 8);
            state.a = ans;
            return .Continue;
        },
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
        // POP B
        0xc1 => {
            state.c = state.memory[state.sp];
            state.b = state.memory[state.sp + 1];
            state.sp += 2;
            return .Continue;
        },
        // JNZ adr
        // - Jump if not zero
        // - If the zero flag is not set, the program counter is loaded with the
        //     address of the instruction specified in the operand.
        // - If the zero flag is set, the program counter is incremented by 2.
        0xc2 => {
            if (!state.cc.z) {
                state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | state.memory[state.pc];
            } else {
                state.pc += 2;
            }

            return .Continue;
        },
        0xc3 => {
            state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | @as(u16, state.memory[state.pc]);
            return .Continue;
        },
        0xc4 => unimplementedInstruction(state),
        // PUSH B
        0xc5 => {
            state.memory[state.sp - 1] = state.b;
            state.memory[state.sp - 2] = state.c;
            state.sp -= 2;
            return .Continue;
        },
        // ADI D8
        // - Add immediate
        // - (A) <- (A) + (byte 2)
        // - The content of the second byte of the instruction is added to the
        //      content of the accumulator (register A). The result is placed in
        //      the accumulator.
        0xc6 => {
            const res_struct = @addWithOverflow(state.a, state.memory[state.pc]);
            const fields = @typeInfo(@TypeOf(res_struct)).Struct.fields;
            const res: u8 = @field(res_struct, fields[0].name);
            state.cc.z = (res == 0);
            state.cc.s = (0x80 == (res & 0x80));
            state.cc.p = parity(res, 8);
            state.cc.cy = (res > 0xff);
            state.a = res;
            state.pc += 1;
            return .Continue;
        },
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
        // POP D
        0xd1 => {
            state.e = state.memory[state.sp];
            state.d = state.memory[state.sp + 1];
            state.sp += 2;
            return .Continue;
        },
        0xd2 => unimplementedInstruction(state),
        // OUT D8
        // - (data) <- (A)
        // - The content of the accumulator (register A) is moved to the output
        // FIX: What is the output? Incrementing for now.
        0xd3 => {
            state.pc += 1;
            return .Continue;
        },
        0xd4 => unimplementedInstruction(state),
        // PUSH D
        // - Push Register Pair
        // - ( (SP) - 1 ) <- (rh), ( (SP) - 2 ) <- (rl), (SP) <- (SP) - 2
        0xd5 => {
            state.memory[state.sp - 1] = state.d;
            state.memory[state.sp - 2] = state.e;
            state.sp = state.sp - 2;
            return .Continue;
        },
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
        // POP H
        0xe1 => {
            state.h = state.memory[state.sp + 1];
            state.l = state.memory[state.sp];
            state.sp += 2;
            return .Continue;
        },
        0xe2 => unimplementedInstruction(state),
        0xe3 => unimplementedInstruction(state),
        0xe4 => unimplementedInstruction(state),
        0xe5 => {
            state.memory[state.sp - 1] = state.h;
            state.memory[state.sp - 2] = state.l;
            state.sp -= 2;
            return .Continue;
        },
        // ANI D8
        // - AND immediate
        // - (A) <- (A) & (byte 2)
        0xe6 => {
            const res = state.a & state.memory[state.pc];
            state.cc.z = (res == 0);
            state.cc.s = (0x80 == (res & 0x80));
            state.cc.p = parity(res, 8);
            state.cc.cy = false;
            state.a = res;
            state.pc += 1;
            return .Continue;
        },
        0xe7 => unimplementedInstruction(state),
        0xe8 => unimplementedInstruction(state),
        0xe9 => unimplementedInstruction(state),
        0xea => unimplementedInstruction(state),
        // XCHG
        // - Exchange H and L with D and E
        // - The contents of the H register is exchanged with
        //      the contents of the D register.
        0xeb => {
            const save1: u8 = state.d;
            const save2: u8 = state.e;
            state.d = state.h;
            state.e = state.l;
            state.h = save1;
            state.l = save2;
            return .Continue;
        },
        0xec => unimplementedInstruction(state),
        0xed => unimplementedInstruction(state),
        0xee => unimplementedInstruction(state),
        0xef => unimplementedInstruction(state),
        0xf0 => unimplementedInstruction(state),
        // POP PSW
        // - Pop process status word
        // - The contents of the memory location whose address is in the
        //     register pair SP (stack pointer) are moved to the low-order
        // - The content of the memory location whose address
        //      is specified by the content of register SP is used to
        //      restore the condition flags.
        // - The content of the memory location whose address is one
        //      more than the content of register SP is moved to register A.
        // - The content of register SP is incremented by 2.
        0xf1 => {
            state.a = state.memory[state.sp + 1];
            const psw = state.memory[state.sp];
            state.cc.z = (0x01 == (psw & 0x01));
            state.cc.s = (0x02 == (psw & 0x02));
            state.cc.p = (0x04 == (psw & 0x04));
            state.cc.cy = (0x08 == (psw & 0x08));
            state.cc.ac = (0x10 == (psw & 0x10));
            state.sp += 2;
            return .Continue;
        },
        0xf2 => unimplementedInstruction(state),
        0xf3 => unimplementedInstruction(state),
        0xf4 => unimplementedInstruction(state),
        // PUSH PSW
        // - Push process status word
        // - The contents of the accumulator (register A) are moved to
        //      to the memory location whose address is one less than the
        //      content of the register SP (stack pointer).
        // - The contents of the condition flags are assembled
        //      into a processor status word and the word is moved
        //      to the memory location whose address is two less
        //      than the content of register SP.
        0xf5 => {
            state.memory[state.sp - 1] = state.a;
            const psw: u8 = @as(u8, @intFromBool(state.cc.z)) |
                (@as(u8, @intFromBool(state.cc.s)) << 1) |
                (@as(u8, @intFromBool(state.cc.p)) << 2) |
                (@as(u8, @intFromBool(state.cc.cy)) << 3) |
                (@as(u8, @intFromBool(state.cc.ac)) << 4);
            state.memory[state.sp - 2] = psw;
            state.sp -= 2;
            return .Continue;
        },
        0xf6 => unimplementedInstruction(state),
        0xf7 => unimplementedInstruction(state),
        0xf8 => unimplementedInstruction(state),
        0xf9 => unimplementedInstruction(state),
        0xfa => unimplementedInstruction(state),
        //  EI
        // - Enable interrupts
        0xfb => {
            state.int_enabled = true;
            return .Continue;
        },
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
            state.cc.z = (res == state.memory[state.pc]);
            state.cc.s = (0x80 == (res & 0x80));
            state.cc.p = parity(res, 8);
            state.cc.cy = (state.a < state.memory[state.pc]);
            state.pc += 1;
            return .Continue;
        },
        0xff => unimplementedInstruction(state),
    };

    return result;
}

fn call_instruction(state: *State8080) void {
    const ret: u16 = state.pc + 2;
    state.memory[state.sp - 1] = @truncate((ret >> 8) & 0xff);
    state.memory[state.sp - 2] = @truncate(ret & 0xff);
    state.sp -= 2;
    state.pc = (@as(u16, state.memory[state.pc + 1]) << 8) | @as(u16, state.memory[state.pc]);
}
