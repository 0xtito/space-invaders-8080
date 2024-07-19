const std = @import("std");
const print = std.debug.print;

const d = @import("disassembler.zig");

pub const RomData = [256]u8;
pub const RomContent = struct { data: RomData, len: usize };

pub const ConditionCodes = struct { z: bool, s: bool, p: bool, cy: bool, ac: bool, pad: u3 };

pub const State8080 = struct { a: u8, b: u8, c: u8, d: u8, e: u8, h: u8, l: u8, sp: u16, pc: u16, memory: *u8, cc: ConditionCodes, int_enabled: u8 };

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    const rom = getRom() catch |err| {
        return err;
    };

    const rom_ptr: *const RomData = &rom.data;

    // print_rom_data(rom_ptr);

    var pc: u16 = 0;
    // while (pc < rom.len) {
    while (pc < rom.len) {
        pc += try d.deassemblerP(rom_ptr, pc);
        // if (pc == 3) break;
    }

    try bw.flush(); // don't forget to flush!
}

pub fn getRom() !RomContent {
    // Get the current working directory
    const cwd = std.fs.cwd();

    var output_dir = try cwd.openDir("src/roms", .{});
    defer output_dir.close();

    const file = try output_dir.openFile("invaders.concatenated", .{});
    // const file = try output_dir.openFile("invaders.h", .{});
    // const file = try output_dir.openFile("invaders.g", .{});
    defer file.close();

    const rom = blk: {
        var temp: RomData = undefined;
        const bytes_read = try file.readAll(&temp);
        if (bytes_read < temp.len) {
            return error.NotEnoughData;
        }
        print("Successfully read {d} bytes from the file.\n", .{bytes_read});

        break :blk RomContent{ .data = temp, .len = bytes_read };
    };

    return rom;
}

fn printRomData(data: *const RomContent) void {
    for (data[0..128]) |byte| {
        print("{x:0>2} ", .{byte});
    }
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
