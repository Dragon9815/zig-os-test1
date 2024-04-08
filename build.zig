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
        "qemu-system-x86_64",
        "-cdrom", iso_path,
        "-debugcon", "stdio",
        "-m", "128M",
        "-machine", "q35,accel=kvm:whpx:tcg",
        "-no-reboot", "-no-shutdown"
    };
    // zig fmt: on

    const run_cmd = b.addSystemCommand(run_cmd_str);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the kernel");
    run_step.dependOn(&run_cmd.step);

    // zig fmt: off
    const listing_cmd_str = &[_][]const u8{
        "objdump", "-d", "-S"
    };
    // zig fmt: on
    const listing_cmd = b.addSystemCommand(listing_cmd_str);
    listing_cmd.addFileArg(.{ .path = kernel_path });
    listing_cmd.step.dependOn(&kernel_install_step.step);

    const listing_output = listing_cmd.captureStdOut();

    const listing_step = b.step("listing", "Create kernel listing");
    listing_step.dependOn(&b.addInstallFileWithDir(listing_output, .prefix, "kernel.lst").step);
}
