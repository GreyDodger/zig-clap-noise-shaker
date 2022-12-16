const std = @import("std");
const global = @import("global.zig");
const math = std.math;

pub inline fn amplitudeTodB(amplitude: f32) f32 {
    return 20.0 * math.log10(amplitude);
}

pub inline fn dBToAmplitude(dB: f32) f32 {
    return math.pow(f32, 10.0, dB / 20.0);
}

pub inline fn randAmplitudeValue() f32 {
    return global.rng.float(f32) * 2 - 1;
}

pub inline fn sawWave(on_sample: usize, wavelength: usize) f32 {
    return @intToFloat(f32, on_sample % wavelength) / @intToFloat(f32, wavelength - 1);
}

pub inline fn sawWaveBackwards(on_sample: usize, wavelength: usize) f32 {
    return @intToFloat(f32, (wavelength - 1) - (on_sample % wavelength)) / @intToFloat(f32, wavelength - 1);
}

pub inline fn envAD(on_sample: usize, length_a: usize, length_d: usize) f32 {
    if (on_sample < length_a) {
        return sawWave(on_sample, length_a);
    } else if (on_sample < (length_a + length_d)) {
        return sawWaveBackwards(on_sample - length_a, length_d);
    }
    return 0.0;
}
