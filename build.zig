const std = @import("std");
const Step = std.build.Step;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addSharedLibrary(.{
        .name = "clap-shaker",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe.addIncludePath(.{ .path = "clap/include" });
    exe.addIncludePath(.{ .path = "src" });

    const rename_dll_step = CreateClapPluginStep.create(b, exe);
    b.getInstallStep().dependOn(&rename_dll_step.step);
}

pub const CreateClapPluginStep = struct {
    pub const base_id = .top_level;

    const Self = @This();

    step: Step,
    build: *std.Build,
    artifact: *Step.Compile,

    pub fn create(b: *std.Build, artifact: *Step.Compile) *Self {
        const self = b.allocator.create(Self) catch unreachable;
        const name = "create clap plugin";

        self.* = Self{
            .step = Step.init(Step.StepOptions{ .id = .top_level, .name = name, .owner = b, .makeFn = make }),
            .build = b,
            .artifact = artifact,
        };

        self.step.dependOn(&artifact.step);
        return self;
    }

    fn make(step: *Step, _: *std.Progress.Node) !void {
        const self = @fieldParentPtr(Self, "step", step);
        if (self.build.build_root.path) |path| {
            if (self.artifact.target.isWindows()) {
                var dir = try std.fs.openDirAbsolute(path, .{});
                _ = try dir.updateFile("zig-out/lib/clap-shaker.dll", dir, "zig-out/lib/clap-shaker.dll.clap", .{});
            } else if (self.artifact.target.isDarwin()) {
                var dir = try std.fs.openDirAbsolute(path, .{});
                _ = try dir.updateFile("zig-out/lib/libclap-shaker.dylib", dir, "zig-out/lib/Noise Shaker.clap/Contents/MacOS/Noise Shaker", .{});
                _ = try dir.updateFile("macos/info.plist", dir, "zig-out/lib/Noise Shaker.clap/Contents/info.plist", .{});
                _ = try dir.updateFile("macos/PkgInfo", dir, "zig-out/lib/Noise Shaker.clap/Contents/PkgInfo", .{});
            }
        }
    }
};
