// UNIX is very simple
// it just needs a genius to understand its simplicity
const std = @import("std");
const Io = std.Io;
const assert = std.debug.assert;


pub fn main(init: std.process.Init) !void {
    var reader_buffer: [1024]u8 = undefined;
    var reader = Io.File.stdin().reader(init.io, &reader_buffer);
    const stdin = &reader.interface;

    var writer_buffer: [1024]u8 = undefined;
    var writer = Io.File.stdout().writer(init.io, &writer_buffer);
    const stdout = &writer.interface;

    while (true) {
        const prompt = try get_prompt(init.arena.allocator(), init.io, init.minimal.environ);
        try stdout.print("{s} $ ", .{prompt});
        try stdout.flush();
        const line = stdin.takeDelimiterInclusive('\n') catch |e| switch (e) {
            error.ReadFailed => unreachable,
            error.StreamTooLong => unreachable,
            error.EndOfStream => {
                try stdout.print("\nexit\n", .{});
                try stdout.flush();
                std.process.exit(0);
            },
        };

        var args = std.mem.splitScalar(u8, std.mem.trimEnd(u8, line, "\n"), ' ');
        _ = exec_input(line, init.io, stdout, init.minimal.environ, init.arena.allocator()) catch |err| switch (err) {
            error.InvalidCommand => {
                const command = args.first();
                std.debug.print("zhell: Unknown Command: {s}\n", .{command});
            },
            error.TooManyArguments => {
                const command = args.first();
                std.debug.print("zhell: {s}: too many arguments\n", .{command});
            },
            error.PathRequired => std.debug.print("zhell: The Path is Required\n", .{}),
            error.FileNotFound => {
                const command = args.first();
                const first_parameter = args.next();
                std.debug.print("zhell: {s}: {?s}: No such file or directory\n", .{ command, first_parameter });
            },
            error.NotDir => {
                const command = args.first();
                const first_parameter = args.next();
                std.debug.print("zhell: {s}: {?s}: Not a directory\n", .{ command, first_parameter });
            },
            else => |err| {
                std.debug.print("Got other error: {}\n", .{err});
                unreachable;
            },
        };
    }
}

const Commands = enum {
    cd,
    ls,
    echo,
    clear,
    exit,
    pub fn parse(input: []const u8) !Commands {
        return std.meta.stringToEnum(Commands, input) orelse error.InvalidCommand;
    }
};

fn exec_input(line: []u8, io: Io, stdout: anytype, environ: std.process.Environ, allocator: std.mem.Allocator) !void {
    std.mem.replaceScalar(u8, line, '\n', ' ');
    var args = std.mem.splitScalar(u8, line, ' ');

    const command = try Commands.parse(args.first());

    switch (command) {
        .cd => try changeDirectory(&args, io, environ, allocator),
        .ls => try list(&args, io),
        .echo => try last_words(&args, stdout),
        .clear => try clear_screen(&args, stdout),
        .exit => {
            std.debug.print("exit\n", .{});
            std.process.exit(0);
        },
    }
}

fn changeDirectory(args: *std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar), io: Io, environ: std.process.Environ, allocator: std.mem.Allocator) !void {
    const path = args.next() orelse return error.PathRequired;
    if (std.mem.trimEnd(u8, args.rest(), " \n\r\t").len > 0) return error.TooManyArguments;

    const sub_path = std.mem.trimEnd(u8, path, " \n\r\t");

    if (sub_path.len == 0) {
        const home = try environ.getAlloc(allocator, "HOME");
        const dir = try Io.Dir.openDirAbsolute(io, home, .{});
        try std.process.setCurrentDir(io, dir);
        return;
    }
    assert(sub_path.len > 0);

    const dir = try Io.Dir.cwd().openDir(io, sub_path, .{});
    defer dir.close(io);
    try std.process.setCurrentDir(io, dir);
}

fn list(args: *std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar), io: std.Io) !void {
    const next_dir = args.next() orelse return error.PathRequired;
    const next_dir_trimmed = std.mem.trimEnd(u8, next_dir, " \n\r\t");
    const path = if (next_dir_trimmed.len > 0) next_dir_trimmed else ".";

    assert(path.len > 0);

    var dir = try Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
    defer dir.close(io);

    var iter: Io.Dir.Iterator = dir.iterate();
    while (try iter.next(io)) |entry| {
        std.debug.print("{s}\n", .{entry.name});
    }
}

fn last_words(args: *std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar), stdout: anytype) !void {
    const prevContent = args.next() orelse return error.InvalidCommand;
    const content = std.mem.trimEnd(u8, prevContent, "\n\t\r");

    if (content.len == 0) {
        try stdout.print("\n", .{});
        try stdout.flush();
    }
    if (args.rest().len > 0) return error.TooManyArguments;

    try stdout.print("{s}\n", .{content});
    try stdout.flush();
}

fn clear_screen(args: *std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar), stdout: anytype) !void {
    _ = args;
    try stdout.print("\x1B[2J\x1B[H", .{});
}

fn get_prompt(allocator: std.mem.Allocator, io: Io, environ: std.process.Environ) ![]const u8 {
    const home = try environ.getAlloc(allocator, "HOME");
    assert(home.len > 0);

    const full_path = try std.process.currentPathAlloc(io, allocator);

    if (std.mem.startsWith(u8, full_path, home)) return std.mem.cut(u8, full_path, home).?.@"1";
    assert(full_path.len > 0);

    
    
    return full_path;
}
