# Hardware-independent Raspberry Pi 5 readiness

This document records what can be established without energising a PiCar-X. The
host build, Robot HAT simulator, recorded-media tests, and sanitizers exercise
software behaviour only. They do not verify Raspberry Pi 5 electrical access,
Robot HAT revision detection, motor polarity, servo geometry, camera cabling,
audio-device selection, or sensor calibration.

## Safety architecture

The deployment composition is intentionally inert during construction. Motors
must initialise successfully and then be explicitly armed before movement.
Motor commands are limited by `picarx_max_motor_output_percent`, whose
deployment default is 20 percent. A command expires after
`picarx_motor_watchdog_timeout_ms`, whose default is 500 ms. Expiry, emergency
stop, paired-channel failure, control-input loss, line loss, and safety-pipeline
failure stop both motors and disarm them. Clearing a fault never resumes a
previous command; recovery requires explicit rearming.

The injected monotonic clock tests also treat clock rollback and large forward
jumps as watchdog expiry. This prevents an old command from remaining valid
while a discontinuous clock catches up.

The watchdog is process-local. It cannot protect against power loss, kernel
failure, `SIGKILL`, a completely stalled process, or a fault below the software
stack. A physical power-disconnect method remains mandatory during
commissioning.

Steering, camera pan, and camera tilt use independent calibration and mechanical
limits. Servo construction does not write PWM, initialisation is explicit and
idempotent, persisted positions are disabled by default, and shutdown does not
command a new position. Commands outside the configured angle range are
rejected rather than silently clamped.

## Device-free validation

Validate the complete layered deployment manifest without constructing any
physical backend:

```bash
xwalk-picarx-control --deployment-config=/absolute/path/to/picar-x.conf --validate-config
xwalk-picarx-control --deployment-config=/absolute/path/to/picar-x.conf --print-effective-config
xwalk-picarx-control --deployment-config=/absolute/path/to/picar-x.conf --diagnose --no-hardware
```

The report checks board selection, device-path shapes, V4 and V5 motor maps,
motor inversion and limits, watchdog bounds, servo offsets and commissioning
gates, camera source settings, language-model transport settings, and the local
control listener. `deployment_config_version` defaults to the backward-compatible
schema version 1; an explicitly unsupported version is rejected. Effective
output uses stable schema order and redacts secret-shaped values. A passing
report is simulated configuration evidence, not device discovery or hardware
verification.

The Robot HAT simulator is documented in
[`xWalk-rpi5-hw/xWalkHal/simulation/xWalkRobotHat/README.md`](../../xWalkHal/simulation/xWalkRobotHat/README.md).
It covers the default `0x14` I2C address, register state, PWM P0 through P15, ADC
A0 through A7, GPIO, grayscale values, ultrasonic distance, battery voltage,
encoded camera frames, deterministic event order and logical delays, and
targeted faults. It never opens Linux hardware device nodes. Robot HAT v5 motor
composition uses P12/P13 and P14/P15; v4 PWM-and-direction mapping remains
available where the production composition supports it.

The ADC conversion path uses one I2C transaction lock around request and
response. Controlled interleaving tests verify that simultaneous A0 and A1
reads cannot exchange responses.

The road-user safety pipeline defines detector and classifier boundaries for
person, car, bicycle, bus, and motorbike detections. Synthetic scenarios cover
safe, warning, dangerous, occluded, camera-loss, invalid-output, and model-fault
transitions. A generated four-frame MJPEG recording exercises decoded frame
order, image-derived bounding-box features, Safe/Warning/Dangerous transitions,
simulated red LED and buzzer output, line-loss stop, and end-of-video stop as one
end-to-end scenario. Twelve additional committed five-frame recorded fixtures
cover entering and standing pedestrians, vehicle/pedestrian risk, bicycle,
multiple users, occlusion, poor lighting, motion blur, empty road, false-positive
challenge, camera interruption and normal end-of-video. Their immutable sources,
licenses, transformations and SHA-256 values are recorded in
`xWalk-rpi5-hw/xWalkAgent/xWalkVision/test/assets/manifests/manifest.json`; behavior annotations
are separate and validated before decode tests. No trained YOLO or Random Forest artifact is included, so
these tests establish media and control-flow safety rather than model accuracy.

## Camera sources

Computer vision and recording accept `automatic`, `v4l2`, `gstreamer`,
`video_file`, and `image_sequence` input backends. Input and recording output
configuration are separate. Host tests generate a small MJPEG fixture and
distinguish finite-source end-of-file from a live-source failure. The configured
read timeout is best effort because OpenCV and the selected driver may ignore
`CAP_PROP_READ_TIMEOUT_MSEC`; bounded V4L2/libcamera shutdown therefore still
requires Raspberry Pi testing.

Example host-safe settings are:

```ini
computer_vision_camera_backend = video_file
computer_vision_camera_device = /absolute/path/to/scenario.avi
computer_vision_read_timeout_ms = 1000
video_recording_camera_backend = image_sequence
video_recording_camera_device = /absolute/path/to/frames/frame-%03d.png
video_recording_directory = /tmp/xwalk-videos
video_recording_read_timeout_ms = 1000
```

CSI input remains configurable through the installed `rpicam-still` settings,
but it has not been tested on Raspberry Pi 5. Do not assume `/dev/video0` is the
CSI camera.

## Bounded HTTP/MJPEG transport

`xWalkVideoStreaming` supplies deterministic multipart-MJPEG framing, a
thread-safe, bounded per-client queue. It validates loopback-only defaults,
client and frame limits, rejects malformed JPEG input, drops the oldest queued
frame for slow clients, clears queued movement-adjacent media after camera loss,
and supports idempotent start, disconnect, and shutdown operations. Its
pump-driven non-blocking IPv4 listener exposes `/stream`, `/health` and `/status`
without creating a thread or actuator endpoint. Requests, clients, pending
output and timeouts are bounded. External binding is disabled by default and
requires both explicit opt-in and a caller-owned authentication callback plus
secret reference. Loopback socket tests pass on x86; external binding and
Raspberry Pi networking remain unverified.

## Fuzzing, logical models, and soak testing

Nine Clang/libFuzzer executables cover JSON configuration, generated Protobuf,
gRPC request payloads, bounded HTTP parsing, camera-source strings, model
metadata, scenario JSON, I2C payloads and OpenCV image decoding. Seed corpora
and commands are documented in `scripts/integration/cpp-tool/fuzz/README.md`. LeakSanitizer cannot
finalize under the current sandbox wrapper, so local smoke uses ASan/UBSan with
leak detection disabled and records that limitation.

The Robot HAT simulator includes configurable logical—not physically
calibrated—motor rate limits, direction inversion, steering/servo clamps,
battery thresholds and reduction, grayscale and ultrasonic sequences, camera
delay/freeze and intermittent I2C failure. Events use logical time and bounded
storage. The finite soak executable accepts `--seed`, `--iterations`,
`--logical-duration`, `--fault-rate`, and `--report`; every injected failure
must leave motor commands at zero and the logical controller disarmed.

Short CI soak:

```bash
build-host/cmake/xWalkHal/simulation/xWalkRobotHat/xWalkRobotHatSoakTest --seed 42 --iterations 5000 --logical-duration 10000 --fault-rate 0.05 --report build-host/soak-ci.json
```

Medium developer soak:

```bash
build-host/cmake/xWalkHal/simulation/xWalkRobotHat/xWalkRobotHatSoakTest --seed 20260811 --iterations 100000 --logical-duration 1000000 --fault-rate 0.02 --report build-host/soak-medium.json
```

Long local soak:

```bash
build-host/cmake/xWalkHal/simulation/xWalkRobotHat/xWalkRobotHatSoakTest --seed 20260811 --iterations 1000000 --logical-duration 10000000 --fault-rate 0.01 --report build-host/soak-long.json
```

## Reproduction commands

```bash
cmake --fresh -S xWalk-rpi5-hw --preset host-debug
cmake --build build-host/cmake --parallel
ctest --test-dir build-host/cmake --output-on-failure
ctest --test-dir build-host/cmake -L group-tests --output-on-failure
ctest --test-dir build-host/cmake -L simulation --output-on-failure
ctest --test-dir build-host/cmake -L recorded-media --output-on-failure
ctest --test-dir build-host/cmake -L streaming --output-on-failure
ctest --test-dir build-host/cmake -L soak --output-on-failure
cmake --build build-host/cmake --target cppcheck
```

The complete sanitizer, coverage, Valgrind, Clang Static Analyzer, and
ShellCheck workflow is documented in
[`scripts/integration/cpp-tool/quality/README.md`](../../cpp-tool/quality/README.md). The current GCC host
coverage baseline is 80.7 percent lines, 85.2 percent functions, and 66.6
percent branches. LeakSanitizer is blocked under the present ptrace wrapper;
its intentional leak is rejected but the runtime cannot complete. Clang TSan
rejects the intentional race and its four focused project tests pass when the
sandbox grants loopback access. LSan must be rerun on an unrestricted native
Ubuntu host or VM.

These checks improve confidence in host software only. They do not establish
ARM64 compatibility or physical PiCar-X readiness.

For the reviewed-sysroot AArch64 procedure and dependency separation, use
[`ARM64_CROSS_BUILD.md`](ARM64_CROSS_BUILD.md). A cross-build is not a hardware
test.

Run the target dependency and architecture audit independently with:

```bash
XWALK_AARCH64_SYSROOT=/absolute/path/to/arm64-sysroot bash scripts/integration/shell-agent/deploy-tool/aarch64-dependency-audit.sh
```

The audit never substitutes host packages. It fails when required target
metadata, linker inputs, or AArch64 objects are missing and when any resolved
package path escapes the reviewed sysroot.

## Wheels-up commissioning gate

Before running a movement command:

1. Confirm the exact PiCar-X kit and Robot HAT revision from board markings and
   the supplied schematic.
2. Verify battery chemistry, voltage, polarity, power-switch state, and every
   connector with the official assembly guide.
3. Fit the Raspberry Pi 5-compatible camera cable with power removed.
4. Raise the wheels, disconnect motor power for the first boot, and keep servo
   horns mechanically unloaded where practical.
5. Build and run host-compatible tests on the Pi; do not run hardware tests yet.
6. Run `xwalk-picarx-control doctor`, inspect `/dev/i2c-*`, GPIO-chip identity,
   camera discovery, and ALSA devices.
7. With actuators still disabled, confirm the expected I2C address and read ADC,
   grayscale, battery, button, and ultrasonic inputs individually.
8. Test each servo separately with conservative limits, then establish centres
   and mechanical endpoints before enabling persisted calibration.
9. Reconnect one motor at a time, keep wheels raised, use no more than 20 percent
   output, and verify polarity, stop, emergency stop, watchdog expiry, `Ctrl+C`,
   and repeated shutdown.
10. Only after both paired-stop paths pass should line tracking, camera safety,
    voice, AI, or complete-application tests be attempted at low speed in a clear
    area.

Record each result as one of: verified on x86, simulated only, cross-compiled
only, verified on Raspberry Pi 5, or verified on physical PiCar-X. Never promote
a simulated result to a physical-hardware claim.
