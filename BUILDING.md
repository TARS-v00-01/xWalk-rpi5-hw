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

## Full hardware module regression from the root

The shared GoogleTest fixture runs the same production Controller → Driver → HAL sequences for Robot HAT v4
and v5 with deterministic HOST providers. It verifies lifecycle/restart, motor PWM output and cleanup, camera
servos, ADC failure propagation and recovery, request correlation, battery averaging, camera failure recovery,
and announcement/shutdown. This does not validate electrical behavior, real cameras, speakers, or physical motion.

Build and run every hardware component suite, the root sequences, Library architecture checks, and audio assets:

```bash
python3 ci/run-module-tests.py --jobs 4
```

Run the new sequences alone after configuring the host preset:

```bash
cmake --build --preset host --target xWalkHardwareSequenceTest
ctest --test-dir ../build-host/cmake -R '^xWalkHardwareSequenceHostTest$' --output-on-failure
```

With an already fully built host tree, use `--no-build --build-dir ../build-host/cmake`, or invoke:

```bash
cmake --build ../build-host/cmake --target xWalkHardwareFullTest
```

The full-test target requires the normal aggregate build first. All runs exclude hardware-labelled tests and
reject a non-HOST cache. Test configuration stays under the build directory. Each sequence has a bounded timeout.
Hardware integration CI adds the full regression after its five component checks and requires it before the gate.
The repository workflow pins the submitted tooling revision that provides this CI stage.

| Root test file | Responsibility |
| --- | --- |
| `xWalkTest/include/xWalkHardwareTestSupport.h` | Shared graph ownership and parameterized fixture |
| `xWalkTest/src/xWalkHardwareTestSupport.cpp` | Isolated configuration, bounded requests, motor output checks |
| `xWalkTest/src/xWalkHardwareSequenceTest.cpp` | Identical multi-device sequences for both board profiles |
| `xWalkTest/CMakeLists.txt` | Host-only GoogleTest registration and full-test target |
| `ci/run-module-tests.py` | Complete hardware component regression entry point |
| `ci/test-module-runner.py` | Inventory completeness and device-test exclusion regressions |

## Editor include resolution

`xWalkTest/` follows the same module naming as the desktop repository. The full-test runner and host preset
both export `../build-host/cmake/compile_commands.json`. VS Code settings support opening this hardware
repository or the parent product, including the shared test headers and build-local test configuration macro.

After adding or moving C++ sources, refresh the compilation database from this repository:

```bash
cmake --preset host
```

If VS Code still shows cached include errors, run **C/C++: Reset IntelliSense Database** and reload the window.
Do not copy generated compilation databases into Git; they contain machine-specific build paths.
