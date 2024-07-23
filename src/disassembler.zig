const std = @import("std");
const print = std.debug.print;

const m = @import("main.zig");

const MemorySize = m.MemorySize;
const RomContent = @import("main.zig").RomContent;
const RomData = @import("main.zig").RomData;

fn printFlags(state: *const m.State8080) !void {
    print("Flags: ", .{});
    print("S: {} | ", .{state.cc.s});
    print("Z: {} | ", .{state.cc.z});
    print("AC: {} | ", .{state.cc.ac});
    print("P: {} | ", .{state.cc.p});
    print("CY: {}\n", .{state.cc.cy});
}

// pub fn deassemblerP(state_memory: *const [MemorySize]u8, pc: *const u16) !u16 {
pub fn deassemblerP(state: *const m.State8080, state_memory: *const [MemorySize]u8, pc: *const u16) !void {
    const opcode = state_memory[pc.*];
    var op_bytes: u16 = 1;

    print("{x:0>4}   {x:0>2}   ", .{ pc.*, opcode });

    if (opcode >= 0x40 and opcode <= 0x7F) {
        try deassembleMOV(state_memory, pc);
        print("\n", .{});
        return;
        // return op_bytes;
    }

    // try printFlags(state);
    _ = state;

    switch (opcode) {
        0x00 => print("NOP", .{}),
        0x01 => {
            print("LXI   B{x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0x02 => print("STAX   B", .{}),
        0x03 => print("INX   B", .{}),
        0x04 => print("INR   B", .{}),
        0x05 => print("DCR   B", .{}),
        0x06 => {
            print("MVI   B,#0x{x:0>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0x07 => print("RLC", .{}),
        0x08 => print("NOP", .{}),
        0x09 => print("DAD   B", .{}),
        0x0a => print("LDAX   B", .{}),
        0x0b => print("DCX   B", .{}),
        0x0c => print("INR   C", .{}),
        0x0d => print("DCR   C", .{}),
        0x0e => {
            print("MVI   C,#0x{x:x>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0x0f => {
            print("RRC", .{});
        },
        0x10 => print("NOP", .{}),
        0x11 => {
            print("LXI   D{x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0x12 => print("STAX   D", .{}),
        0x13 => print("INX   D", .{}),
        0x14 => print("INR   D", .{}),
        0x15 => print("DCR   D", .{}),
        0x16 => {
            print("LXI   D{x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0x17 => print("RAL", .{}),

        0x18 => print("NOP", .{}),

        0x19 => print("DAD   D", .{}),
        0x1a => print("LDAX   D", .{}),
        0x1b => print("DCX   D", .{}),
        0x1c => print("INR   E", .{}),
        0x1d => print("DCR   E", .{}),
        0x1e => {
            print("MVI   E,#0x{x:x>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0x1f => print("RAR", .{}),

        0x20 => print("NOP", .{}),

        0x21 => {
            print("LXI   H{x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0x22 => print("SHLD   ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] }),
        0x23 => print("INX   H", .{}),
        0x24 => print("INR   H", .{}),
        0x25 => print("DCR   H", .{}),
        0x26 => {
            print("MVI   H,#0x{x:0>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0x27 => print("DAA", .{}),

        0x28 => print("NOP", .{}),

        0x29 => print("DAD   H", .{}),
        0x2a => print("LHLD   H", .{}),
        0x2b => print("DCX   H", .{}),
        0x2c => print("INR   L", .{}),
        0x2d => print("DCR   L", .{}),
        0x2e => {
            print("MVI   L,#0x{x:x>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0x2f => print("CMA", .{}),

        0x30 => print("NOP", .{}),

        0x31 => {
            print("LXI   SP,{x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0x32 => {
            print("STA   ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0x33 => print("INX   SP", .{}),
        0x34 => print("INR   M", .{}),
        0x35 => print("DCR   M", .{}),
        0x36 => {
            print("MVI   M{x:0>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0x37 => print("STC", .{}),

        0x38 => print("NOP", .{}),

        0x39 => print("DAD   SP", .{}),
        0x3a => {
            print("LDA   ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0x3b => print("DCX   SP", .{}),
        0x3c => print("INR   A", .{}),
        0x3d => print("DCR   A", .{}),
        0x3e => {
            print("MVI   A,#0x{x:0>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0x3f => print("CMC", .{}),

        // 0x40 through 0x7f are all MOV opcodes (and the special case HLT)
        // see `disassembleMOV`

        // NOTE: ADD r - Compare Register ( (A) - (r) )
        // The content of register r is subtracted from the accumulator.
        0x80 => print("ADD   B", .{}),
        0x81 => print("ADD   C", .{}),
        0x82 => print("ADD   D", .{}),
        0x83 => print("ADD   E", .{}),
        0x84 => print("ADD   H", .{}),
        0x85 => print("ADD   L", .{}),
        0x86 => print("ADD   M", .{}),
        0x87 => print("ADD   A", .{}),
        0x88 => print("ADC   B", .{}),
        0x89 => print("ADC   C", .{}),
        0x8a => print("ADC   D", .{}),
        0x8b => print("ADC   E", .{}),
        0x8c => print("ADC   H", .{}),
        0x8d => print("ADC   L", .{}),
        0x8e => print("ADC   M", .{}),
        0x8f => print("ADC   A", .{}),

        0x90 => print("SUB   B", .{}),
        0x91 => print("SUB   C", .{}),
        0x92 => print("SUB   D", .{}),
        0x93 => print("SUB   E", .{}),
        0x94 => print("SUB   H", .{}),
        0x95 => print("SUB   L", .{}),
        0x96 => print("SUB   M", .{}),
        0x97 => print("SUB   A", .{}),
        0x98 => print("SBB   B", .{}),
        0x99 => print("SBB   C", .{}),
        0x9a => print("SBB   D", .{}),
        0x9b => print("SBB   E", .{}),
        0x9c => print("SBB   H", .{}),
        0x9d => print("SBB   L", .{}),
        0x9e => print("SBB   M", .{}),
        0x9f => print("SBB   A", .{}),

        0xa0 => print("ANA   B", .{}),
        0xa1 => print("ANA   C", .{}),
        0xa2 => print("ANA   D", .{}),
        0xa3 => print("ANA   E", .{}),
        0xa4 => print("ANA   H", .{}),
        0xa5 => print("ANA   L", .{}),
        0xa6 => print("ANA   M", .{}),
        0xa7 => print("ANA   A", .{}),
        0xa8 => print("XRA   B", .{}),
        0xa9 => print("XRA   C", .{}),
        0xaa => print("XRA   D", .{}),
        0xab => print("XRA   E", .{}),
        0xac => print("XRA   H", .{}),
        0xad => print("XRA   L", .{}),
        0xae => print("XRA   M", .{}),
        0xaf => print("XRA   A", .{}),

        0xb0 => print("ORA   B", .{}),
        0xb1 => print("ORA   C", .{}),
        0xb2 => print("ORA   D", .{}),
        0xb3 => print("ORA   E", .{}),
        0xb4 => print("ORA   H", .{}),
        0xb5 => print("ORA   L", .{}),
        0xb6 => print("ORA   M", .{}),
        0xb7 => print("ORA   A", .{}),
        // NOTE: CMP r - Compare Register ( (A) - (r) )
        // The content of register r is subtracted from the accumulator.
        0xb8 => print("CMP   B", .{}),
        0xb9 => print("CMP   C", .{}),
        0xba => print("CMP   D", .{}),
        0xbb => print("CMP   E", .{}),
        0xbc => print("CMP   H", .{}),
        0xbd => print("CMP   L", .{}),
        0xbe => print("CMP   M", .{}),
        0xbf => print("CMP   A", .{}),

        0xc0 => print("RNZ", .{}),
        0xc1 => print("POP   B", .{}),
        0xc2 => {
            print("JNZ   ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xc3 => {
            print("JMP   ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xc4 => {
            print("CNZ   ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xc5 => print("PUSH  B", .{}),
        0xc6 => {
            print("ADI   ${x:0>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0xc7 => print("RST   0", .{}),
        0xc8 => print("RZ", .{}),
        0xc9 => print("RET", .{}),
        0xca => {
            print("JZ    ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xcb => print("NOP", .{}), // This opcode is not used in 8080
        0xcc => {
            print("CZ    ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xcd => {
            print("CALL  ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xce => {
            print("ACI   ${x:0>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0xcf => print("RST   1", .{}),
        0xd0 => print("RNC", .{}),
        0xd1 => print("POP   D", .{}),
        0xd2 => {
            print("JNC   ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xd3 => {
            print("OUT   ${x:0>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0xd4 => {
            print("CNC   ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xd5 => print("PUSH  D", .{}),
        0xd6 => {
            print("SUI   ${x:0>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0xd7 => print("RST   2", .{}),
        0xd8 => print("RC", .{}),
        0xd9 => print("NOP", .{}), // This opcode is not used in 8080
        0xda => {
            print("JC    ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xdb => {
            print("IN    ${x:0>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0xdc => {
            print("CC    ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xdd => print("NOP", .{}), // This opcode is not used in 8080
        0xde => {
            print("SBI   ${x:0>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0xdf => print("RST   3", .{}),
        0xe0 => print("RPO", .{}),
        0xe1 => print("POP   H", .{}),
        0xe2 => {
            print("JPO   ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xe3 => print("XTHL", .{}),
        0xe4 => {
            print("CPO   ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xe5 => print("PUSH  H", .{}),
        0xe6 => {
            print("ANI   ${x:0>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0xe7 => print("RST   4", .{}),
        0xe8 => print("RPE", .{}),
        0xe9 => print("PCHL", .{}),
        0xea => {
            print("JPE   ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xeb => print("XCHG", .{}),
        0xec => {
            print("CPE   ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xed => print("NOP", .{}), // This opcode is not used in 8080
        0xee => {
            print("XRI   ${x:0>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0xef => print("RST   5", .{}),
        0xf0 => print("RP", .{}),
        0xf1 => print("POP   PSW", .{}),
        0xf2 => {
            print("JP   ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xf3 => print("DI", .{}),
        0xf4 => {
            print("CP    ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xf5 => print("PUSH  PSW", .{}),
        0xf6 => {
            print("ORI   ${x:0>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0xf7 => print("RST   6", .{}),
        0xf8 => print("RM", .{}),
        0xf9 => print("SPHL", .{}),
        0xfa => {
            print("JM    ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xfb => print("EI", .{}),
        0xfc => {
            print("CM    ${x:0>2}{x:0>2}", .{ state_memory[pc.* + 2], state_memory[pc.* + 1] });
            op_bytes = 3;
        },
        0xfd => print("NOP", .{}), // This opcode is not used in 8080
        0xfe => {
            print("CPI   ${x:0>2}", .{state_memory[pc.* + 1]});
            op_bytes = 2;
        },
        0xff => print("RST   7", .{}),
        else => {
            print("NOT SETUP YET", .{});
            // op_bytes += 1;

            // if (code.* >= 0x40 and code.* <= 0x7F) {
            //     _ = try deassembleMOV(rom_ptr, pc);
            // }
        },
    }
    print("\n", .{});

    // return op_bytes;
}

// NOTE: All of the registers.
// M is actually not a register, it stands for "Memory"
// Though, for simplicity, will be added to the Register Enum (may change)
const Register = enum { B, C, D, E, H, L, M, A };

const RegisterPair = struct {
    dest: Register,
    src: Register,
};

fn getRegisterPair(opcode: u8) RegisterPair {
    const dest: Register = @enumFromInt((opcode - 0x40) >> 3);
    const src: Register = @enumFromInt(opcode & 0x07);
    return RegisterPair{ .dest = dest, .src = src };
}

fn registerToString(reg: Register) []const u8 {
    return switch (reg) {
        .M => "M(HL)",
        else => @tagName(reg),
    };
}

// NOTE: Prob have to rework/double check it
pub inline fn deassembleMOV(state_memory: *const [MemorySize]u8, pc: *const u16) !void {
    const opcode = state_memory[pc.*];

    if (opcode < 0x40 or opcode > 0x7F) {
        return error.InvalidOpcode;
    }

    const pair = getRegisterPair(opcode);

    if (opcode == 0x76) {
        std.debug.print("0x{x:0>4}: HLT\n", .{pc});
        return;
    }

    const dest_str = registerToString(pair.dest);
    const src_str = registerToString(pair.src);

    // std.debug.print("0x{X:0>4}: MOV {s},{s}\n", .{pc, dest_str, src_str});
    print("MOV   {s},{s}    {x:0>4}", .{ dest_str, src_str, pc });
}
