const std = @import("std");
const instr = @import("instr.zig");

const AccessBits = packed struct {
    /// The CPU will set this bit when the segment is accessed, but only if it is 0.
    accessed: u1,

    /// For code segments: If set to 1 read access is allowed, write is never allowed
    /// For data segments: If set to 1 write access is allowed, read is always allowed
    read_write: u1,

    /// TODO
    direction_conform: u1,

    /// When set, the entry is a code segment, otherwise the entry is a data segment
    executable: u1,

    /// When set the entry is a data or code segment, when not set the
    /// entry is a system segment (i.e. TSS)
    desc_type: u1,

    /// Privilege level,  0 = highest privilege (kernel), 3 = lowest privilege (user applications)
    privilege: u2,

    /// When set the entry describes a valid segment
    present: u1,
};

const FlagBits = packed struct {
    /// Reserved bit, must be set to 0
    reserved_zero: u1,

    /// When set the entry describes a 64-bit code segment. If this bit is set,
    /// the size_flag bit should always be clear.
    code_64: u1,

    /// If set, the entry describes a 32-bit protected mode segment.
    /// If clean, the entry describes a 16-bit protected mode segment.
    mode: u1,

    /// If set, the limit is in 4 KiB blocks. If clear, the limit is in Bytes.
    granularity: u1,
};

const GdtEntry = packed struct {
    limit_lo: u16,
    base_lo: u24,
    access: AccessBits,
    limit_hi: u4,
    flags: FlagBits,
    base_hi: u8,

    fn init(base: u32, limit: u20, access: AccessBits, flags: FlagBits) GdtEntry {
        return GdtEntry{
            .limit_lo = @truncate(limit),
            .base_lo = @truncate(base),
            .access = access,
            .limit_hi = @truncate(limit >> 16),
            .flags = flags,
            .base_hi = @truncate(base >> 24),
        };
    }
};

pub const GdtPtr = packed struct {
    limit: u16,
    base: u32,
};

const kernel_code = AccessBits{
    .accessed = 0,
    .read_write = 1,
    .direction_conform = 0,
    .executable = 1,
    .desc_type = 1,
    .privilege = 0,
    .present = 1,
};

const kernel_data = AccessBits{
    .accessed = 0,
    .read_write = 1,
    .direction_conform = 0,
    .executable = 0,
    .desc_type = 1,
    .privilege = 0,
    .present = 1,
};

const user_code = AccessBits{
    .accessed = 0,
    .read_write = 1,
    .direction_conform = 0,
    .executable = 1,
    .desc_type = 1,
    .privilege = 3,
    .present = 1,
};

const user_data = AccessBits{
    .accessed = 0,
    .read_write = 1,
    .direction_conform = 0,
    .executable = 0,
    .desc_type = 1,
    .privilege = 3,
    .present = 1,
};

const null_access = AccessBits{
    .accessed = 0,
    .read_write = 0,
    .direction_conform = 0,
    .executable = 0,
    .desc_type = 0,
    .privilege = 0,
    .present = 0,
};

const pm32_flags = FlagBits{
    .reserved_zero = 0,
    .code_64 = 0,
    .mode = 1,
    .granularity = 1,
};

const null_flags = FlagBits{
    .reserved_zero = 0,
    .code_64 = 0,
    .mode = 0,
    .granularity = 0,
};

const num_entries = 5;

const entries: [num_entries]GdtEntry = entries: {
    var tmp_entries: [num_entries]GdtEntry = undefined;
    tmp_entries[0] = GdtEntry.init(0, 0, null_access, null_flags);
    tmp_entries[1] = GdtEntry.init(0, 0xFFFFF, kernel_code, pm32_flags);
    tmp_entries[2] = GdtEntry.init(0, 0xFFFFF, kernel_data, pm32_flags);
    tmp_entries[3] = GdtEntry.init(0, 0xFFFFF, user_code, pm32_flags);
    tmp_entries[4] = GdtEntry.init(0, 0xFFFFF, user_data, pm32_flags);
    break :entries tmp_entries;
};

var gdtr = GdtPtr{
    .limit = num_entries * @sizeOf(GdtEntry) - 1,
    .base = undefined,
};

pub fn init() void {
    gdtr.base = @intFromPtr(&entries[0]);
    instr.lgdt(&gdtr);
}
