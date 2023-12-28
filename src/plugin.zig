const std = @import("std");
const c = @import("ext/vst3.zig");
const assert = std.debug.assert;

pub const std_options = struct {
    pub const log_level = .debug;
};

// Global Allocator
var global_gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var global_allocator = global_gpa.allocator();

fn copy_wide_string(dst: []i16, src: []const u8) void {
    for (dst[0..src.len], src) |*d, s| d.* = @intCast(s);
}

const Guid = [16]u8;

const Interface = struct {
    cid: Guid,
    ptr_offset: usize,
};

fn parseGuid(str: []const u8) Guid {
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

fn FUnknown(comptime name: []const u8, comptime interfaces: []const Interface) type {
    _ = name;
    return struct {
        const vtbl = c.Steinberg_FUnknownVtbl{
            .queryInterface = queryInterface,
            .addRef = addRef,
            .release = release,
        };

        fn queryInterface(self: *anyopaque, iid: [*]const u8, obj: *?*anyopaque) callconv(.C) c.Steinberg_tresult {
            for (interfaces) |interface| {
                if (std.mem.eql(u8, iid[0..16], &interface.cid)) {
                    const interface_ptr: *c.Steinberg_FUnknown =
                        @ptrFromInt(@intFromPtr(self) + interface.ptr_offset);
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

fn PluginBase(comptime name: []const u8, comptime interfaces: []const Interface) type {
    const FUnknown_vtbl = FUnknown(name, interfaces);

    return struct {
        const vtbl = c.Steinberg_IPluginBaseVtbl{
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

fn Component(comptime interfaces: []const Interface) type {
    const PluginBase_vtbl = PluginBase("IComponent", interfaces).vtbl;

    return struct {
        const vtbl = c.Steinberg_Vst_IComponentVtbl{
            .queryInterface = PluginBase_vtbl.queryInterface,
            .addRef = PluginBase_vtbl.addRef,
            .release = PluginBase_vtbl.release,
            .initialize = PluginBase_vtbl.initialize,
            .terminate = PluginBase_vtbl.terminate,
            .getControllerClassId = getControllerClassId,
            .setIoMode = setIoMode,
            .getBusCount = getBusCount,
            .getBusInfo = getBusInfo,
            .getRoutingInfo = getRoutingInfo,
            .activateBus = activateBus,
            .setActive = setActive,
            .setState = setState,
            .getState = getState,
        };

        fn getControllerClassId(self: *anyopaque, class_id: [*c]u8) callconv(.C) c.Steinberg_tresult {
            _ = class_id;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn setIoMode(self: *anyopaque, mode: c.Steinberg_Vst_IoMode) callconv(.C) c.Steinberg_tresult {
            _ = mode;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn getBusCount(self: *anyopaque, media_type: c.Steinberg_Vst_MediaType, dir: c.Steinberg_Vst_BusDirection) callconv(.C) c.Steinberg_int32 {
            _ = dir;
            _ = self;
            if (media_type == c.Steinberg_Vst_MediaTypes_kAudio) {
                return 1;
            } else {
                return 0;
            }
        }

        fn getBusInfo(self: *anyopaque, media_type: c.Steinberg_Vst_MediaType, dir: c.Steinberg_Vst_BusDirection, index: c.Steinberg_int32, info: *c.Steinberg_Vst_BusInfo) callconv(.C) c.Steinberg_tresult {
            _ = index;
            _ = self;
            if (media_type == c.Steinberg_Vst_MediaTypes_kAudio) {
                if (dir == c.Steinberg_Vst_BusDirections_kInput) {
                    info.direction = dir;
                    info.busType = c.Steinberg_Vst_MediaTypes_kAudio;
                    info.channelCount = 2;
                    info.flags = c.Steinberg_Vst_BusInfo_BusFlags_kDefaultActive;
                    copy_wide_string(&info.name, "Audio Input\x00");
                } else {
                    info.direction = dir;
                    info.busType = c.Steinberg_Vst_MediaTypes_kAudio;
                    info.channelCount = 2;
                    info.flags = c.Steinberg_Vst_BusInfo_BusFlags_kDefaultActive;
                    copy_wide_string(&info.name, "Audio Output\x00");
                }
                return c.Steinberg_kResultOk;
            } else {
                return c.Steinberg_kResultFalse;
            }
        }

        fn getRoutingInfo(self: *anyopaque, in_info: *c.Steinberg_Vst_RoutingInfo, out_info: *c.Steinberg_Vst_RoutingInfo) callconv(.C) c.Steinberg_tresult {
            _ = out_info;
            _ = in_info;
            _ = self;
            return c.Steinberg_kResultFalse;
        }

        fn activateBus(self: *anyopaque, type_: c.Steinberg_Vst_MediaType, dir: c.Steinberg_Vst_BusDirection, index: c.Steinberg_int32, state: c.Steinberg_TBool) callconv(.C) c.Steinberg_tresult {
            _ = state;
            _ = index;
            _ = dir;
            _ = type_;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn setActive(self: *anyopaque, state: c.Steinberg_TBool) callconv(.C) c.Steinberg_tresult {
            _ = state;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn setState(self: *anyopaque, state: [*c]c.Steinberg_IBStream) callconv(.C) c.Steinberg_tresult {
            _ = state;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn getState(self: *anyopaque, state: [*c]c.Steinberg_IBStream) callconv(.C) c.Steinberg_tresult {
            _ = state;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn create() c.Steinberg_Vst_IComponent {
            return c.Steinberg_Vst_IComponent{ .lpVtbl = &vtbl };
        }
    };
}

fn EditController(comptime interfaces: []const Interface) type {
    const PluginBase_vtbl = PluginBase("EditController", interfaces).vtbl;

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

fn AudioProcessor(comptime interfaces: []const Interface) type {
    const FUnknown_vtbl = FUnknown("AudioController", interfaces).vtbl;
    return struct {
        const vtbl = c.Steinberg_Vst_IAudioProcessorVtbl{
            .queryInterface = FUnknown_vtbl.queryInterface,
            .addRef = FUnknown_vtbl.addRef,
            .release = FUnknown_vtbl.release,
            .setBusArrangements = setBusArrangements,
            .getBusArrangement = getBusArrangement,
            .canProcessSampleSize = canProcessSampleSize,
            .getLatencySamples = getLatencySamples,
            .setupProcessing = setupProcessing,
            .setProcessing = setProcessing,
            .process = process,
            .getTailSamples = getTailSamples,
        };

        fn setBusArrangements(
            self: *c.Steinberg_Vst_IAudioProcessor,
            inputs: *c.Steinberg_Vst_SpeakerArrangement,
            num_ins: c.Steinberg_int32,
            outputs: *c.Steinberg_Vst_SpeakerArrangement,
            num_outs: c.Steinberg_int32,
        ) callconv(.C) c.Steinberg_tresult {
            _ = num_outs;
            _ = outputs;
            _ = num_ins;
            _ = inputs;
            _ = self;
            return c.Steinberg_kResultFalse;
        }

        fn getBusArrangement(
            self: *c.Steinberg_Vst_IAudioProcessor,
            dir: c.Steinberg_Vst_BusDirection,
            idx: c.Steinberg_int32,
            arr: *c.Steinberg_Vst_SpeakerArrangement,
        ) callconv(.C) c.Steinberg_tresult {
            _ = idx;
            _ = dir;
            _ = self;
            if (arr.* == c.Steinberg_Vst_SpeakerArr_kEmpty or
                arr.* == c.Steinberg_Vst_kSpeakerL or
                arr.* == c.Steinberg_Vst_SpeakerArr_kStereo)
            {
                return c.Steinberg_kResultOk;
            } else {
                arr.* = c.Steinberg_Vst_SpeakerArr_kStereo;
                return c.Steinberg_kResultOk;
            }
        }

        fn canProcessSampleSize(
            self: *c.Steinberg_Vst_IAudioProcessor,
            symbolic_sample_size: c.Steinberg_int32,
        ) callconv(.C) c.Steinberg_tresult {
            _ = symbolic_sample_size;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn getLatencySamples(self: *c.Steinberg_Vst_IAudioProcessor) callconv(.C) c.Steinberg_uint32 {
            _ = self;
            return 0;
        }

        fn setupProcessing(
            self: *c.Steinberg_Vst_IAudioProcessor,
            setup: *c.Steinberg_Vst_ProcessSetup,
        ) callconv(.C) c.Steinberg_tresult {
            _ = setup;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn setProcessing(
            self: *c.Steinberg_Vst_IAudioProcessor,
            state: c.Steinberg_TBool,
        ) callconv(.C) c.Steinberg_tresult {
            _ = state;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn copy_samples(
            comptime T: type,
            num_samples: usize,
            input_buffers: [][*]T,
            output_buffers: [][*]T,
        ) void {
            for (input_buffers, output_buffers[0..input_buffers.len]) |input, output| {
                @memcpy(output[0..num_samples], input[0..num_samples]);
            }
        }

        fn process(
            self: *c.Steinberg_Vst_IAudioProcessor,
            data: *c.Steinberg_Vst_ProcessData,
        ) callconv(.C) c.Steinberg_tresult {
            _ = self;
            if (data.numInputs == 0 or data.numOutputs == 0) {
                return c.Steinberg_kResultOk;
            }

            const num_channels: usize = @intCast(data.inputs[0].numChannels);

            if (data.symbolicSampleSize == c.Steinberg_Vst_SymbolicSampleSizes_kSample32) {
                copy_samples(
                    f32,
                    @intCast(data.numSamples),
                    data.inputs[0].buffers.channelBuffers32[0..num_channels],
                    data.outputs[0].buffers.channelBuffers32[0..num_channels],
                );
            } else {
                copy_samples(
                    f64,
                    @intCast(data.numSamples),
                    data.inputs[0].buffers.channelBuffers64[0..num_channels],
                    data.outputs[0].buffers.channelBuffers64[0..num_channels],
                );
            }

            return c.Steinberg_kResultOk;
        }

        fn getTailSamples(self: *c.Steinberg_Vst_IAudioProcessor) callconv(.C) c.Steinberg_uint32 {
            _ = self;
            return 0;
        }

        fn create() c.Steinberg_Vst_IAudioProcessor {
            return c.Steinberg_Vst_IAudioProcessor{
                .lpVtbl = &vtbl,
            };
        }
    };
}

const PluginClass = struct {
    component: c.Steinberg_Vst_IComponent,
    edit_controller: c.Steinberg_Vst_IEditController,
    audio_processor: c.Steinberg_Vst_IAudioProcessor,

    const interfaces = [_]Interface{
        Interface{ .cid = c.Steinberg_Vst_IComponent_iid, .ptr_offset = @offsetOf(PluginClass, "component") },
        Interface{ .cid = c.Steinberg_Vst_IEditController_iid, .ptr_offset = @offsetOf(PluginClass, "edit_controller") },
        Interface{ .cid = c.Steinberg_Vst_IAudioProcessor_iid, .ptr_offset = @offsetOf(PluginClass, "audio_processor") },
    };

    const cid = parseGuid("00dd3401-343f-468e-9cf2-f18bdd415890");

    fn init(allocator: std.mem.Allocator) *PluginClass {
        const self = allocator.create(PluginClass) catch {
            std.log.err("Failed to allocate plugin class!", .{});
            unreachable;
        };
        self.* = PluginClass{
            .component = Component(&interfaces).create(),
            .edit_controller = EditController(&interfaces).create(),
            .audio_processor = AudioProcessor(&interfaces).create(),
        };

        return self;
    }
};

const PluginFactory = struct {
    const cid = c.Steinberg_IPluginFactory_iid;

    const interfaces = [_]Interface{
        Interface{ .cid = cid, .ptr_offset = 0 },
    };

    const FUnknown_vtbl = FUnknown("PluginFactory", &interfaces).vtbl;

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
        return 1;
    }

    fn getClassInfo(self: *c.Steinberg_IPluginFactory, idx: c.Steinberg_int32, info: *c.Steinberg_PClassInfo) callconv(.C) c.Steinberg_tresult {
        _ = self;
        if (idx == 0) {
            // NOTE(oliver): Only one allowed value (thanks Steinberg!), who knows what it's for
            info.cardinality = c.Steinberg_PClassInfo_ClassCardinality_kManyInstances;
            info.cid = PluginClass.cid;
            std.mem.copyForwards(u8, &info.category, "Audio Module Class\x00");
            std.mem.copyForwards(u8, &info.name, "Hello VST3!\x00");

            return c.Steinberg_kResultOk;
        }

        std.log.err("Invalid class info index! {d}", .{idx});
        return c.Steinberg_kResultFalse;
    }

    fn createInstance(self: *c.Steinberg_IPluginFactory, plugin_cid: c.Steinberg_FIDString, riid: c.Steinberg_FIDString, obj: *?*anyopaque) callconv(.C) c.Steinberg_tresult {
        _ = riid;
        _ = self;

        if (std.mem.eql(u8, plugin_cid[0..16], &PluginClass.cid)) {
            // TODO(oliver): Don't just leak this memory, lol
            obj.* = PluginClass.init(global_allocator);
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
