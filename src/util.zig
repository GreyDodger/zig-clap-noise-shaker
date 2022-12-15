const std = @import("std");
const main = @import("main.zig");
const math = std.math;

pub inline fn amplitudeTodB(amplitude: f32) f32 {
    return 20.0 * math.log10(amplitude);
}

pub inline fn dBToAmplitude(dB: f32) f32 {
    return math.pow(f32, 10.0, dB / 20.0);
}

pub inline fn randAmplitudeValue() f32 {
    return main.rng.float(f32) * 2 - 1;
}
