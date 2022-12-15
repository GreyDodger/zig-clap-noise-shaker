const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var allocator: std.mem.Allocator = undefined;

pub fn init() void {
    allocator = gpa.allocator();
}