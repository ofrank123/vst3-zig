const vst = @import("plugin.zig");
const ctrl = @import("controller.zig");
const c = @import("ext/vst3.zig");
const std = @import("std");

fn Component(
    comptime self_offset: usize,
    comptime interfaces: []const vst.Interface,
) type {
    const PluginBase_vtbl = vst.PluginBase(
        "IComponent",
        self_offset,
        interfaces,
    ).vtbl;

    return struct {
        const Self = @This();

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

        fn getControllerClassId(self: *c.Steinberg_Vst_IComponent, class_id: [*]u8) callconv(.C) c.Steinberg_tresult {
            _ = self;
            @memcpy(class_id[0..16], &ctrl.PluginController.cid);
            return c.Steinberg_kResultOk;
        }

        fn setIoMode(self: *c.Steinberg_Vst_IComponent, mode: c.Steinberg_Vst_IoMode) callconv(.C) c.Steinberg_tresult {
            _ = mode;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn getBusCount(self: *c.Steinberg_Vst_IComponent, media_type: c.Steinberg_Vst_MediaType, dir: c.Steinberg_Vst_BusDirection) callconv(.C) c.Steinberg_int32 {
            _ = dir;
            _ = self;
            if (media_type == c.Steinberg_Vst_MediaTypes_kAudio) {
                return 1;
            } else {
                return 0;
            }
        }

        fn getBusInfo(self: *c.Steinberg_Vst_IComponent, media_type: c.Steinberg_Vst_MediaType, dir: c.Steinberg_Vst_BusDirection, index: c.Steinberg_int32, info: *c.Steinberg_Vst_BusInfo) callconv(.C) c.Steinberg_tresult {
            _ = index;
            _ = self;
            if (media_type == c.Steinberg_Vst_MediaTypes_kAudio) {
                if (dir == c.Steinberg_Vst_BusDirections_kInput) {
                    info.direction = dir;
                    info.busType = c.Steinberg_Vst_MediaTypes_kAudio;
                    info.channelCount = 2;
                    info.flags = c.Steinberg_Vst_BusInfo_BusFlags_kDefaultActive;
                    vst.copy_wide_string(&info.name, "Audio Input\x00");
                } else {
                    info.direction = dir;
                    info.busType = c.Steinberg_Vst_MediaTypes_kAudio;
                    info.channelCount = 2;
                    info.flags = c.Steinberg_Vst_BusInfo_BusFlags_kDefaultActive;
                    vst.copy_wide_string(&info.name, "Audio Output\x00");
                }
                return c.Steinberg_kResultOk;
            } else {
                return c.Steinberg_kResultFalse;
            }
        }

        fn getRoutingInfo(self: *c.Steinberg_Vst_IComponent, in_info: *c.Steinberg_Vst_RoutingInfo, out_info: *c.Steinberg_Vst_RoutingInfo) callconv(.C) c.Steinberg_tresult {
            _ = out_info;
            _ = in_info;
            _ = self;
            return c.Steinberg_kResultFalse;
        }

        fn activateBus(self: *c.Steinberg_Vst_IComponent, type_: c.Steinberg_Vst_MediaType, dir: c.Steinberg_Vst_BusDirection, index: c.Steinberg_int32, state: c.Steinberg_TBool) callconv(.C) c.Steinberg_tresult {
            _ = state;
            _ = index;
            _ = dir;
            _ = type_;
            _ = self;
            // TODO(oliver): Handle bus activation properly
            return c.Steinberg_kResultOk;
        }

        fn setActive(self: *c.Steinberg_Vst_IComponent, state: c.Steinberg_TBool) callconv(.C) c.Steinberg_tresult {
            _ = state;
            _ = self;
            return c.Steinberg_kResultOk;
        }

        fn setState(self: *c.Steinberg_Vst_IComponent, state: *c.Steinberg_IBStream) callconv(.C) c.Steinberg_tresult {
            var plugin_: ?*PluginClass = null;
            _ = self.lpVtbl.queryInterface(
                self,
                &PluginClass.cid,
                @ptrCast(&plugin_),
            );

            if (plugin_) |plugin| {
                // TODO(oliver): Check for failure
                _ = state.lpVtbl.read(state, &plugin.gain, @sizeOf(f32), null);
                std.log.debug("Setting Gain: {d}", .{plugin.gain});
            } else {
                std.log.err("Failed to get plugin when setting state", .{});
            }

            return c.Steinberg_kResultOk;
        }

        fn getState(self: *c.Steinberg_Vst_IComponent, state: *c.Steinberg_IBStream) callconv(.C) c.Steinberg_tresult {
            var plugin_: ?*PluginClass = null;
            _ = self.lpVtbl.queryInterface(
                self,
                &PluginClass.cid,
                @ptrCast(&plugin_),
            );

            if (plugin_) |plugin| {
                // TODO(oliver): Check for failure
                _ = state.lpVtbl.write(state, &plugin.gain, @sizeOf(f32), null);
                std.log.debug("Getting Gain: {d}", .{plugin.gain});
            } else {
                std.log.err("Failed to get plugin when getting state", .{});
            }

            return c.Steinberg_kResultOk;
        }

        fn create() c.Steinberg_Vst_IComponent {
            return c.Steinberg_Vst_IComponent{ .lpVtbl = &vtbl };
        }
    };
}

fn AudioProcessor(
    comptime self_offset: usize,
    comptime interfaces: []const vst.Interface,
) type {
    const FUnknown_vtbl = vst.FUnknown(
        "AudioController",
        self_offset,
        interfaces,
    ).vtbl;

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
            // Handle Events
            const event_count = data.inputEvents.lpVtbl.getEventCount(data.inputEvents);
            for (0..@intCast(event_count)) |idx| {
                var event: ?*c.Steinberg_Vst_Event = null;
                _ = data.inputEvents.lpVtbl.getEvent(
                    data.inputEvents,
                    @intCast(idx),
                    @ptrCast(event),
                );
            }

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

pub const PluginClass = struct {
    // Interfaces
    component: c.Steinberg_Vst_IComponent, // NOTE(oliver): Must come first because VST3 doesn't really follow COM :-)
    audio_processor: c.Steinberg_Vst_IAudioProcessor,

    // Self properties
    gain: f32,

    const interfaces = [_]vst.Interface{
        vst.Interface{ .cid = cid, .ptr_offset = 0 }, // Self
        vst.Interface{ .cid = c.Steinberg_Vst_IComponent_iid, .ptr_offset = @offsetOf(PluginClass, "component") },
        vst.Interface{ .cid = c.Steinberg_Vst_IAudioProcessor_iid, .ptr_offset = @offsetOf(PluginClass, "audio_processor") },
    };

    pub const cid = vst.parseGuid("00dd3401-343f-468e-9cf2-f18bdd415890");

    pub fn init(allocator: std.mem.Allocator) *PluginClass {
        const self = allocator.create(PluginClass) catch {
            std.log.err("Failed to allocate plugin class!", .{});
            unreachable;
        };
        self.* = PluginClass{
            .component = Component(
                @offsetOf(PluginClass, "component"),
                &interfaces,
            ).create(),
            .audio_processor = AudioProcessor(
                @offsetOf(PluginClass, "audio_processor"),
                &interfaces,
            ).create(),

            .gain = 0.5,
        };

        return self;
    }
};
