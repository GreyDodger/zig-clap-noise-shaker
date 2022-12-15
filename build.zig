const std = @import("std");
const Step = std.build.Step;
const Builder = std.build.Builder;

pub fn build(b: *std.build.Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addSharedLibrary("clap-shaker", "src/main.zig", .unversioned);
    exe.linkLibC();
    exe.addIncludePath("clap/include");
    exe.addIncludePath("src");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const rename_dll_step = CreateClapPluginStep.create(b, exe);
    b.getInstallStep().dependOn(&rename_dll_step.step);
}

pub const CreateClapPluginStep = struct {
    pub const base_id = .top_level;

    const Self = @This();

    step: Step,
    builder: *Builder,
    artifact: *std.build.LibExeObjStep,

    pub fn create(builder: *Builder, artifact: *std.build.LibExeObjStep) *Self {
        const self = builder.allocator.create(Self) catch unreachable;
        const name = "create clap plugin";

        self.* = Self{
            .step = Step.init(.top_level, name, builder.allocator, make),
            .builder = builder,
            .artifact = artifact,
        };

        self.step.dependOn(&artifact.step);
        return self;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(Self, "step", step);
        if (self.artifact.target.isWindows()) {
            var dir = std.fs.cwd();
            _ = try dir.updateFile("zig-out/lib/clap-shaker.dll", dir, "zig-out/lib/clap-shaker.dll.clap", .{});
        } else if (self.artifact.target.isDarwin()) {
            var dir = std.fs.cwd();
            _ = try dir.updateFile("zig-out/lib/libclap-shaker.dylib", dir, "zig-out/lib/Noise Shaker.clap/Contents/MacOS/Noise Shaker", .{});
            _ = try dir.updateFile("macos/info.plist", dir, "zig-out/lib/Noise Shaker.clap/Contents/info.plist", .{});
            _ = try dir.updateFile("macos/PkgInfo", dir, "zig-out/lib/Noise Shaker.clap/Contents/PkgInfo", .{});
        }
    }
};
