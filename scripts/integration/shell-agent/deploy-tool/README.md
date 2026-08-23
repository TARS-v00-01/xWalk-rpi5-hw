# Deployment tools

This directory contains reviewed Raspberry Pi provisioning, cross-build audit,
package-installation, service, udev, tmpfiles, and host-test assets for xWalk.
Run commands from the `MyPiCarX` repository root.

Hardware operations are opt-in. Do not run `--apply` or
`provision-hardware.sh` until the exact Raspberry Pi, Robot HAT revision,
wiring, power state, GPIO controller, I2C bus, SPI device, and safe actuator
state have been confirmed.

## Directory contents

| Path | Purpose |
|---|---|
| `setup-rpi-local.sh` | Build pinned camera and Ollama runtimes below the current user's `${HOME}/.local`. |
| `configure-rpi-runtime.sh` | Generate build-local configuration, start user Ollama, and list local models. |
| `generate-rpi-runtime.sh` | Generate ignored build-local Raspberry Pi configuration. |
| `rpi-defaults.conf` | Own the shared CMake and deployment-script Raspberry Pi defaults. |
| `setup-rpi.sh` | Assess, validate, preview, or apply Raspberry Pi host provisioning. |
| `provision-hardware.sh` | Record a verified Robot HAT and exact device identities in a writable configuration. |
| `aarch64-dependency-audit.sh` | Validate an ARM64 sysroot and dependency architecture. |
| `debian/` | Debian package metadata. |
| `systemd/` | Installed xWalk service unit and defaults. |
| `searxng/` | Optional loopback-only SearXNG compose and JSON settings. |
| `udev/` | Device-access rule template. |
| `tmpfiles/` | Runtime-directory configuration. |
| `test/` | Host-safe tests and fixtures; no physical hardware is accessed. |

## Inspect the Raspberry Pi plan

Show the supported options:

```bash
scripts/integration/shell-agent/deploy-tool/setup-rpi.sh --help
```

The script defaults to Robot HAT v4, runtime user `xwalk`, `/dev/gpiochip4`,
`/dev/i2c-1`, `/dev/spidev0.0`, CSI camera, and dry-run mode. It still requires
a real supported Raspberry Pi identity and an existing runtime user. Preview
the default plan:

```bash
scripts/integration/shell-agent/deploy-tool/setup-rpi.sh --dry-run
```

Use `--check` to validate the target without changing it. `--apply` may install
packages, update boot configuration, install service and access-control assets,
and change the target configuration. Review the complete dry-run output before
authorization. Explicit options continue to select Robot HAT v5, alternate
devices, USB cameras, or another runtime user:

```bash
scripts/integration/shell-agent/deploy-tool/setup-rpi.sh --profile robot_hat_v5 --runtime-user operator --gpio-device /dev/gpiochip0 --camera usb --check
```

## Record verified hardware

The hardware provisioner validates the detected HAT identity and GPIO metadata,
then atomically updates an existing writable configuration while preserving its
owner, group, and mode. Root may preserve any existing ownership; a non-root
caller must own the configuration and retain permission to use its group:

```bash
scripts/integration/shell-agent/deploy-tool/provision-hardware.sh --profile robot_hat_v5 --config /var/lib/xwalk/picar-x.conf --gpio-device /dev/gpiochip0 --i2c-device /dev/i2c-1 --spi-device /dev/spidev0.0
```

After provisioning, run `--diagnose --no-hardware`, then the bounded `doctor`
preflight before any separately authorized calibration or actuator test. Doctor
pulses only the configured MCU reset GPIO and reports that activation explicitly.
For an explicit v4 profile, Doctor verifies the recorded GPIO identity and
successful MCU firmware and battery transactions without claiming that an
absent v5 UUID alone identifies v4.

## Install the validated user-local runtime

Preview the pinned Raspberry Pi 5 camera and Ollama workflow without changing
the host:

```bash
scripts/integration/shell-agent/deploy-tool/setup-rpi-local.sh --dry-run
```

On the target Pi, apply it as the non-root runtime user. It builds the official
Raspberry Pi libcamera fork and rpicam-apps into `${HOME}/.local` by default, installs an
Ollama user service and `llama3.2:3b`, adds the runtime user to `video` and
`render`, and generates ignored files below `build-rpi`. It never installs an
xWalk package or camera build under `/usr` or `/usr/local`:

```bash
scripts/integration/shell-agent/deploy-tool/setup-rpi-local.sh --apply
```

Use `--local-prefix /absolute/prefix` when the camera stack is installed outside
`${HOME}/.local`. The Raspberry Pi CMake configure records the same prefix in
`XWALK_RPI_LOCAL_PREFIX` and validates the CSI plugin and its matching
libraries. CMake compiles the required GStreamer plugin directory into the
Raspberry Pi executable. The plugin's validated runpath selects the matching
libraries, so users do not export camera environment variables manually.

Log out and back in or reboot after group changes. Then test the camera with
`${HOME}/.local/bin/rpicam-still --list-cameras` and run the build-local executable:

```bash
build-rpi/cmake/xWalkController/xWalkApp/xwalk-picarx-control doctor
```

To regenerate the runtime configuration later and ensure the existing Ollama
user service is enabled and running, use the following command. This target-side
check records one second of microphone input to `/dev/null`, verifies the
configured PulseAudio mixer element, and checks the Vosk and Piper assets
without moving the vehicle:

```bash
scripts/integration/shell-agent/deploy-tool/configure-rpi-runtime.sh
```

The tracked service binds Ollama only to `127.0.0.1:11434`, restarts after an
unexpected failure with a three-second delay, and reuses an installed
`llama3.2:3b` model. Inspect it without exposing the service publicly:

```bash
systemctl --user daemon-reload
systemctl --user enable --now ollama
systemctl --user status ollama --no-pager
journalctl --user -u ollama --no-pager
curl http://127.0.0.1:11434/api/tags
ollama list
```

For a service-managed Jarvis session, stop any separately configured system
controller instance, then enable the user service. Its `Requires=` and `After=`
ordering starts the same user manager's Ollama unit first:

```bash
systemctl --user enable --now xwalk-jarvis
systemctl --user status xwalk-jarvis --no-pager
journalctl --user -u xwalk-jarvis --no-pager
systemctl --user stop xwalk-jarvis
```

## Audit an ARM64 sysroot

Point the audit at an explicit absolute sysroot. It validates headers,
pkg-config metadata, library search paths, and AArch64 library identities
without operating hardware:

```bash
XWALK_AARCH64_SYSROOT=/absolute/aarch64/sysroot scripts/integration/shell-agent/deploy-tool/aarch64-dependency-audit.sh
```

See [ARM64_CROSS_BUILD.md](ARM64_CROSS_BUILD.md) and
[HARDWARE_INDEPENDENT_READINESS.md](HARDWARE_INDEPENDENT_READINESS.md) for the
complete cross-build and readiness requirements.

## Host-safe verification

These checks use fixtures or temporary directories and do not actuate hardware:

```bash
bash scripts/integration/shell-agent/deploy-tool/test/setup-rpi-test.sh
bash scripts/integration/shell-agent/deploy-tool/test/aarch64-dependency-audit-test.sh
bash scripts/integration/shell-agent/deploy-tool/test/environment-loader-test.sh
bash scripts/integration/shell-agent/deploy-tool/test/language-model-config-test.sh
bash scripts/integration/shell-agent/deploy-tool/test/rpi-local-runtime-test.sh
python3 scripts/integration/shell-agent/deploy-tool/test/dependency-installer-test.py
```

Run ShellCheck over the deployment scripts before review:

```bash
scripts/integration/shell-agent/quality-tool/run-host-shellcheck.sh
```
