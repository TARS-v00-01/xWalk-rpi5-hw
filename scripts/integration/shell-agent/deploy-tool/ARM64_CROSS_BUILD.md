# ARM64 cross-build from Linux x86

The checked-in toolchain prevents CMake from resolving x86 headers or libraries for an AArch64 target. A complete,
reviewed ARM64 sysroot is required; the cross compiler alone is not sufficient.

The sysroot must contain ARM64 development files for Protobuf, gRPC, TinyXML2, ALSA, OpenCV, CURL, OpenSSL,
GoogleTest/GoogleMock when tests are enabled, and every transitive dependency selected by the build. Keep host tools
such as `protoc` and `grpc_cpp_plugin` installed on x86. Do not copy individual x86 libraries into the sysroot.

Audit the staged target metadata before configuring. The command confines
`pkg-config` to the sysroot, checks the required package families and their
reported linker inputs, and rejects metadata or resolved libraries outside the
reviewed root. A missing dependency produces a complete list instead of stopping
at the first CMake package lookup.

```sh
XWALK_AARCH64_SYSROOT=/absolute/path/to/arm64-sysroot bash scripts/integration/shell-agent/deploy-tool/aarch64-dependency-audit.sh
```

One reproducible source is a staged Raspberry Pi OS 64-bit or Ubuntu 24.04 ARM64 root filesystem whose package
versions match the intended target. Copy it read-only from a controlled image or target into a local directory, then
configure with:

```sh
export XWALK_AARCH64_SYSROOT=/absolute/path/to/arm64-sysroot
cmake --fresh -S xWalk-rpi5-hw --preset aarch64-rpi-release
cmake --build build-aarch64/cmake --parallel
find build-aarch64/cmake -type f -perm -111 -exec file {} \;
```

The preset is the preferred reproducible profile. The equivalent explicit
commands are:

```sh
cmake -S xWalk-rpi5-hw -B build-aarch64 -DCMAKE_TOOLCHAIN_FILE=xWalk-rpi5-hw/cmake/toolchains/aarch64-linux-gnu.cmake -DXWALK_AARCH64_SYSROOT=/absolute/path/to/arm64-sysroot -DXWALK_BUILD_RPI=ON -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build build-aarch64 --parallel
find build-aarch64 -type f -perm -111 -exec file {} \;
```

The toolchain propagates `XWALK_AARCH64_SYSROOT` into CMake compiler
`try_compile` projects. A missing or incomplete reviewed sysroot therefore
fails at the guard, while a usable compiler reaches target dependency discovery
without resolving host libraries. It also clears `PKG_CONFIG_PATH` and sets
`PKG_CONFIG_SYSROOT_DIR` and `PKG_CONFIG_LIBDIR` to target-only locations.
Cross RPI configuration runs the dependency audit by default. The
`XWALK_AARCH64_DEPENDENCY_AUDIT=OFF` escape hatch is for isolated toolchain
diagnosis only and must not be used for a deployable build.

After the ARM64 build succeeds, package only from that target build directory:

```sh
cmake -S xWalk-rpi5-hw -B build-aarch64 -DCMAKE_TOOLCHAIN_FILE=xWalk-rpi5-hw/cmake/toolchains/aarch64-linux-gnu.cmake -DXWALK_AARCH64_SYSROOT=/absolute/path/to/arm64-sysroot -DXWALK_BUILD_RPI=ON -DXWALK_ENABLE_PACKAGING=ON -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=Release
cpack --config build-aarch64/CPackConfig.cmake
```

CMake rejects Debian packaging from the x86 compile-check profile, and CPack is
fixed to the `arm64` package architecture. This prevents an x86 binary set from
being presented as a deployable Raspberry Pi package.

For an Ubuntu multiarch sysroot, install the matching `:arm64` development packages into a dedicated staged root
instead of the host root. Required package families include `libprotobuf-dev`, `protobuf-compiler-grpc`,
`libgrpc++-dev`, `libtinyxml2-dev`, `libasound2-dev`, `libopencv-dev`, `libcurl4-openssl-dev`, `libssl-dev`,
`libgtest-dev`, and their dependencies. Package availability and exact names must be checked against the selected
distribution release. The current audit covers Protobuf, gRPC, OpenCV, ALSA,
CURL, OpenSSL, TinyXML2, JSON-C, libsndfile, and yaml-cpp. Their `pkg-config`
link flags are also inspected, so required transitive linker inputs must exist
inside the target root and identify as AArch64 ELF when directly inspectable.

QEMU smoke execution is optional and device-free. It requires `qemu-aarch64`
and a fully linked target runtime. Run only `--help`, `--validate-config`,
`--print-effective-config`, and `--diagnose --no-hardware`; do not run hardware
commands or hardware-labelled tests under emulation.

An ARM64 link proves only target-architecture build compatibility. It does not verify Raspberry Pi 5 GPIO, I2C,
camera, audio, Robot HAT behavior, actuator mapping, timing, or electrical safety.

See [`HARDWARE_INDEPENDENT_READINESS.md`](HARDWARE_INDEPENDENT_READINESS.md) for simulator, camera-source, safety,
and wheels-up commissioning guidance.
