const builtin = @import("builtin");

pub const c = @cImport({
    @cInclude("clap/clap.h");
    @cInclude("string.h");
    if (builtin.os.tag == .windows) {
        @cInclude("windows.c");
    }
});

const std = @import("std");
const ArrayList = std.ArrayList;
const util = @import("util.zig");
const c_cast = std.zig.c_translation.cast;
const global = @import("global.zig");

pub const Params = struct {
    const Values = struct {
        stereo: f64 = 1.0,
        gain_amplitude_main: f64 = 0.5,
        length_a: f64 = 0.0,
        length_d_beat_1: f64 = 150.0,
        length_d_beat_2: f64 = 100.0,
        length_d_beat_3: f64 = 50.0,
        length_d_beat_4: f64 = 100.0,
        gain_amplitude_beat_1: f64 = 1.0,
        gain_amplitude_beat_2: f64 = 0.8,
        gain_amplitude_beat_3: f64 = 0.6,
        gain_amplitude_beat_4: f64 = 0.4,
        swing: f64 = 0.0,
    };

    values: Values = Values{},

    const ValueMeta = struct {
        id: u32,
        name: []const u8 = &[_]u8{},
        t: ValueType = .VolumeAmp,
        min_value: f64 = 0.0,
        max_value: f64 = 1.0,
    };
    const ValueType = enum {
        Bool,
        VolumeAmp,
        VolumeDB,
        TimeSamples,
        TimeMilliseconds,
        TVal,
    };

    const value_metas = [std.meta.fields(Values).len]ValueMeta{
        .{ .id = 0x5da004c1, .name = "Stereo", .t = .Bool },
        .{ .id = 0xe100e598, .name = "Volume" },
        .{ .id = 0xa898f74a, .name = "Shaker Env: Attack", .t = .TimeMilliseconds, .min_value = 0.0, .max_value = 100 },
        .{ .id = 0x52a6f72d, .name = "Shaker Env: Delay (beat 1)", .t = .TimeMilliseconds, .min_value = 0.0, .max_value = 500 },
        .{ .id = 0x546487f1, .name = "Shaker Env: Delay (beat 2)", .t = .TimeMilliseconds, .min_value = 0.0, .max_value = 500 },
        .{ .id = 0x9ff538eb, .name = "Shaker Env: Delay (beat 3)", .t = .TimeMilliseconds, .min_value = 0.0, .max_value = 500 },
        .{ .id = 0x6f11886a, .name = "Shaker Env: Delay (beat 4)", .t = .TimeMilliseconds, .min_value = 0.0, .max_value = 500 },
        .{ .id = 0x5935e90a, .name = "% Volume Beat 1" },
        .{ .id = 0x3c2799cb, .name = "% Volume Beat 2" },
        .{ .id = 0x154b3694, .name = "% Volume Beat 3" },
        .{ .id = 0x3cf7df5f, .name = "% Volume Beat 4" },
        .{ .id = 0xe1d8f811, .name = "Swing", .t = .TVal },
    };

    comptime {
        var i: usize = 0;
        while (i < value_metas.len) : (i += 1) {
            var j = i + 1;
            while (j < value_metas.len) : (j += 1) {
                if (value_metas[i].id == value_metas[j].id) {
                    @compileLog("Repeating IDs ", i, j);
                }
            }
        }
    }

    fn idToValueIndex(id: u32) !usize {
        const fields = std.meta.fields(Values);
        inline for (fields) |_, field_index| {
            if (value_metas[field_index].id == id) {
                return field_index;
            }
        }
        return error.CantFindValue;
    }
    fn idToValue(self: Params, id: u32) !f64 {
        const fields = std.meta.fields(Values);
        inline for (fields) |field, field_index| {
            if (value_metas[field_index].id == id) {
                return @field(self.values, field.name);
            }
        }
        return error.CantFindValue;
    }
    fn idToValuePtr(self: *Params, id: u32) !*f64 {
        const fields = std.meta.fields(Values);
        inline for (fields) |field, field_index| {
            if (value_metas[field_index].id == id) {
                return &@field(self.values, field.name);
            }
        }
        return error.CantFindValue;
    }

    fn count(plugin: [*c]const c.clap_plugin_t) callconv(.C) u32 {
        _ = plugin;
        return std.meta.fields(Values).len;
    }

    fn get_info(plugin: [*c]const c.clap_plugin_t, index: u32, info: [*c]c.clap_param_info_t) callconv(.C) bool {
        _ = plugin;
        const fields = std.meta.fields(Values);
        switch (index) {
            inline 0...(fields.len - 1) => |comptime_index| {
                const field = fields[comptime_index];
                var flags: u32 = if (value_metas[index].t == .Bool) c.CLAP_PARAM_IS_STEPPED else 0;
                flags |= c.CLAP_PARAM_IS_AUTOMATABLE;
                info.* = .{
                    .id = value_metas[index].id,
                    .name = undefined,
                    .module = undefined,
                    .min_value = value_metas[index].min_value,
                    .max_value = value_metas[index].max_value,
                    .default_value = @ptrCast(*const f64, @alignCast(@alignOf(field.field_type), field.default_value.?)).*,
                    .flags = flags,
                    .cookie = null,
                };
                if (value_metas[index].name.len > 0) {
                    _ = std.fmt.bufPrintZ(&info.*.name, "{s}", .{value_metas[index].name}) catch unreachable;
                } else {
                    _ = std.fmt.bufPrintZ(&info.*.name, field.name, .{}) catch unreachable;
                }
                _ = std.fmt.bufPrintZ(&info.*.module, "params/" ++ field.name, .{}) catch unreachable;
            },
            else => {},
        }
        return true;
    }
    fn get_value(plugin: [*c]const c.clap_plugin_t, id: c.clap_id, out: [*c]f64) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        out.* = plug.params.idToValue(id) catch {
            return false;
        };
        return true;
    }
    fn value_to_text(plugin: [*c]const c.clap_plugin_t, id: c.clap_id, value: f64, buf_ptr: [*c]u8, buf_size: u32) callconv(.C) bool {
        _ = plugin;
        var buf: []u8 = buf_ptr[0..buf_size];
        var index = idToValueIndex(id) catch {
            return false;
        };
        switch (value_metas[index].t) {
            .Bool => {
                _ = std.fmt.bufPrintZ(buf, "{s}", .{if (value == 0.0) "false" else "true"}) catch unreachable;
            },
            .VolumeAmp => {
                const display = util.amplitudeTodB(@floatCast(f32, value));
                _ = std.fmt.bufPrintZ(buf, "{d:.4} dB", .{display}) catch unreachable;
            },
            .TimeMilliseconds => {
                _ = std.fmt.bufPrintZ(buf, "{d:.4} ms", .{value}) catch unreachable;
            },
            else => {
                _ = std.fmt.bufPrintZ(buf, "{d:.4}", .{value}) catch unreachable;
            },
        }
        return true;
    }
    fn text_to_value(plugin: [*c]const c.clap_plugin_t, id: c.clap_id, display: [*c]const u8, out: [*c]f64) callconv(.C) bool {
        _ = plugin;
        var index = idToValueIndex(id) catch {
            return false;
        };
        switch (value_metas[index].t) {
            .Bool => {
                const str: []const u8 = std.mem.span(display);
                out.* = if (std.mem.eql(u8, str, "true")) 1.0 else 0.0;
            },
            .VolumeAmp => {
                const str: []const u8 = blk: {
                    var str: []const u8 = std.mem.span(display);
                    str.len = for (str) |char, char_index| {
                        if (char == ' ') {
                            break char_index;
                        }
                    } else new_len: {
                        break :new_len str.len;
                    };
                    break :blk str;
                };
                out.* = util.dBToAmplitude(std.fmt.parseFloat(f32, str) catch @panic("parse float"));
            },
            else => {
                const str: []const u8 = blk: {
                    var str: []const u8 = std.mem.span(display);
                    str.len = for (str) |char, char_index| {
                        if (char == ' ') {
                            break char_index;
                        }
                    } else new_len: {
                        break :new_len str.len;
                    };
                    break :blk str;
                };
                out.* = std.fmt.parseFloat(f32, str) catch @panic("parse float");
            },
        }
        return true;
    }
    fn flush(plugin: [*c]const c.clap_plugin_t, in: [*c]const c.clap_input_events_t, out: [*c]const c.clap_output_events_t) callconv(.C) void {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        var event_index: u32 = 0;
        const num_events = in.*.size.?(in);
        while (event_index < num_events) : (event_index += 1) {
            const event_header = in.*.get.?(in, event_index);
            plug.do_process_event(event_header, out);
        }
    }

    const Data = c.clap_plugin_params_t{
        .count = count,
        .get_info = get_info,
        .get_value = get_value,
        .value_to_text = value_to_text,
        .text_to_value = text_to_value,
        .flush = flush,
    };

    fn write(stream: *const c.clap_ostream_t, value: anytype) !void {
        if (stream.*.write.?(stream, &value, @sizeOf(@TypeOf(value))) != @sizeOf(@TypeOf(value))) {
            return error.WriteError;
        }
    }
    fn read(stream: *const c.clap_istream_t, comptime T: type) !T {
        var result: T = undefined;
        if (stream.*.read.?(stream, &result, @sizeOf(T)) != @sizeOf(T)) {
            return error.ReadError;
        }
        return result;
    }
    fn writeAll(self: Params, stream: *const c.clap_ostream_t) !void {
        const fields = std.meta.fields(Values);
        try write(stream, fields.len);
        inline for (fields) |field, field_index| {
            try write(stream, Params.value_metas[field_index].id);
            try write(stream, @field(self.values, field.name));
        }
    }
    fn readAll(self: *Params, stream: *const c.clap_istream_t) !void {
        const fields = std.meta.fields(Values);
        const num_values = try read(stream, usize);
        var i: usize = 0;
        while (i < num_values) : (i += 1) {
            const id = try read(stream, u32);
            inline for (value_metas) |meta, meta_index| {
                if (id == meta.id) {
                    @field(self.values, fields[meta_index].name) = try read(stream, f64);
                    break;
                }
            } else {
                // discard value
                _ = try read(stream, f64);
            }
        }
    }

    pub fn setValue(self: *Params, param_id: u32, value: f64) void {
        (self.idToValuePtr(param_id) catch {
            return;
        }).* = value;
    }
    pub fn setValueTellHost(self: *Params, comptime field_name: []const u8, value: f64, time: u32, out_events: *const c.clap_output_events_t) void {
        const param_id = Params.value_metas[@intCast(u32, std.meta.fieldIndex(Params.Values, field_name).?)].id;

        self.setValue(param_id, value);

        var e = c.clap_event_param_value_t{
            .header = .{
                .size = @sizeOf(c.clap_event_param_value_t),
                .space_id = c.CLAP_CORE_EVENT_SPACE_ID,
                .type = c.CLAP_EVENT_PARAM_VALUE,
                .flags = 0,
                .time = time,
            },

            .param_id = param_id,
            .cookie = null,

            .note_id = 0,
            .port_index = 0,
            .channel = 0,
            .key = 0,

            .value = value,
        };

        _ = out_events.*.try_push.?(out_events, &e.header);
    }
};

const NotePorts = struct {
    fn count(plugin: [*c]const c.clap_plugin_t, is_input: bool) callconv(.C) u32 {
        _ = plugin;
        _ = is_input;
        return 1;
    }

    fn get(plugin: [*c]const c.clap_plugin_t, index: u32, is_input: bool, info: [*c]c.clap_note_port_info_t) callconv(.C) bool {
        _ = plugin;
        _ = is_input;
        switch (index) {
            0 => {
                info.* = .{
                    .id = 0,
                    .name = undefined,
                    .supported_dialects = c.CLAP_NOTE_DIALECT_MIDI,
                    .preferred_dialect = c.CLAP_NOTE_DIALECT_MIDI,
                };
                _ = std.fmt.bufPrint(&info.*.name, "Audio Port", .{}) catch unreachable;
            },
            else => {},
        }
        return true;
    }

    const Data = c.clap_plugin_note_ports_t{
        .count = count,
        .get = get,
    };
};

const AudioPorts = struct {
    fn count(plugin: [*c]const c.clap_plugin_t, is_input: bool) callconv(.C) u32 {
        _ = plugin;
        _ = is_input;
        return 1;
    }

    fn get(plugin: [*c]const c.clap_plugin_t, index: u32, is_input: bool, info: [*c]c.clap_audio_port_info_t) callconv(.C) bool {
        _ = plugin;
        _ = is_input;
        switch (index) {
            0 => {
                info.* = .{
                    .id = 0,
                    .name = undefined,
                    .channel_count = 2,
                    .flags = c.CLAP_AUDIO_PORT_IS_MAIN,
                    .port_type = &c.CLAP_PORT_STEREO,
                    .in_place_pair = c.CLAP_INVALID_ID,
                };

                _ = std.fmt.bufPrint(&info.*.name, "Audio Port", .{}) catch unreachable;
            },
            else => {},
        }
        return true;
    }

    const Data = c.clap_plugin_audio_ports_t{
        .count = count,
        .get = get,
    };
};

const Latency = struct {
    fn get(plugin: [*c]const c.clap_plugin_t) callconv(.C) u32 {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        return plug.*.latency;
    }

    const Data = c.clap_plugin_latency_t{
        .get = get,
    };
};

const State = struct {
    fn save(plugin: [*c]const c.clap_plugin_t, stream: [*c]const c.clap_ostream_t) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        plug.params.writeAll(stream) catch {
            return false;
        };
        return true;
    }

    fn load(plugin: [*c]const c.clap_plugin_t, stream: [*c]const c.clap_istream_t) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        plug.params.readAll(stream) catch {
            return false;
        };
        return true;
    }

    const Data = c.clap_plugin_state_t{
        .save = save,
        .load = load,
    };
};

pub const MyPlugin = struct {
    plugin: c.clap_plugin_t,
    latency: u32,
    sample_rate: f64 = 44100, // will be overwritten, just don't want this to ever be 0
    tempo: f64 = 120, // (bpm) will be overwritten, just don't want this to ever be 0
    host: [*c]const c.clap_host_t,
    hostParams: [*c]const c.clap_host_params_t,
    hostLog: ?*const c.clap_host_log_t,
    hostLatency: [*c]const c.clap_host_latency_t,
    hostThreadCheck: [*c]const c.clap_host_thread_check_t,
    params: Params = Params{},

    prev_sample: [2]f32 = [2]f32{
        0.0,
        0.0,
    },
    on_sample: usize = 0,
    play: bool = false,
    block_sample_start: usize = 0,
    on_block_sample: usize = 0,

    const desc = c.clap_plugin_descriptor_t{
        .clap_version = c.clap_version_t{ .major = c.CLAP_VERSION_MAJOR, .minor = c.CLAP_VERSION_MINOR, .revision = c.CLAP_VERSION_REVISION },
        .id = "michael-flaherty.Noise-Shaker",
        .name = "Noise Shaker",
        .vendor = "Michael Flaherty",
        .url = "https://your-domain.com/your-plugin",
        .manual_url = "https://your-domain.com/your-plugin/manual",
        .support_url = "https://your-domain.com/support",
        .version = "0.0.1",
        .description = "shaker with white noise",
        .features = &[_][*c]const u8{
            c.CLAP_PLUGIN_FEATURE_INSTRUMENT,
            c.CLAP_PLUGIN_FEATURE_STEREO,
            null,
        },
    };

    fn init(plugin: [*c]const c.clap_plugin_t) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);

        // Fetch host's extensions here
        {
            var ptr = plug.*.host.*.get_extension.?(plug.*.host, &c.CLAP_EXT_LOG);
            if (ptr != null) {
                plug.*.hostLog = c_cast(*const c.clap_host_log_t, ptr);
            }
        }
        {
            var ptr = plug.*.host.*.get_extension.?(plug.*.host, &c.CLAP_EXT_THREAD_CHECK);
            if (ptr != null) {
                plug.*.hostThreadCheck = c_cast(*const c.clap_host_thread_check_t, ptr);
            }
        }
        {
            var ptr = plug.*.host.*.get_extension.?(plug.*.host, &c.CLAP_EXT_LATENCY);
            if (ptr != null) {
                plug.*.hostLatency = c_cast(*const c.clap_host_latency_t, ptr);
            }
        }
        {
            var ptr = plug.*.host.*.get_extension.?(plug.*.host, &c.CLAP_EXT_PARAMS);
            if (ptr != null) {
                plug.*.hostParams = c_cast(*const c.clap_host_params_t, ptr);
            }
        }

        return true;
    }

    fn destroy(plugin: [*c]const c.clap_plugin_t) callconv(.C) void {
        global.allocator.destroy(c_cast(*MyPlugin, plugin.*.plugin_data));
    }

    fn activate(plugin: [*c]const c.clap_plugin_t, sample_rate: f64, min_frames_count: u32, max_frames_count: u32) callconv(.C) bool {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);
        plug.sample_rate = sample_rate;
        _ = min_frames_count;
        _ = max_frames_count;
        return true;
    }

    fn deactivate(plugin: [*c]const c.clap_plugin_t) callconv(.C) void {
        _ = plugin;
    }

    fn start_processing(plugin: [*c]const c.clap_plugin_t) callconv(.C) bool {
        _ = plugin;
        return true;
    }

    fn stop_processing(plugin: [*c]const c.clap_plugin_t) callconv(.C) void {
        _ = plugin;
    }

    fn reset(plugin: [*c]const c.clap_plugin_t) callconv(.C) void {
        _ = plugin;
    }
    fn on_main_thread(plugin: [*c]const c.clap_plugin_t) callconv(.C) void {
        _ = plugin;
    }

    fn get_extension(plugin: [*c]const c.clap_plugin_t, id: [*c]const u8) callconv(.C) ?*const anyopaque {
        _ = plugin;
        if (c.strcmp(id, &c.CLAP_EXT_LATENCY) == 0)
            return &Latency.Data;
        if (c.strcmp(id, &c.CLAP_EXT_AUDIO_PORTS) == 0)
            return &AudioPorts.Data;
        if (c.strcmp(id, &c.CLAP_EXT_NOTE_PORTS) == 0)
            return &NotePorts.Data;
        if (c.strcmp(id, &c.CLAP_EXT_PARAMS) == 0)
            return &Params.Data;
        if (c.strcmp(id, &c.CLAP_EXT_STATE) == 0)
            return &State.Data;
        return null;
    }

    fn create(host: [*c]const c.clap_host_t) [*c]c.clap_plugin_t {
        var p = global.allocator.create(MyPlugin) catch unreachable;
        p.* = .{
            .plugin = .{
                .desc = &desc,
                .plugin_data = p,
                .init = init,
                .destroy = destroy,
                .activate = activate,
                .deactivate = deactivate,
                .start_processing = start_processing,
                .stop_processing = stop_processing,
                .reset = reset,
                .process = do_process,
                .get_extension = get_extension,
                .on_main_thread = on_main_thread,
            },
            .host = host,
            .hostParams = null,
            .hostLatency = null,
            .hostLog = null,
            .hostThreadCheck = null,
            .latency = 0,
        };
        // Don't call into the host here
        return &p.plugin;
    }

    fn do_process(plugin: [*c]const c.clap_plugin_t, process: [*c]const c.clap_process_t) callconv(.C) c.clap_process_status {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);

        plug.tempo = process.*.transport.*.tempo;

        const pos_seconds = @intToFloat(f64, process.*.transport.*.song_pos_seconds) / @intToFloat(f64, @as(i64, 1 << 31));
        plug.block_sample_start = @floatToInt(usize, std.math.round(pos_seconds * plug.sample_rate));
        plug.on_block_sample = 0;

        const num_frames = process.*.frames_count;
        const num_events = process.*.in_events.*.size.?(process.*.in_events);

        var frame_index: u32 = 0;
        var event_index: u32 = 0;
        var next_event_frame: u32 = if (num_events > 0) @as(u32, 0) else num_frames;

        while (frame_index < num_frames) {
            handle_events: while (event_index < num_events and frame_index == next_event_frame) {
                const event_header = process.*.in_events.*.get.?(process.*.in_events, event_index);

                if (event_header.*.time != frame_index) {
                    next_event_frame = event_header.*.time;
                    break :handle_events;
                }

                do_process_event(plug, event_header, process.*.out_events);
                event_index += 1;

                if (event_index == num_events) {
                    next_event_frame = num_frames;
                }
            }

            const gain_main = @floatCast(f32, plug.params.values.gain_amplitude_main);

            const loop_sample_length = @floatToInt(usize, std.math.round(plug.sample_rate * 60.0 / plug.tempo));
            const loop_sample_length_quarter = loop_sample_length / 4;
            const beat_on_sample_length = loop_sample_length_quarter + @floatToInt(usize, @intToFloat(f64, loop_sample_length_quarter / 2) * plug.params.values.swing);
            const beat_off_sample_length = (loop_sample_length_quarter * 2) - beat_on_sample_length;

            const length_a = @floatToInt(usize, std.math.round((plug.params.values.length_a / 1000.0) * plug.sample_rate));
            const length_d_1 = @floatToInt(usize, std.math.round((plug.params.values.length_d_beat_1 / 1000.0) * plug.sample_rate));
            const length_d_2 = @floatToInt(usize, std.math.round((plug.params.values.length_d_beat_2 / 1000.0) * plug.sample_rate));
            const length_d_3 = @floatToInt(usize, std.math.round((plug.params.values.length_d_beat_3 / 1000.0) * plug.sample_rate));
            const length_d_4 = @floatToInt(usize, std.math.round((plug.params.values.length_d_beat_4 / 1000.0) * plug.sample_rate));

            while (frame_index < next_event_frame) : (frame_index += 1) {
                if (plug.play) {
                    const beat: struct { sample: usize, num: usize } = get_beat: {
                        var sample = plug.on_sample % loop_sample_length;
                        var sample_length: usize = 0;
                        if (sample < sample_length + beat_on_sample_length) {
                            break :get_beat .{ .sample = sample, .num = 0 };
                        }
                        sample_length += beat_on_sample_length;
                        if (sample < sample_length + beat_off_sample_length) {
                            break :get_beat .{ .sample = sample - sample_length, .num = 1 };
                        }
                        sample_length += beat_off_sample_length;
                        if (sample < sample_length + beat_on_sample_length) {
                            break :get_beat .{ .sample = sample - sample_length, .num = 2 };
                        }
                        sample_length += beat_on_sample_length;
                        break :get_beat .{ .sample = sample - sample_length, .num = 3 };
                    };

                    const saw = util.envAD(beat.sample, length_a, switch (beat.num) {
                        0 => length_d_1,
                        1 => length_d_2,
                        2 => length_d_3,
                        3 => length_d_4,
                        else => unreachable,
                    });
                    const gain_beat = switch (beat.num) {
                        0 => @floatCast(f32, plug.params.values.gain_amplitude_beat_1),
                        1 => @floatCast(f32, plug.params.values.gain_amplitude_beat_2),
                        2 => @floatCast(f32, plug.params.values.gain_amplitude_beat_3),
                        3 => @floatCast(f32, plug.params.values.gain_amplitude_beat_4),
                        else => unreachable,
                    };

                    const out_0 = util.randAmplitudeValue() * gain_main * gain_beat * saw;
                    const out_1 = if (plug.params.values.stereo == 0.0) out_0 else util.randAmplitudeValue() * gain_main * gain_beat * saw;

                    const out = [2]f32{
                        out_0,
                        out_1,
                    };

                    process.*.audio_outputs[0].data32[0][frame_index] = out[0];
                    process.*.audio_outputs[0].data32[1][frame_index] = out[1];

                    plug.on_sample += 1;
                    plug.prev_sample = out;
                }

                plug.on_block_sample += 1;
            }
        }

        return c.CLAP_PROCESS_SLEEP;
    }

    fn do_process_event(plug: *MyPlugin, hdr: [*c]const c.clap_event_header_t, out_events: *const c.clap_output_events_t) void {
        if (hdr.*.space_id == c.CLAP_CORE_EVENT_SPACE_ID) {
            switch (hdr.*.type) {
                c.CLAP_EVENT_PARAM_VALUE => {
                    const ev = c_cast([*c]const c.clap_event_param_value_t, hdr);
                    plug.params.setValue(ev.*.param_id, ev.*.value);
                },
                c.CLAP_EVENT_TRANSPORT => {
                    const ev = c_cast([*c]const c.clap_event_transport_t, hdr);
                    plug.tempo = ev.*.tempo;
                },
                c.CLAP_EVENT_MIDI => {
                    const ev = c_cast([*c]const c.clap_event_midi_t, hdr);
                    switch (ev.*.data[0]) {
                        0x90 => { // Note On
                            const velocity = ev.*.data[2];
                            if (velocity == 0) {
                                plug.play = false;
                            } else {
                                plug.play = true;
                                plug.on_sample = plug.block_sample_start + plug.on_block_sample;
                            }
                        },
                        0x80 => { // Note Off
                            plug.play = false;
                        },
                        176 => { // CC
                            if (ev.*.data[1] == 1) {
                                const value = @intToFloat(f32, ev.*.data[2]) / 127.0;
                                plug.params.setValueTellHost("gain_amplitude_main", value, hdr.*.time, out_events);
                            }
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }
    }
};

const Factory = struct {
    fn get_plugin_count(factory: [*c]const c.clap_plugin_factory_t) callconv(.C) u32 {
        _ = factory;
        return 1;
    }
    fn get_plugin_descriptor(factory: [*c]const c.clap_plugin_factory_t, index: u32) callconv(.C) [*c]const c.clap_plugin_descriptor_t {
        _ = factory;
        _ = index;
        return &MyPlugin.desc;
    }
    fn create_plugin(factory: [*c]const c.clap_plugin_factory_t, host: [*c]const c.clap_host_t, plugin_id: [*c]const u8) callconv(.C) [*c]const c.clap_plugin_t {
        _ = factory;
        if (!clap_version_is_compatible(host.*.clap_version)) {
            return null;
        }
        if (std.cstr.cmp(plugin_id, MyPlugin.desc.id) == 0) {
            return MyPlugin.create(host);
        }
        return null;
    }
    const Data = c.clap_plugin_factory_t{
        .get_plugin_count = Factory.get_plugin_count,
        .get_plugin_descriptor = Factory.get_plugin_descriptor,
        .create_plugin = Factory.create_plugin,
    };
};

pub fn clap_version_is_compatible(v: c.clap_version_t) bool {
    return v.major >= 1;
}

const Entry = struct {
    fn init(plugin_path: [*c]const u8) callconv(.C) bool {
        _ = plugin_path;

        // this is my current best idea on how to read logging
        // reaper has hostLog extension, but I don't know how that works
        if (builtin.mode == .Debug and builtin.os.tag == .windows) {
            c.redirectStdOutToConsoleWindow();
        }

        global.init();
        return true;
    }
    fn deinit() callconv(.C) void {}
    fn get_factory(factory_id: [*c]const u8) callconv(.C) ?*const anyopaque {
        if (std.cstr.cmp(factory_id, &c.CLAP_PLUGIN_FACTORY_ID) == 0) {
            return &Factory.Data;
        }
        return null;
    }
};

export const clap_entry = c.clap_plugin_entry_t{
    .clap_version = c.clap_version_t{ .major = c.CLAP_VERSION_MAJOR, .minor = c.CLAP_VERSION_MINOR, .revision = c.CLAP_VERSION_REVISION },
    .init = &Entry.init,
    .deinit = &Entry.deinit,
    .get_factory = &Entry.get_factory,
};
