# Building xWalk hardware

Run these commands from `xWalk-rpi5-hw`. The preset selects all platform flags and the output directory.

## Host

```bash
cmake --preset host
cmake --build --preset host
ctest --preset host
```

Host output: `../build-host/cmake`. The preset enables hardware-free tests and the simulated Boot backend.

## Raspberry Pi

```bash
cmake --preset rpi
cmake --build --preset rpi
```

Raspberry Pi output: `../build-rpi/cmake`. Build on the Pi for native ARM64 binaries.
The preset selects Linux hardware providers. It builds optional hardware tests but does not run them.
On an x86 machine, this preset checks native provider compilation using the host compiler.

## ARM64 cross build

Set `XWALK_AARCH64_SYSROOT` to the reviewed target sysroot, then run:

```bash
cmake --preset rpi-cross
cmake --build --preset rpi-cross
```

Cross-build output: `../build-aarch64/cmake`. The repository AArch64 toolchain and target dependencies are required.
Keep the three build directories separate. The existing detailed presets remain available for quality checks.

The full Node `host` and `rpi5` presets also build this complete hardware tree. They enable
`XWALK_BUILD_ALL_BACKENDS` internally, compiling every Linux provider while HOST Boot continues to use
simulation. The Node `module` preset remains isolated. Run the ordinary Node configure and build commands;
no additional flags are required.
