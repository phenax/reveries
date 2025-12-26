const std = @import("std");

pub fn build(b: *std.Build) void {
  const target = b.standardTargetOptions(.{});
  const optimize = b.standardOptimizeOption(.{});
  const exe = b.addExecutable(.{
    .name = "dashboard",
    .root_module = b.createModule(.{
      .root_source_file = b.path("src/main.zig"),
      .target = target,
      .optimize = optimize,
    }),
  });

  const raylib_dep = b.dependency("raylib_zig", .{
      .target = target,
      .optimize = optimize,
      .platform = b.option([]const u8, "platform", "Raylib platform") orelse "glfw",
  });

  const raylib = raylib_dep.module("raylib"); // main raylib module
  const raygui = raylib_dep.module("raygui"); // raygui module
  const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library
  exe.linkLibrary(raylib_artifact);
  exe.root_module.addImport("raylib", raylib);
  exe.root_module.addImport("raygui", raygui);

  const pg = b.dependency("datetime", .{
    .target = target,
    .optimize = optimize,
  });
  exe.root_module.addImport("datetime", pg.module("datetime"));

  exe.linkLibC();
  // exe.linkSystemLibrary("GL");
  exe.linkSystemLibrary("m");
  exe.linkSystemLibrary("pthread");
  exe.linkSystemLibrary("dl");
  exe.linkSystemLibrary("EGL");

  // exe.defineCMacro("PLATFORM_DRM", null);
  // exe.defineCMacro("GRAPHICS_API_OPENGL_ES2", null);

  b.installArtifact(exe);

  const run_exe = b.addRunArtifact(exe);

  const run_step = b.step("run", "Run the application");
  run_step.dependOn(&run_exe.step);
}
