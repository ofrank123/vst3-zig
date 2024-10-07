const std = @import("std");
const c = @import("ext/vst3.zig");
const assert = std.debug.assert;
const ctrl = @import("controller.zig");
const proc = @import("processor.zig");

pub const std_options = std.Options{
    .log_level = .debug,
};

// Global Allocator
var global_gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var global_allocator = global_gpa.allocator();

pub fn copy_wide_string(dst: []i16, src: []const u8) void {
    for (dst[0..src.len], src) |*d, s| d.* = @intCast(s);
}

const Guid = [16]u8;

pub const Interface = struct {
    cid: Guid,
    ptr_offset: usize,
};

pub fn parseGuid(str: []const u8) Guid {
    var last_nibble: ?u8 = null;
    var ret = [_]u8{0} ** 16;
    var idx: usize = 0;
    for (str) |char| {
        var nibble: u8 = 0;
        if ('A' <= char and char <= 'F') {
            nibble = char - 'A' + 10;
        } else if ('a' <= char and char <= 'f') {
            nibble = char - 'a' + 10;
        } else if ('0' <= char and char <= '9') {
            nibble = char - '0';
        } else {
            continue;
        }

        if (last_nibble) |last_val| {
            ret[idx] = last_val * 16 + nibble;
            idx += 1;
            last_nibble = null;
        } else {
            last_nibble = nibble;
        }
    }

    return ret;
}

pub fn FUnknown(comptime name: []const u8, comptime self_offset: usize, comptime interfaces: []const Interface) type {
    _ = name;
    return struct {
        pub const vtbl = c.Steinberg_FUnknownVtbl{
            .queryInterface = queryInterface,
            .addRef = addRef,
            .release = release,
        };

        fn queryInterface(self: *anyopaque, iid: [*]const u8, obj: *?*anyopaque) callconv(.C) c.Steinberg_tresult {
            for (interfaces) |interface| {
                if (std.mem.eql(u8, iid[0..16], &interface.cid)) {
                    const interface_ptr: *c.Steinberg_FUnknown =
                        @ptrFromInt(@intFromPtr(self) - self_offset + interface.ptr_offset);
                    _ = interface_ptr.lpVtbl.addRef(@ptrCast(interface_ptr));
                    obj.* = @ptrCast(interface_ptr);
                    return c.Steinberg_kResultOk;
                }
            }

            return c.Steinberg_kResultFalse;
        }

        // TODO(oliver): Handle ref counting properly
        fn addRef(self: *anyopaque) callconv(.C) c.Steinberg_uint32 {
            _ = self;
            return 1;
        }

        // TODO(oliver): Handle ref counting properly
        fn release(self: *anyopaque) callconv(.C) c.Steinberg_uint32 {
            _ = self;
            return 1;
        }
    };
}

pub fn PluginBase(comptime name: []const u8, comptime self_offset: usize, comptime interfaces: []const Interface) type {
    const FUnknown_vtbl = FUnknown(name, self_offset, interfaces);

    return struct {
        pub const vtbl = c.Steinberg_IPluginBaseVtbl{
            .queryInterface = FUnknown_vtbl.queryInterface,
            .addRef = FUnknown_vtbl.addRef,
            .release = FUnknown_vtbl.release,
            .initialize = initialize,
            .terminate = terminate,
        };

        fn initialize(self: *anyopaque, context: *c.Steinberg_FUnknown) callconv(.C) c.Steinberg_tresult {
            _ = context;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn terminate(self: *anyopaque) callconv(.C) c.Steinberg_tresult {
            _ = self;
            return c.Steinberg_kResultOk;
        }
    };
}

const PluginFactory = struct {
    const cid = c.Steinberg_IPluginFactory_iid;

    const interfaces = [_]Interface{
        Interface{ .cid = cid, .ptr_offset = 0 },
    };

    const FUnknown_vtbl = FUnknown("PluginFactory", 0, &interfaces).vtbl;

    const vtbl = c.Steinberg_IPluginFactoryVtbl{
        .queryInterface = FUnknown_vtbl.queryInterface,
        .addRef = FUnknown_vtbl.addRef,
        .release = FUnknown_vtbl.release,
        .getFactoryInfo = getFactoryInfo,
        .countClasses = countClasses,
        .getClassInfo = getClassInfo,
        .createInstance = createInstance,
    };

    const factory = c.Steinberg_IPluginFactory{
        .lpVtbl = &vtbl,
    };

    fn getFactoryInfo(self: *c.Steinberg_IPluginFactory, info: *c.Steinberg_PFactoryInfo) callconv(.C) c.Steinberg_tresult {
        _ = self;
        std.mem.copyForwards(u8, &info.vendor, "SuperElectric\x00");
        std.mem.copyForwards(u8, &info.url, "https://superelectric.dev\x00");
        std.mem.copyForwards(u8, &info.email, "oliverfrank321@gmail.com\x00");
        info.flags = 8;

        return c.Steinberg_kResultOk;
    }

    fn countClasses(self: *c.Steinberg_IPluginFactory) callconv(.C) c.Steinberg_int32 {
        _ = self;
        return 2;
    }

    fn getClassInfo(self: *c.Steinberg_IPluginFactory, idx: c.Steinberg_int32, info: *c.Steinberg_PClassInfo) callconv(.C) c.Steinberg_tresult {
        _ = self;
        if (idx == 0) {
            // NOTE(oliver): Only one allowed value (thanks Steinberg!), who knows what it's for
            info.cardinality = c.Steinberg_PClassInfo_ClassCardinality_kManyInstances;
            info.cid = proc.PluginClass.cid;
            std.mem.copyForwards(u8, &info.category, "Audio Module Class\x00");
            std.mem.copyForwards(u8, &info.name, "Hello VST3!\x00");

            return c.Steinberg_kResultOk;
        } else if (idx == 1) {
            info.cardinality = c.Steinberg_PClassInfo_ClassCardinality_kManyInstances;
            info.cid = ctrl.PluginController.cid;
            std.mem.copyForwards(u8, &info.category, "Component Controller Class\x00");
            std.mem.copyForwards(u8, &info.name, "Hello VST3! Controller\x00");

            return c.Steinberg_kResultOk;
        }

        std.log.err("Invalid class info index! {d}", .{idx});
        return c.Steinberg_kResultFalse;
    }

    fn createInstance(self: *c.Steinberg_IPluginFactory, plugin_cid: c.Steinberg_FIDString, riid: c.Steinberg_FIDString, obj: *?*anyopaque) callconv(.C) c.Steinberg_tresult {
        _ = riid;
        _ = self;

        if (std.mem.eql(u8, plugin_cid[0..16], &proc.PluginClass.cid)) {
            // TODO(oliver): Don't just leak this memory, lol
            obj.* = proc.PluginClass.init(global_allocator);
            return c.Steinberg_kResultOk;
        } else if (std.mem.eql(u8, plugin_cid[0..16], &ctrl.PluginController.cid)) {
            obj.* = ctrl.PluginController.init(global_allocator);
            return c.Steinberg_kResultOk;
        }

        std.log.err("Cannot create instance: invalid CID", .{});
        return c.Steinberg_kResultFalse;
    }
};

pub export fn GetPluginFactory() *const c.Steinberg_IPluginFactory {
    return &PluginFactory.factory;
}

pub export fn ModuleEntry(_: *anyopaque) bool {
    return true;
}

pub export fn ModuleExit() bool {
    _ = global_gpa.deinit();
    return true;
}
