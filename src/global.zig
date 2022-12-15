const std = @import("std");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var allocator: std.mem.Allocator = undefined;

var prng = std.rand.DefaultPrng.init(0);
pub var rng: std.rand.Random = undefined;

pub fn init() void {
    allocator = gpa.allocator();
    rng = prng.random();
}
