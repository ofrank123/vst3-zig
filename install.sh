mkdir -p HelloVST3.vst3/Contents/Resources
mkdir -p HelloVST3.vst3/Contents/x86_64-linux
zig build && cp zig-out/lib/libHelloVST3.so HelloVST3.vst3/Contents/x86_64-linux/HelloVST3.so && cp -r HelloVST3.vst3 ~/.vst3/
