const vst = @import("plugin.zig");
const c = @import("ext/vst3.zig");
const std = @import("std");

fn EditController(
    comptime self_offset: usize,
    comptime interfaces: []const vst.Interface,
) type {
    const PluginBase_vtbl = vst.PluginBase(
        "EditController",
        self_offset,
        interfaces,
    ).vtbl;

    return struct {
        const vtbl = c.Steinberg_Vst_IEditControllerVtbl{
            .queryInterface = PluginBase_vtbl.queryInterface,
            .addRef = PluginBase_vtbl.addRef,
            .release = PluginBase_vtbl.release,
            .initialize = PluginBase_vtbl.initialize,
            .terminate = PluginBase_vtbl.terminate,
            .setComponentState = setComponentState,
            .setState = setState,
            .getState = getState,
            .getParameterCount = getParameterCount,
            .getParameterInfo = getParameterInfo,
            .getParamStringByValue = getParamStringByValue,
            .getParamValueByString = getParamValueByString,
            .normalizedParamToPlain = normalizedParamToPlain,
            .plainParamToNormalized = plainParamToNormalized,
            .getParamNormalized = getParamNormalized,
            .setParamNormalized = setParamNormalized,
            .setComponentHandler = setComponentHandler,
            .createView = createView,
        };

        fn setComponentState(
            self: *c.Steinberg_Vst_IEditController,
            state: *c.Steinberg_IBStream,
        ) callconv(.C) c.Steinberg_tresult {
            _ = state;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn setState(
            self: *c.Steinberg_Vst_IEditController,
            state: *c.Steinberg_IBStream,
        ) callconv(.C) c.Steinberg_tresult {
            _ = state;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn getState(
            self: *c.Steinberg_Vst_IEditController,
            state: *c.Steinberg_IBStream,
        ) callconv(.C) c.Steinberg_tresult {
            _ = state;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn getParameterCount(self: *c.Steinberg_Vst_IEditController) callconv(.C) c.Steinberg_int32 {
            _ = self;
            return 0;
        }

        fn getParameterInfo(
            self: *c.Steinberg_Vst_IEditController,
            param_idx: c.Steinberg_int32,
            info: *c.Steinberg_Vst_ParameterInfo,
        ) callconv(.C) c.Steinberg_tresult {
            _ = info;
            _ = param_idx;
            _ = self;
            return c.Steinberg_kResultFalse;
        }

        fn getParamStringByValue(
            self: *c.Steinberg_Vst_IEditController,
            id: c.Steinberg_Vst_ParamID,
            value_normalized: c.Steinberg_Vst_ParamValue,
            string: [*:0]c.Steinberg_Vst_TChar,
        ) callconv(.C) c.Steinberg_tresult {
            _ = string;
            _ = value_normalized;
            _ = id;
            _ = self;
            return c.Steinberg_kResultFalse;
        }

        fn getParamValueByString(
            self: *c.Steinberg_Vst_IEditController,
            id: c.Steinberg_Vst_ParamID,
            string: [*:0]c.Steinberg_Vst_TChar,
            value_normalized: *c.Steinberg_Vst_ParamValue,
        ) callconv(.C) c.Steinberg_tresult {
            _ = value_normalized;
            _ = string;
            _ = id;
            _ = self;
            return c.Steinberg_kResultFalse;
        }

        fn normalizedParamToPlain(
            self: *c.Steinberg_Vst_IEditController,
            id: c.Steinberg_Vst_ParamID,
            value_normalized: c.Steinberg_Vst_ParamValue,
        ) callconv(.C) c.Steinberg_Vst_ParamValue {
            _ = value_normalized;
            _ = id;
            _ = self;
            return 0;
        }

        fn plainParamToNormalized(
            self: *c.Steinberg_Vst_IEditController,
            id: c.Steinberg_Vst_ParamID,
            value_plain: c.Steinberg_Vst_ParamValue,
        ) callconv(.C) c.Steinberg_Vst_ParamValue {
            _ = value_plain;
            _ = id;
            _ = self;
            return 0;
        }

        fn getParamNormalized(
            self: *c.Steinberg_Vst_IEditController,
            id: c.Steinberg_Vst_ParamID,
        ) callconv(.C) c.Steinberg_Vst_ParamValue {
            _ = id;
            _ = self;
            return 0;
        }

        fn setParamNormalized(
            self: *c.Steinberg_Vst_IEditController,
            id: c.Steinberg_Vst_ParamID,
            value: c.Steinberg_Vst_ParamValue,
        ) callconv(.C) c.Steinberg_tresult {
            _ = value;
            _ = id;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn setComponentHandler(
            self: *c.Steinberg_Vst_IEditController,
            handler: *c.Steinberg_Vst_IComponentHandler,
        ) callconv(.C) c.Steinberg_tresult {
            _ = handler;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn createView(
            self: *c.Steinberg_Vst_IEditController,
            name: c.Steinberg_FIDString,
        ) callconv(.C) ?*c.Steinberg_IPlugView {
            _ = name;
            _ = self;
            return null;
        }

        fn create() c.Steinberg_Vst_IEditController {
            return c.Steinberg_Vst_IEditController{
                .lpVtbl = &vtbl,
            };
        }
    };
}

pub const PluginController = struct {
    edit_controller: c.Steinberg_Vst_IEditController,

    const interfaces = [_]vst.Interface{
        vst.Interface{ .cid = c.Steinberg_Vst_IEditController_iid, .ptr_offset = @offsetOf(PluginController, "edit_controller") },
    };

    pub const cid = vst.parseGuid("4f48782a-c430-428f-ae1b-f7fe9827afb8");

    pub fn init(allocator: std.mem.Allocator) *PluginController {
        const self = allocator.create(PluginController) catch {
            std.log.err("Failed to allocate plugin controller!", .{});
            unreachable;
        };

        self.* = PluginController{
            .edit_controller = EditController(
                @offsetOf(PluginController, "edit_controller"),
                &interfaces,
            ).create(),
        };

        return self;
    }
};
