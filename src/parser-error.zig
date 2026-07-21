const std = @import("std");
const luv = @import("luv");

pub const ParserErrorReport = struct {
    code: []const u8,
    reporter: luv.ErrorReport,
    const Self = @This();

    pub fn init(code: []const u8, writer: *std.Io.Writer) ParserErrorReport {
        return .{
            .code = code,
            .reporter = .init(writer),
        };
    }

    pub fn errorUnexpectedToken(self: *Self, pos: luv.Position, errMsg: []const u8) !void {
        try self.reporter
            .report(.Err, "Unexpected Token")
            .withLineMsg(self.code, pos, errMsg)
            .flush();
    }

    pub fn errorFunVariadicUnclosed(self: *Self, current_pos: luv.Position, variadic_pos: luv.Position) !void {
        try self.reporter
            .report(.Err, "Unexpected Token")
            .withLineMsg(
                self.code,
                current_pos,
                "Expecting a right parentheses for closing function type after variadic marker",
            )
            .withLineMsg(self.code, variadic_pos, "The variadic is defined here")
            .flush();
    }

    pub fn warnRedundantToken(
        self: *Self,
        redundant_pos: luv.Position,
        comptime errMsg: []const u8,
    ) !void {
        try self.reporter
            .report(.Warn, "Redundant syntax")
            .withLineMsg(self.code, redundant_pos, errMsg ++ "; delete this token")
            .flush();
    }

    pub fn errorIllegalChainUseGrouping(self: *Self, comptime something: []const u8, pos: luv.Position) !void {
        try self.reporter
            .report(.Err, "Illegal Chain of " ++ something)
            .withLineMsg(self.code, pos, "use explicit grouping parentheses for this")
            .flush();
    }

    pub fn errorEmptyGeneric(
        self: *Self,
        pos: luv.Position,
    ) !void {
        try self.reporter
            .report(.Err, "Invalid Empty Generic")
            .withLineMsg(self.code, pos, "This generic is empty, delete these token")
            .flush();
    }

    pub fn errorExpectedSomeRule(self: *Self, pos: luv.Position, comptime rule: []const u8) !void {
        try self.reporter
            .report(.Err, rule ++ " Not Found")
            .withLineMsg(self.code, pos, "Expecting " ++ rule ++ " rule here")
            .flush();
    }

    pub fn errorTupleDestructure(self: *Self, pos: luv.Position, comptime in: []const u8) !void {
        try self.reporter
            .report(.Err, "Invalid Syntax")
            .withLineMsg(self.code, pos, "Tuple destructure is not allowed in " ++ in)
            .flush();
    }

    pub fn errorUnreachableReturn(self: *Self, ret_pos: luv.Position, pos: luv.Position) !void {
        try self.reporter
            .report(.Err, "Unreachable Code")
            .withLineMsg(self.code, pos, "Returning statement must be followed by closing curly bracket")
            .withLineMsg(self.code, ret_pos, "Returning statement must be the last statement in a block")
            .flush();
    }

    pub fn errorModDeclNotOnTop(self: *Self, pos: luv.Position) !void {
        try self.reporter
            .report(.Err, "Module Declaration not on top")
            .withLineMsg(self.code, pos, "This module declaration must be the on top of the file")
            .flush();
    }
};
