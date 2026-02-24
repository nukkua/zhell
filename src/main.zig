// UNIX is very simple
// it just needs a genius to understand its simplicity
const std = @import("std");
const Io  = std.Io;

pub fn main(init: std.process.Init) !void {
    var reader_buffer: [1024]u8 = undefined;
    var reader = Io.File.stdin().reader(init.io, &reader_buffer);
    const stdin = &reader.interface;

    var writer_buffer: [1024]u8 = undefined;
    var writer = Io.File.stdout().writer(init.io, &writer_buffer);
    const stdout = &writer.interface;
    try get_prompt(init.arena.allocator(), init.io);

    while (true) {
        try stdout.print("> ", .{});
        try stdout.flush();

        const line = stdin.takeDelimiterInclusive('\n') catch |e| switch (e) {
            error.ReadFailed =>    continue,
            error.StreamTooLong => unreachable,
            error.EndOfStream => {
                try stdout.print("\nexit\n", .{});
                try stdout.flush();
                std.process.exit(0);
            },
        };
        var args = std.mem.splitScalar(u8, std.mem.trimEnd(u8, line, "\n"), ' ');
        _ = exec_input(line, init.io, stdout) catch |err| switch (err) {
            error.InvalidCommand => {
                const command = args.first();
                std.debug.print("zhell: Unknown Command: {s}\n", .{command});
            },
            error.TooManyArguments => {
                const command = args.first();
                std.debug.print("zhell: {s}: too many arguments\n", .{command});
            },
            error.PathRequired => std.debug.print("zhell: The Path is Required\n", .{}),
            error.DirNotFound => {
                const command = args.first();
                const first_parameter = args.next();
                std.debug.print("zhell: {s}: {?s}: No such file or directory\n", .{command, first_parameter});
            },
            else => unreachable,
        };
    }
}

const Commands = enum {
    cd,
    ls,
    echo,
    exit,
    pub fn parse(input: []const u8) !Commands {
        return std.meta.stringToEnum(Commands, input) orelse error.InvalidCommand;
    }
};


fn exec_input(line: []u8, io: Io, stdout: anytype) !void {
    std.mem.replaceScalar(u8, line, '\n', ' '); 
    var args = std.mem.splitScalar(u8, line, ' ');

    const command = try Commands.parse(args.first());

    switch (command) {
        .cd => try changeDirectory(&args, io),
        .ls => try list(&args, io),
        .echo => try last_words(&args, stdout),
        .exit => {
            std.debug.print("exit\n", .{});
            std.process.exit(0);
        },
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

    if (rc != 0) return error.DirNotFound; // c style errors
}



fn list(args: *std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar), io: std.Io) !void {
    if(std.mem.trimEnd(u8, args.rest(), " \n\t\r").len > 0) return error.TooManyArguments; // provisional cuz ls accepts the directory too
         
    
    var dir = try Io.Dir.cwd().openDir(io, ".", .{ .iterate = true});
    defer dir.close(io);

    var iter: Io.Dir.Iterator = dir.iterate();
    while (try iter.next(io)) |entry| {
        std.debug.print("{s}\n", .{entry.name});
    }
}


fn last_words(args: *std.mem.SplitIterator(u8, std.mem.DelimiterType.scalar), stdout: anytype) !void {
    const content = std.mem.trimEnd(u8, args.rest(), "\n\t\r");
    try stdout.print("{s}\n", .{content});
    try stdout.flush();
}

fn get_prompt(allocator: std.mem.Allocator, io: Io) !void {
    _ = allocator;
    _ = io;
}
