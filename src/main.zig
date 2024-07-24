const std = @import("std");
const print = std.debug.print;

const d = @import("disassembler.zig");
const a = @import("assembler_8080.zig");
const m = @import("machine/machine.zig");

// NOTE: THis is the max memory size for the 8080
// May consist of both ROM and RAM
pub const MemorySize = 0x10000; // 64KB = 65536 bytes

// NOTE: Each invaders file is 0x7f0 bytes long
// which equates to 2032 bytes
// Thus, 0x2000 bytes is enough to store each file
pub const RomSize = 0x2000; // 2KB = 8192 bytes

pub const RomData = [8192]u8;
pub const RomContent = struct { data: RomData, len: usize };

pub const ConditionCodes = struct {
    z: bool,
    s: bool,
    p: bool,
    cy: bool,
    ac: bool,
    pad: u3,

    pub fn pack(self: ConditionCodes) u8 {
        return @as(u8, @intFromBool(self.z)) |
            (@as(u8, @intFromBool(self.s)) << 1) |
            (@as(u8, @intFromBool(self.p)) << 2) |
            (@as(u8, @intFromBool(self.cy)) << 3) |
            (@as(u8, @intFromBool(self.ac)) << 4) |
            (@as(u8, self.pad) << 5);
    }

    pub fn unpack(value: u8) ConditionCodes {
        return ConditionCodes{
            .z = (value & 0b00000001) != 0,
            .s = (value & 0b00000010) != 0,
            .p = (value & 0b00000100) != 0,
            .cy = (value & 0b00001000) != 0,
            .ac = (value & 0b00010000) != 0,
            .pad = @truncate(value >> 5),
        };
    }
};

// NOTE: This is the state of the 8080 CPU
// - a: 8-bit accumulator register
// - b: 8-bit register
// - c: 8-bit register
// - d: 8-bit register
// - e: 8-bit register
// - h: 8-bit register
// - l: 8-bit register
// - sp: 16-bit stack pointer register
//      - points to the current stack location
// - pc: 16-bit program counter register
// - memory: 64KB memory
// - cc: condition codes
// - int_enabled: interrupt enabled flag
pub const State8080 = struct { a: u8, b: u8, c: u8, d: u8, e: u8, h: u8, l: u8, sp: u16, pc: u16, memory: [MemorySize]u8, cc: ConditionCodes, int_enabled: bool };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // const allocator = gpa.allocator();
    // _ = allocator;

    if (true) {
        try test_machine();
    } else {
        var state: State8080 = try initState8080();

        print("State initialized.\n", .{});
        print("Memory size: {d}\n", .{state.memory.len});
        // defer allocator.free(state.memory);
        //

        if (true) {
            try getBin(&state);
        } else {
            try getRom(&state, "invaders.h", 0x0000);
            try getRom(&state, "invaders.g", 0x0800);
            try getRom(&state, "invaders.f", 0x1000);
            try getRom(&state, "invaders.e", 0x1800);
        }

        var count: u32 = 0;
        emulation_loop: while (true) {
            switch (a.emulate8080P(&state)) {
                .Continue => {
                    count += 1;
                    continue :emulation_loop;
                },
                .Halt => {
                    print("Halted.\n", .{});
                    print("Instructions executed: {d}\n", .{count});
                    break :emulation_loop;
                },
                .Unimplemented => {
                    print("Unimplemented instruction.\n", .{});
                    print("Instructions executed: {d}\n", .{count});
                    break :emulation_loop;
                },
            }
        }
    }
}

fn test_machine() !void {
    var machine: m.Machine = try m.initMachine();

    machine.doCpu();
}

pub fn getRom(state: *State8080, file_name: *const [10]u8, offset: u32) !void {
    // Get the current working directory
    const cwd = std.fs.cwd();

    var output_dir = try cwd.openDir("src/roms", .{});
    defer output_dir.close();

    // const file = try output_dir.openFile("invaders.concatenated", .{});
    // const file = try output_dir.openFile("invaders.h", .{});
    // const file = try output_dir.openFile("invaders.g", .{});

    const file = try output_dir.openFile(file_name, .{});
    defer file.close();

    var buffer: [2048]u8 = undefined;
    const bytes_read = try file.readAll(&buffer);

    print("Successfully read {d} bytes from the file {s}.\n", .{ bytes_read, file_name });
    print("File name: {s}\n", .{file_name});
    print("Memory slot: {d}\n", .{offset});

    std.mem.copyForwards(u8, state.memory[offset..], buffer[0..bytes_read]);
}

pub fn getBin(state: *State8080) !void {
    const cwd = std.fs.cwd();

    var output_dir = try cwd.openDir("src", .{});
    defer output_dir.close();

    const file = try output_dir.openFile("cpudiag.bin", .{});
    defer file.close();

    var buffer: [8096]u8 = undefined;
    const bytes_read = try file.readAll(&buffer);

    print("Successfully read {d} bytes from the file.\n", .{bytes_read});

    std.mem.copyForwards(u8, state.memory[0x100..], buffer[0..bytes_read]);

    // Fix the first instruction to be JMP 0x100
    state.memory[0] = 0xc3;
    state.memory[1] = 0;
    state.memory[2] = 0x01;

    // Fix the stack pointer from 0x6ad to 0x7ad
    // this 0x06 byte 112 in the code, which is
    // byte 112 + 0x100 = 368 in memory
    state.memory[368] = 0x7;

    // Skip DAA test
    state.memory[0x59c] = 0xc3; // JMP
    state.memory[0x59d] = 0xc2;
    state.memory[0x59e] = 0x05;
}

fn printRomData(data: *const RomData) void {
    for (data[0..128]) |byte| {
        print("{x:0>2} ", .{byte});
    }
}

// pub fn initState8080(allocator: std.mem.Allocator) !State8080 {
pub fn initState8080() !State8080 {
    // const memory: []u8 = try allocator.alloc(u8, 0x10000);
    //
    // @memset(memory, 0);

    // INFO: Initialize the state of the 8080 CPU
    // I am purposefully being explicit here regarding the initial values
    //  being set to their hexadecimal equivalent for educational reasons
    const state: State8080 = State8080{
        .a = 0x00,
        .b = 0x00,
        .c = 0x00,
        .d = 0x00,
        .e = 0x00,
        .h = 0x00,
        .l = 0x00,
        .sp = 0x0000,
        .pc = 0x0000,
        .memory = [_]u8{0} ** MemorySize,
        .cc = ConditionCodes{ .z = false, .s = false, .p = false, .cy = false, .ac = false, .pad = 0 },
        .int_enabled = false,
    };

    return state;
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
