pub const c = @cImport({
    @cInclude("clap/clap.h");
    @cInclude("string.h");
});

const std = @import("std");
const ArrayList = std.ArrayList;
const util = @import("util.zig");
const c_cast = std.zig.c_translation.cast;
const global = @import("global.zig");

var prng = std.rand.DefaultPrng.init(0);
pub var rng: std.rand.Random = undefined;

pub const Params = struct {
    const Values = struct {
        gain_amplitude: f64 = 0.0,
    };
    const ValueMeta = struct {
        min_value: f64,
        max_value: f64,
    };

    pub var values = Values{};
    var value_metas = [std.meta.fields(Values).len]ValueMeta{
        .{ .min_value = 0.0, .max_value = 1.0 },
    };

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
                info.* = .{
                    .id = index,
                    .name = undefined,
                    .module = undefined,
                    .min_value = value_metas[index].min_value,
                    .max_value = value_metas[index].max_value,
                    .default_value = @ptrCast(*const f64, @alignCast(@alignOf(field.field_type), field.default_value.?)).*,
                    .flags = 0,
                    .cookie = null,
                };
                _ = std.fmt.bufPrintZ(&info.*.name, field.name, .{}) catch unreachable;
                _ = std.fmt.bufPrintZ(&info.*.module, "params/" ++ field.name, .{}) catch unreachable;
            },
            else => {},
        }
        return true;
    }
    fn get_value(plugin: [*c]const c.clap_plugin_t, id: c.clap_id, out: [*c]f64) callconv(.C) bool {
        _ = plugin;
        const fields = std.meta.fields(Values);
        switch (id) {
            inline 0...(fields.len - 1) => |comptime_index| {
                out.* = @field(values, fields[comptime_index].name);
            },
            else => {},
        }
        return true;
    }
    fn value_to_text(plugin: [*c]const c.clap_plugin_t, id: c.clap_id, value: f64, buf_ptr: [*c]u8, buf_size: u32) callconv(.C) bool {
        _ = plugin;
        var buf: []u8 = buf_ptr[0..buf_size];

        if (id == 0) {
            const display = util.amplitudeTodB(@floatCast(f32, value));
            _ = std.fmt.bufPrintZ(buf, "{d:.4} dB", .{display}) catch unreachable;
        } else {
            _ = std.fmt.bufPrintZ(buf, "{d:.4}", .{value}) catch unreachable;
        }
        return true;
    }
    fn text_to_value(plugin: [*c]const c.clap_plugin_t, id: c.clap_id, display: [*c]const u8, out: [*c]f64) callconv(.C) bool {
        _ = plugin;
        _ = id;
        _ = display;
        _ = out;
        return true;
    }
    fn flush(plugin: [*c]const c.clap_plugin_t, in: [*c]const c.clap_input_events_t, out: [*c]const c.clap_output_events_t) callconv(.C) void {
        _ = plugin;
        _ = in;
        _ = out;
    }

    const Data = c.clap_plugin_params_t{
        .count = count,
        .get_info = get_info,
        .get_value = get_value,
        .value_to_text = value_to_text,
        .text_to_value = text_to_value,
        .flush = flush,
    };

    fn writeAll(stream: *const c.clap_ostream_t) bool {
        inline for (std.meta.fields(Values)) |field| {
            const value = @field(values, field.name);
            const num_bytes = @sizeOf(@TypeOf(value));
            if (stream.*.write.?(stream, &value, num_bytes) != num_bytes) {
                return false;
            }
        }
        return true;
    }
    fn readAll(stream: *const c.clap_istream_t) bool {
        inline for (std.meta.fields(Values)) |field| {
            const value = &@field(values, field.name);
            const num_bytes = @sizeOf(@TypeOf(value.*));
            if (stream.*.read.?(stream, value, num_bytes) != num_bytes) {
                return false;
            }
        }
        return true;
    }

    pub fn setValue(param_id: u32, value: f64) void {
        const fields = std.meta.fields(Values);
        switch (param_id) {
            inline 0...(fields.len - 1) => |comptime_index| {
                @field(values, fields[comptime_index].name) = value;
            },
            else => {},
        }
    }
    pub fn setValueTellHost(param_id: u32, value: f64, time: u32, out_events: *const c.clap_output_events_t) void {
        setValue(param_id, value);

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
        _ = plugin;
        var success = Params.writeAll(stream);
        return success;
    }

    fn load(plugin: [*c]const c.clap_plugin_t, stream: [*c]const c.clap_istream_t) callconv(.C) bool {
        _ = plugin;
        var success = Params.readAll(stream);
        return success;
    }

    const Data = c.clap_plugin_state_t{
        .save = save,
        .load = load,
    };
};

pub const MyPlugin = struct {
    plugin: c.clap_plugin_t,
    latency: u32,
    host: [*c]const c.clap_host_t,
    hostParams: [*c]const c.clap_host_params_t,
    hostLog: ?*const c.clap_host_log_t,
    hostLatency: [*c]const c.clap_host_latency_t,
    hostThreadCheck: [*c]const c.clap_host_thread_check_t,

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
        _ = plugin;
        _ = sample_rate;
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

    var prev_sample = [2]f32{
        0.0,
        0.0,
    };

    fn do_process(plugin: [*c]const c.clap_plugin_t, process: [*c]const c.clap_process_t) callconv(.C) c.clap_process_status {
        var plug = c_cast(*MyPlugin, plugin.*.plugin_data);

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

            var param_gain_amp = @floatCast(f32, Params.values.gain_amplitude);

            while (frame_index < next_event_frame) : (frame_index += 1) {
                // white noise
                const out = [2]f32{
                    util.randAmplitudeValue() * param_gain_amp,
                    util.randAmplitudeValue() * param_gain_amp,
                };

                prev_sample = out;

                process.*.audio_outputs[0].data32[0][frame_index] = out[0];
                process.*.audio_outputs[0].data32[1][frame_index] = out[1];
            }
        }

        return c.CLAP_PROCESS_SLEEP;
    }

    fn do_process_event(plug: *const MyPlugin, hdr: [*c]const c.clap_event_header_t, out_events: *const c.clap_output_events_t) void {
        _ = plug;
        if (hdr.*.space_id == c.CLAP_CORE_EVENT_SPACE_ID) {
            switch (hdr.*.type) {
                c.CLAP_EVENT_PARAM_VALUE => {
                    const ev = c_cast([*c]const c.clap_event_param_value_t, hdr);
                    Params.setValue(ev.*.param_id, ev.*.value);
                },
                c.CLAP_EVENT_MIDI => {
                    const ev = c_cast([*c]const c.clap_event_midi_t, hdr);
                    switch (ev.*.data[0]) {
                        144 => { // Note On
                            const velocity = ev.*.data[2];
                            _ = velocity;
                        },
                        176 => { // CC
                            if (ev.*.data[1] == 1) {
                                const db_value = util.amplitudeTodB(@intToFloat(f32, ev.*.data[2]) / 127.0);
                                Params.setValueTellHost(0, db_value, hdr.*.time, out_events);
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

        global.init();
        rng = prng.random();

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