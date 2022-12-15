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

    // TODO
    // figure out how to read the current target

    //if(target.os_tag.? == .Windows) {
    //const rename_dll_step = RenameDllStep.create(b);
    //rename_dll_step.step.dependOn(&exe.install_step.?.step);
    //b.getInstallStep().dependOn(&rename_dll_step.step);
    //}

    //const rename_dll_step = CreateMacOSBundle.create(b);
    //rename_dll_step.step.dependOn(&exe.install_step.?.step);
    //b.getInstallStep().dependOn(&rename_dll_step.step);
}

pub const RenameDllStep = struct {
    pub const base_id = .top_level;

    step: Step,
    builder: *Builder,

    pub fn create(builder: *Builder) *RenameDllStep {
        const self = builder.allocator.create(RenameDllStep) catch unreachable;
        const name = "rename dll";

        self.* = RenameDllStep{
            .step = Step.init(.top_level, name, builder.allocator, make),
            .builder = builder,
        };

        return self;
    }

    fn make(step: *Step) !void {
        _ = step;
        var dir = std.fs.cwd();
        _ = try dir.rename("zig-out/lib/clap-shaker.dll", "zig-out/lib/clap-shaker.dll.clap");
    }
};

pub const CreateMacOSBundle = struct {
    pub const base_id = .top_level;

    step: Step,
    builder: *Builder,

    pub fn create(builder: *Builder) *CreateMacOSBundle {
        const self = builder.allocator.create(CreateMacOSBundle) catch unreachable;
        const name = "create macos bundle";

        self.* = CreateMacOSBundle{
            .step = Step.init(.top_level, name, builder.allocator, make),
            .builder = builder,
        };

        return self;
    }

    fn make(step: *Step) !void {
        _ = step;
        var dir = std.fs.cwd();
        _ = try dir.rename("zig-out/lib/libclap-shaker.dylib", "zig-out/lib/Noise Shaker.clap/Contents/MacOS/Noise Shaker");
    }
};
