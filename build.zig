const std = @import("std");

pub fn build(b: *std.Build) void {
    const features = std.Target.x86.Feature;

    var disabled_features = std.Target.Cpu.Feature.Set.empty;
    var enabled_features = std.Target.Cpu.Feature.Set.empty;

    disabled_features.addFeature(@intFromEnum(features.mmx));
    disabled_features.addFeature(@intFromEnum(features.sse));
    disabled_features.addFeature(@intFromEnum(features.sse2));
    disabled_features.addFeature(@intFromEnum(features.avx));
    disabled_features.addFeature(@intFromEnum(features.avx2));
    enabled_features.addFeature(@intFromEnum(features.soft_float));

    const target_query = std.zig.CrossTarget{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
        .cpu_features_sub = disabled_features,
        .cpu_features_add = enabled_features,
    };
    const target = b.resolveTargetQuery(target_query);
    const optimize = b.standardOptimizeOption(.{});

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .code_model = .kernel,
    });
    kernel.setLinkerScriptPath(.{ .path = "src/linker.ld" });
    kernel.addAssemblyFile(.{ .path = "src/start.s" });
    const kernel_install_step = b.addInstallArtifact(kernel, .{});

    const kernel_step = b.step("kernel", "Build the kernel");
    kernel_step.dependOn(&kernel_install_step.step);

    const iso_dir = b.fmt("{s}/iso_root", .{b.cache_root.path orelse unreachable});
    const kernel_path = b.getInstallPath(kernel_install_step.dest_dir orelse unreachable, kernel.out_filename);
    const iso_path = b.fmt("{s}/disk.iso", .{b.exe_dir});

    // zig fmt: off
    const iso_cmd_str = &[_][]const u8{
        "/bin/sh", "-c",
        std.mem.concat(b.allocator, u8, &[_][]const u8{
            "mkdir -p ", iso_dir, "/boot/grub && ",
            "cp ", kernel_path, " ", iso_dir, "/boot && ",
            "cp src/grub.cfg ", iso_dir, "/boot/grub && ",
            "grub-mkrescue -o ", iso_path, " ", iso_dir,
        }) catch unreachable
    };
    // zig fmt: on

    const iso_cmd = b.addSystemCommand(iso_cmd_str);
    iso_cmd.step.dependOn(kernel_step);

    const iso_step = b.step("iso", "Build an ISO image");
    iso_step.dependOn(&iso_cmd.step);
    b.default_step.dependOn(iso_step);

    // zig fmt: off
    const run_cmd_str = &[_][]const u8{
        "qemu-system-i386",
        "-nodefaults",
        "-d", "cpu_reset", "-d", "int",
        "-vga", "none",
        "-machine", "q35", //"q35,accel=kvm:whpx:tcg", // this makes the -d option not work
        "-m", "128M",
        "-cdrom", iso_path,
        "-serial", "stdio",
        "-no-reboot", "-no-shutdown",
        "-nographic",
        "-D", "qemu.log",
    };
    // zig fmt: on

    const run_cmd = b.addSystemCommand(run_cmd_str);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the kernel");
    run_step.dependOn(&run_cmd.step);

    // zig fmt: off
    const debug_cmd_str = run_cmd_str ++ &[_][]const u8{
        "-s", "-S"
    };
    // zig fmt: on

    const debug_cmd = b.addSystemCommand(debug_cmd_str);
    debug_cmd.step.dependOn(b.getInstallStep());

    const debug_step = b.step("debug", "Debug the kernel");
    debug_step.dependOn(&debug_cmd.step);

    // zig fmt: off
    const listing_cmd_str = &[_][]const u8{
        "objdump", "-d", "-S", "-Mintel",
    };
    // zig fmt: on
    const listing_cmd = b.addSystemCommand(listing_cmd_str);
    listing_cmd.addFileArg(.{ .path = kernel_path });
    listing_cmd.step.dependOn(&kernel_install_step.step);

    const listing_output = listing_cmd.captureStdOut();

    const listing_step = b.step("listing", "Create kernel listing");
    listing_step.dependOn(&b.addInstallFileWithDir(listing_output, .prefix, "kernel.lst").step);

    // zig fmt: off
    const map_cmd_str = &[_][]const u8{
        "readelf", "-h", "-l", "-S", "-s", "--wide",
    };
    // zig fmt: on
    const map_cmd = b.addSystemCommand(map_cmd_str);
    map_cmd.addFileArg(.{ .path = kernel_path });
    map_cmd.step.dependOn(&kernel_install_step.step);

    const map_output = map_cmd.captureStdOut();
    const map_install_step = b.addInstallFileWithDir(map_output, .prefix, "kernel.map");
    b.default_step.dependOn(&map_install_step.step);
    const map_step = b.step("map", "Create a file similar to a linker map");
    map_step.dependOn(&map_install_step.step);
}
