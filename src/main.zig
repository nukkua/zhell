// UNIX is very simple
// it just neds a genius to understand its simplicity
const std = @import("std");
const Io  = std.Io;

pub fn main(init: std.process.Init) !void {
    var reader_buffer: [1024]u8 = undefined;
    var reader = Io.File.stdin().reader(init.io, &reader_buffer);
    const stdin = &reader.interface;

    var writer_buffer: [1024]u8 = undefined;
    var writer = Io.File.stdout().writer(init.io, &writer_buffer);
    const stdout = &writer.interface;

    while (true) {
        try stdout.print("> ", .{});
        try stdout.flush();

        const line = stdin.takeDelimiterInclusive('\n') catch |e| switch (e) {
            error.ReadFailed => continue,
            error.StreamTooLong => unreachable,
            error.EndOfStream => unreachable,
        };
        _ = exec_input(line, init.io) catch |err| switch (err) {
            error.InvalidCommand => std.debug.print("Invalid Command\n", .{}),
            else => unreachable,
        };
    }
}

const Commands = enum {
    cd,
    ls,
    exit,
    pub fn parse(input: []const u8) !Commands {
        return std.meta.stringToEnum(Commands, input) orelse error.InvalidCommand;
    }
};


fn exec_input(line: []u8, io: Io) !void {
    _ = std.mem.replaceScalar(u8, line, '\n', ' '); // it modifies the slice
    var args = std.mem.splitScalar(u8, line, ' ');

    const command = try Commands.parse(args.first());

    switch (command) {
        .cd => try changeDirectory(&args, io),
        .ls => try list(&args, io),
        .exit => std.process.exit(0),
    }
}

fn changeDirectory(args: *std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar), io: Io) !void {
    _ = io;
    const path = args.next() orelse return error.PathRequired;
    const sub_path = std.mem.trimEnd(u8, path, " \n\r\t");
    if (sub_path.len == 0) return error.PathRequired;
    if (std.mem.trimEnd(u8, args.rest(), " \n\r\t").len > 0) return error.TooManyArguments;

    var buffer: [std.fs.max_path_bytes + 1]u8 = undefined;
    @memcpy(buffer[0..sub_path.len], sub_path);
    buffer[sub_path.len] = 0;
    const rc = std.os.linux.chdir(buffer[0..sub_path.len:0]);

    if (rc != 0) return error.ChdirFailed;
}



fn list(args: *std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar), io: std.Io) !void {
    _ = args;
    var dir = try Io.Dir.cwd().openDir(io, ".", .{ .iterate = true});
    defer dir.close(io);

    var iter: Io.Dir.Iterator = dir.iterate();
    while (try iter.next(io)) |entry| {
        std.debug.print("{s}\n", .{entry.name});
    }
}
