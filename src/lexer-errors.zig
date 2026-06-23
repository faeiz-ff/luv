const std = @import("std");

const Errors = @import("errors.zig").Errors;

pub const LexerError = struct {
    pub fn unterminatedString(
        errors: *Errors,
        filename: ?[]const u8,
        x_pos: usize,
        y_pos: usize,
        code: []const u8,
    ) void {
        errors.report(
            "unterminated string",
            "This string is unterminated",
            filename,
            x_pos,
            y_pos,
            code,
        );
    }

    pub fn unknownOperator(
        errors: *Errors,
        filename: ?[]const u8,
        x_pos: usize,
        y_pos: usize,
        code: []const u8,
    ) void {
        errors.report(
            "unknown operator",
            "This operator is unknown",
            filename,
            x_pos,
            y_pos,
            code,
        );
    }
};

test "basic functionality" {
    const t = std.testing;
    var err = Errors{
        .count = 0,
        .capture = try .initCapacity(std.testing.allocator, 32),
    };
    defer err.capture.?.deinit(t.allocator);

    const code =
        \\def Pi = 3.14
        \\var x = "Hello World!
        \\print(x)
    ;

    LexerError.unterminatedString(&err, null, 8, 1, code);

    const expected =
        "error (2:8): unterminated string:\n" ++
        "\tvar x = \"Hello World!\n" ++
        "\t        ^ This string is unterminated\n";

    try t.expectEqualStrings(expected, err.capture.?.items);
}
