const std = @import("std");
const print = std.debug.print;

const m = @import("../main.zig");
const a = @import("../assembler_8080.zig");
const assembler = @import("8080emu_2.zig");

const State8080 = m.State8080;

pub const Machine = struct {
    state: State8080,

    last_timer: i64,
    next_interrupt: i64,
    which_interrupt: u8,

    // LSB of Space Invader's external shift hardware
    shift0: u8,
    // MSB of Space Invader's external shift hardware
    shift1: u8,
    // Offset for external shift hardware
    shift_offset: u8,

    // in: fn (self: Machine, port: u8) u8,
    pub fn machineIn(self: *Machine, port: u8) u8 {
        var new_a: u8 = self.state.a;

        switch (port) {
            0 => {
                return 1;
            },
            1 => {
                return 0;
            },
            3 => {
                const v: u16 = ((@as(u16, self.shift1) << 8) | self.shift0);
                // self.state.pc = (@as(u16, self.state.memory[self.state.pc + 1]) << 8) | @as(u16, self.state.memory[self.state.pc]);
                const res: u4 = @truncate(8 -% self.shift_offset);
                // const new_offset_struct = @subWithOverflow(8, self.shift_offset);
                // const fields = @typeInfo(@TypeOf(new_offset_struct)).Struct.fields;
                // const res: u16 = @field(new_offset_struct, fields[0].name);
                const _new_a = ((v >> res) & 0xff);
                new_a = @truncate(_new_a);
            },
            else => {},
        }
        return new_a;
    }

    // out: fn (self: Machine, port: u8, value: *u8) void,
    pub fn machineOut(self: *Machine, port: u8, value: *u8) void {
        switch (port) {
            2 => {
                self.shift_offset = value.* & 0x7;
            },
            4 => {
                self.shift0 = self.shift1;
                self.shift1 = value.*;
            },
            else => {},
        }
    }

    // doCpu: fn (self: Machine) void,
    pub fn doCpu(self: *Machine) void {
        const now: i64 = std.time.milliTimestamp();

        if (self.last_timer == 0.0) {
            self.last_timer = now;
            self.next_interrupt = now + 16000;
            self.which_interrupt = 1;
        }

        if (self.state.int_enabled and now > self.next_interrupt) {
            if (self.which_interrupt == 1) {
                print("GenerateInterrupt 1\n", .{});
                // GenerateInterrupt(state, 1);
                self.which_interrupt = 2;
            } else {
                // GenerateInterrupt(state, 2);
                print("GenerateInterrupt 2\n", .{});
                self.which_interrupt = 1;
            }
            self.next_interrupt = now + 8000;
        }

        const since_last = now - self.last_timer;
        const cycles_to_catch_up = 2 * since_last;
        var cycles: u16 = 0;

        emulation_loop: while (cycles_to_catch_up > cycles) {
            const opcode = self.state.memory[self.state.pc];

            // IN
            if (opcode == 0xdb) {
                self.state.a = self.machineIn(self.state.memory[self.state.pc + 1]);
                self.state.pc += 2;
                cycles += 3;
                continue :emulation_loop;
                // OUT
            } else if (opcode == 0xd3) {
                self.machineOut(self.state.memory[self.state.pc + 1], &self.state.a);
                self.state.pc += 2;
                cycles += 3;
                continue :emulation_loop;
            } else {
                cycles += assembler.emulate8080Op(&self.state);
                // cycles += a.emulate8080Op(&self.state);
            }
        }
        self.last_timer = now;
    }
};

fn init() !State8080 {

    // INFO: Initialize the state of the 8080 CPU
    // I am purposefully being explicit here regarding the initial values
    //  being set to their hexadecimal equivalent for educational reasons
    var state: State8080 = State8080{
        .a = 0x00,
        .b = 0x00,
        .c = 0x00,
        .d = 0x00,
        .e = 0x00,
        .h = 0x00,
        .l = 0x00,
        .sp = 0x0000,
        .pc = 0x0000,
        .memory = [_]u8{0} ** m.MemorySize,
        .cc = m.ConditionCodes{ .z = false, .s = false, .p = false, .cy = false, .ac = false, .pad = 0 },
        .int_enabled = false,
    };

    try m.getRom(&state, "invaders.h", 0x0000);
    try m.getRom(&state, "invaders.g", 0x0800);
    try m.getRom(&state, "invaders.f", 0x1000);
    try m.getRom(&state, "invaders.e", 0x1800);

    return state;
}

pub fn initMachine() !Machine {
    // const state: State8080 = try m.initState8080();
    const state: State8080 = try init();

    const machine = Machine{
        .state = state,

        .last_timer = 0,
        .next_interrupt = 0,
        .which_interrupt = 0,

        .shift0 = 0,
        .shift1 = 0,
        .shift_offset = 0,
    };

    return machine;

    // return Machine{
    //     .state = state,
    //
    //     .last_timer = 0.0,
    //     .next_interrupt = 0,
    //     .which_interrupt = 0,
    //
    //     .shift0 = 0,
    //     .shift1 = 0,
    //     .shift_offset = 0,
    // };
}

// pub fn doCpu(self: Machine) void {
//     const now = std.time.milliTimestamp();
//
//     if (self.last_timer == 0.0) {
//         self.last_timer = now;
//         self.next_interrupt = now + 16000;
//         self.which_interrupt = 1;
//     }
//
//     if (self.state.int_enable and now > self.next_interrupt) {
//         if (self.which_interrupt == 1) {
//             print("GenerateInterrupt 1\n");
//             // GenerateInterrupt(state, 1);
//             self.which_interrupt = 2;
//         } else {
//             // GenerateInterrupt(state, 2);
//             print("GenerateInterrupt 2\n");
//             self.which_interrupt = 1;
//         }
//         self.which_interrupt = now + 8000.0;
//     }
//
//     const since_last = now - self.last_timer;
//     const cycles_to_catch_up = 2 * since_last;
//     var cycles = 0;
//
//     emulation_loop: while (cycles_to_catch_up > cycles) {
//         const opcode = self.state.memory[self.state.pc];
//
//         if (opcode == 0xdb) {
//             self.state.a = self.in(&self.state, self.state.memory[self.state.pc + 1]);
//             self.state.pc += 2;
//             cycles += 3;
//             continue :emulation_loop;
//         } else if (opcode == 0xd3) {
//             self.out(&self.state, self.state.memory[self.state.pc + 1], &self.state.a);
//             self.state.pc += 2;
//             cycles += 3;
//             continue :emulation_loop;
//         } else {
//             cycles += a.emulate8080Op(&self.state);
//         }
//     }
//     self.last_timer = now;
// }

// pub fn machineIn(self: Machine, port: u8) u8 {
//     var new_a: u8 = self.state.a;
//
//     switch (port) {
//         0 => {
//             return 1;
//         },
//         1 => {
//             return 0;
//         },
//         3 => {
//             const v: u16 = (@as(u16, self.shift1 << 8) | @as(u16, self.shift0));
//             const _new_a = ((v >> (8 - self.shift_offset)) & 0xff);
//             new_a = @truncate(_new_a);
//         },
//     }
//     return new_a;
// }

// pub fn machineOut(self: Machine, port: u8, value: *u8) void {
//     switch (port) {
//         2 => {
//             self.shift_offset = *value & 0x7;
//         },
//         4 => {
//             self.shift0 = self.shift1;
//             self.shift1 = *value;
//         },
//     }
// }

// pub fn timeusec() f64 {
//     var time: std.posix.system.timespec = undefined;
//     std.posix.clock_gettime(std.time.milliTimestamp, &time) catch |err| {
//         std.debug.print("Error getting time: {}\n", .{err});
//         return 0;
//     };
//     return @as(f64, @floatFromInt(time.tv_sec)) * 1e6 + @as(f64, @floatFromInt(time.tv_nsec)) / 1e3;
// }
