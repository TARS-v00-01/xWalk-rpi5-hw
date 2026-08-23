# xWalk-rpi5-tool

`xWalk-rpi5-tool` contains repository maintenance, host verification, Raspberry Pi provisioning, interface
generation, and SunFounder Device Tree overlay assets. It is not a runtime HAL or Agent module.

No command in this directory is run automatically by a normal host build. Hardware-affecting commands remain
explicit and must not be used until the Raspberry Pi model, Robot HAT revision, wiring, and safety state are
confirmed.

## Directory inventory

```text
scripts/integration/
├── README.md
├── apt-packages.txt
├── cpp-tool/
│   ├── fuzz/
│   │   ├── README.md
│   │   ├── corpus/
│   │   └── src/
│   └── quality/
│       ├── README.md
│       └── probes/
├── doc-tool/
│   ├── README.md
│   ├── requirements-wiki.txt
│   ├── verify_wiki.py
│   └── wiki.sh
├── py-agent/
│   ├── README.md
│   ├── board-tool/
│   │   ├── pyproject.toml
│   │   ├── README.md
│   │   ├── requirements.txt
│   │   ├── test/
│   │   └── py-src/xWalkJiraImport/
│   ├── dev-tool/
│   │   ├── README.md
│   │   ├── xHal_Rpi5CarDependencyInstaller
│   │   ├── xHal_Rpi5CarIwGenerator
│   │   ├── xWalkLicenseTool
│   │   ├── xWalkZuulValidator
│   │   └── test/
│   └── gerrit-tool/
│       ├── README.md
│       ├── xWalkReviewControls.js
│       ├── bin/
│       ├── config/
│       ├── local-linux/
│       ├── py-src/
│       ├── py-test/
│       └── shell-script/
└── shell-agent/
    ├── README.md
    ├── jira-tool/
    │   └── xWalkJiraImport.sh
    ├── gerrit-tool/
    │   ├── checkout-gerrit-submodules.sh
    │   ├── run-host-ci-job.sh
    │   └── validate-integration-metadata.sh
    ├── deploy-tool/
    │   ├── debian/
    │   ├── provision-hardware.sh
    │   ├── setup-rpi.sh
    │   ├── systemd/
    │   ├── test/
    │   ├── tmpfiles/
    │   └── udev/
    ├── env-tool/
    │   ├── dtoverlays/
    │   │   ├── sunfounder-robothat5.dtbo
    │   │   └── sunfounder-servohat+.dtbo
    │   ├── license/
    │   │   ├── xWalkEnv.sh
    │   │   └── xWalkLicense.cfg
    │   ├── playbooks/
    │   │   └── zuul/
    │   └── quality/
    │       ├── .clang-tidy
    │       ├── .cppcheck-suppressions
    │       └── gcovr.cfg
    ├── repo-tool/
    │   └── clean-build.sh
    └── quality-tool/
        ├── run-host-coverage.sh
        ├── run-host-sanitizer.sh
        ├── run-host-valgrind.sh
        └── test/
```

The directory contains Bash scripts, one package manifest, Python
tools, their host tests, three quality-tool configurations, Gerrit CI assets, deployment assets,
two compiled Device Tree blobs, the empty model-selection configuration, and this
README. The applicable project and third-party license terms are in the
workspace-root `LICENSE`; there is no separate `scripts/integration/LICENSE` file.

## Detailed guides

- [xWalk-rpi5-tool overview](../devloper-note/xwalk-rpi5-note/Doc/note/xWalk-rpi5-tool%20Overview.md)
- [C++ host quality](cpp-tool/quality/README.md)
- [C++ fuzz testing](cpp-tool/fuzz/README.md)
- [Jira history importer](py-agent/board-tool/README.md)
- [Combined Gerrit server, CI, and review controls](py-agent/gerrit-tool/README.md)
- [Clean build script](../devloper-note/xwalk-rpi5-note/Doc/note/Clean%20Build%20Script%20Guide.md)
- [Host coverage script](../devloper-note/xwalk-rpi5-note/Doc/note/Host%20Coverage%20Script%20Guide.md)
- [CMake dependencies](../devloper-note/xwalk-rpi5-note/Doc/note/Dependency%20Installer%20Guide.md)
- [Dependency flags](../devloper-note/xwalk-rpi5-note/Doc/note/Dependency%20Installer%20Script%20Flags.md)
- [Raspberry Pi setup script](../devloper-note/xwalk-rpi5-note/Doc/note/Raspberry%20Pi%20Setup%20Script%20Guide.md)
- [Hardware provisioner](../devloper-note/xwalk-rpi5-note/Doc/note/Hardware%20Provisioning%20Script%20Guide.md)
- [Device Tree overlays](../devloper-note/xwalk-rpi5-note/Doc/note/Device%20Tree%20Overlay%20Assets%20Guide.md)
- [Licence-key workflow](../devloper-note/xwalk-rpi5-note/Doc/note/License%20Key%20Workflow.md)
- [xWalk licence tool](../devloper-note/xwalk-rpi5-note/Doc/note/xWalk%20Licence%20Tool%20Guide.md)
- [xWalk environment loader](../devloper-note/xwalk-rpi5-note/Doc/note/xWalk%20Environment%20Loader%20Guide.md)
- [Developer tools](py-agent/dev-tool/README.md)
- [Python environment guidance](py-agent/README.md)
- [Shell agent](shell-agent/README.md)

## Responsibility summary

| Path | Responsibility | Host safety |
|---|---|---|
| `apt-packages.txt` | Lists and maps host, Raspberry Pi, quality, packaging, and optional packages | Read-only |
| `cpp-tool` | Groups C++ quality probes, fuzz targets, and their documentation | Host-only |
| `cpp-tool/fuzz` | Stores C++ fuzz harnesses and seed corpora | Host-only |
| `cpp-tool/quality` | Documents host quality checks and stores sanitizer probes | Host-only |
| `py-agent` | Groups Python development, board-integration, and Gerrit administration tools | Mixed; see child modules |
| `py-agent/board-tool` | Stores the installable historical Git-to-Jira importer | Dry-run by default |
| `py-agent/dev-tool` | Stores executable Python development utilities and their host tests | Mixed; see tool documentation |
| `py-agent/gerrit-tool` | Runs Gerrit, CI, logs, and review controls | User-owned service |
| `py-agent/dev-tool/xHal_Rpi5CarDependencyInstaller` | Installs dependencies and configures verified v5 boot | Privileged |
| `py-agent/dev-tool/xWalkLicenseTool` | Authenticates model settings without storing API credentials | Host-safe |
| `py-agent/dev-tool/xWalkZuulValidator` | Validates repository Zuul structure | Host-safe |
| `shell-agent/jira-tool/` | Runs the Jira importer directly from source | Dry-run by default |
| `shell-agent/gerrit-tool/` | Dispatches CI jobs and validates Gerrit integration metadata | Host-safe automation |
| `shell-agent/deploy-tool/` | Stores provisioning scripts, packaging assets, and tests | Apply is privileged |
| `shell-agent/env-tool/` | Groups quality, licence, and boot-overlay modules | Mixed; see child modules |
| `shell-agent/env-tool/dtoverlays/` | Stores Robot HAT Device Tree blobs | RPi boot assets |
| `shell-agent/env-tool/license/` | Stores the model template and environment loader | Interactive decryption |
| `shell-agent/env-tool/playbooks/` | Stores Zuul Ansible playbooks | Host-safe CI configuration |
| `shell-agent/env-tool/quality/` | Stores Clang-Tidy, Cppcheck, and gcovr settings | Host-safe configuration |
| `shell-agent/repo-tool/` | Finds and optionally deletes generated output | Dry-run is non-destructive |
| `shell-agent/quality-tool/` | Runs coverage, sanitizers, analysis, ShellCheck, and Valgrind | Host-only |
| `py-agent/dev-tool/xHal_Rpi5CarIwGenerator` | Validates and generates xWalk-rpi5-iw Protobuf/gRPC sources | Host-only generation |

## Licence environment

Install PyNaCl through the supported dependency workflow (`python3-nacl` on
Debian-family systems). Copy `shell-agent/env-tool/license/xWalkLicense.cfg` to a mode-`0600`
location outside the repository and fill only the model settings in that copy.
Never put values into the committed template. Store fixed-provider API credentials only in the developer's
mode-`0600` `~/.netrc` using the documented actual provider hostnames.

Encrypt the protected copy:

```sh
scripts/integration/py-agent/dev-tool/xWalkLicenseTool encrypt --config /secure/location/xWalkLicense.cfg
```

Or supply repeated manual values, recognizing that they can be retained in
shell history or exposed through process inspection:

```sh
scripts/integration/py-agent/dev-tool/xWalkLicenseTool encrypt --env OPENAI_MODEL='gpt-model' --env GEMINI_MODEL='gemini-model'
```

Replace the quoted example text with the real values. Do not type angle-bracket
placeholders because the shell interprets `<` and `>` as redirection operators.

Decrypt only to an explicit temporary path. The key is requested privately and
the resulting JSON receives mode `0600`:

```sh
scripts/integration/py-agent/dev-tool/xWalkLicenseTool decrypt --output /tmp/xWalkLicense.decrypted.json
```

Only the empty model template may be committed. The repository ignores
`xWalk-rpi5-hw/xWalkLibrary/X_WALK_LICENSE.KEY`; authenticated ciphertext is deployment-specific
and must never be committed or pushed. Filled templates, decrypted files, and
the generated decryption key must also remain outside Git. See the detailed
licence-key guide for deployment and security limitations.

After the encrypted file is durable, encryption prints one
`XWALK-<UTC_YEAR>-<8_HEX>` serial and the decryption key. The identical serial
is stored as authenticated `X_WALK_LICENSE_SERIAL` payload metadata. It is an
identifier only and never participates in key derivation.

## Dependency installation and host maintenance

### Apt package manifest

[`apt-packages.txt`](apt-packages.txt) separates the minimum host build/test packages from optional quality,
packaging, deployment-validation, Raspberry Pi, camera, and inactive gRPC-generator dependencies. It also
maps every xWalk HAL source module to its internal libraries and operating-system packages. It is a
reviewable manifest and contains the machine-readable package-manager catalog used by
`xHal_Rpi5CarDependencyInstaller`.

Check every automatically selected dependency without changing the machine:

```sh
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarDependencyInstaller --check
```

Preview installation after detecting the operating system and device:

```sh
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarDependencyInstaller --dry-run
```

Install all supported catalog scopes for the automatically detected platform:

```sh
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarDependencyInstaller
```

The default includes required, native-audio, quality, release, generator, and external scopes. The installer
does not download Vosk models or install Ollama through an unverified remote pipeline; missing external
components are reported with a cross and an explanation. Use `--required-only` for the minimum normal
build/runtime package set. Use `--include quality`, `--include release`, `--include generator`, or
`--include external` with `--required-only` to add selected optional scopes.

Portable libraries already reviewed under the architecture-selected `../xWalkLibrary` prefix are discovered
by CMake before system locations. The installer retains package-manager entries as a fallback for portable
libraries that are not bundled. Toolchains, build utilities, Linux and ALSA integration, device rules, camera
tools, overlays, and services remain system-managed; the installer never extracts Debian packages into the
project prefix.

Specify a platform and device when automatic detection is not appropriate:

```sh
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarDependencyInstaller --os ubuntu --device host --required-only
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarDependencyInstaller --os fedora --device host --required-only
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarDependencyInstaller --os arch --device host --required-only
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarDependencyInstaller --os macos --device host --required-only
```

Supported package families are Debian/Ubuntu/Raspberry Pi OS through APT, Fedora/RHEL through DNF,
Arch/Manjaro through Pacman, and macOS through Homebrew. The macOS report intentionally marks ALSA and Linux
hardware dependencies unavailable because the current CMake host aggregate requires Linux ALSA. It does not
claim that the complete firmware builds on macOS.

Normal Linux package installation uses root or `sudo`; Homebrew is never run through `sudo`. The final table
contains a tick for installed packages and a cross for missing, failed, external, or unsupported dependencies.
The script returns non-zero after `--check` or installation when selected dependencies remain unavailable.

`--device auto` is the default and uses the local Device Tree to distinguish a Raspberry Pi from a host.
`--target` remains an alias for compatibility. `--device host` skips every `config.txt` and overlay operation.

On a Raspberry Pi with a physically verified Robot HAT v5, review the boot plan before installation:

```sh
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarDependencyInstaller --os raspbian --device rpi --profile robot_hat_v5 --camera csi --required-only --dry-run
```

The Raspberry Pi path requires the supported v5 UUID before changing anything. It verifies the bundled
overlay checksum, rejects an active Servo HAT+ overlay or disabled I2C/SPI setting, backs up `config.txt`,
backs up a different existing destination blob, installs `sunfounder-robothat5.dtbo`, and idempotently adds:

```text
dtparam=i2c_arm=on
dtparam=spi=on
dtoverlay=sunfounder-robothat5
```

It detects `/boot/firmware/config.txt` with `/boot/firmware/overlays` or `/boot/config.txt` with
`/boot/overlays`. It never reboots automatically. Reboot and complete passive diagnostics and physical
hardware acceptance before movement.

There is no verified Robot HAT v4 overlay in
`scripts/integration/shell-agent/env-tool/dtoverlays`. The Servo HAT+ blob must not be used as a v4 substitute.
Selecting `--device rpi --profile robot_hat_v4` therefore fails without changing the boot configuration.

Raspberry Pi provisioning should still use `setup-rpi.sh --dry-run` before `--apply`. The guarded v5 path can
configure boot interfaces and its overlay, but it does not configure runtime groups, udev rules, exact device
identity, or mutable deployment configuration.

### Build cleanup

Preview every generated build target without deleting anything:

```sh
scripts/integration/shell-agent/repo-tool/clean-build.sh --dry-run
```

Interactive cleanup requires confirmation. Non-interactive cleanup requires the explicit `--yes` option:

```sh
scripts/integration/shell-agent/repo-tool/clean-build.sh --yes
```

Options:

| Option | Effect |
|---|---|
| `--dry-run` | Lists detected CMake and Python output and exits without deleting it |
| `--yes` | Deletes the listed output without an interactive prompt |
| `--help`, `-h` | Prints usage and exits |

Cleanup is restricted to named CMake build output, detected in-source CMake
output, and recognized Python caches, coverage data, and package-build output.
Generated output can be rebuilt, but cleanup results cannot be recovered directly.

### Coverage

Run coverage in the foreground:

```sh
scripts/integration/shell-agent/quality-tool/run-host-coverage.sh run
```

The required `run` action performs these steps in order:

1. Finds `gcovr`.
2. Removes only the dedicated `build-host/coverage` instrumentation tree.
3. Configures the root CMake `coverage` preset with `cmake --fresh`.
4. Builds the coverage preset.
5. Runs its CTest preset.
6. Generates the reports defined by `scripts/integration/shell-agent/env-tool/quality/gcovr.cfg`.

Use `scripts/integration/shell-agent/quality-tool/run-host-coverage.sh --help` to print usage. Any other action exits with status 2.

The script searches for a system `gcovr` executable and then
`build-host/tools/gcovr-venv/bin/gcovr`. It fails before configuring when neither exists. It never installs
packages, requests privileges, creates a detached process, or accesses physical hardware.

Coverage uses the root `coverage` preset and
`scripts/integration/shell-agent/env-tool/quality/gcovr.cfg`. Reports are written to:

```text
build-host/coverage/coverage.html
build-host/coverage/coverage.xml
```

The report command is also a gate. It fails below 75 percent total line,
87 percent function, or 68 percent total branch coverage.

## Raspberry Pi provisioning

`setup-rpi.sh` supports Debian-family Raspberry Pi OS and Ubuntu Server on a Raspberry Pi. Its authoritative
defaults select Robot HAT v4, runtime user `xwalk`, `/dev/gpiochip4`, `/dev/i2c-1`, `/dev/spidev0.0`, and a CSI
camera. Inspection and planning must precede apply mode.

Show available options:

```sh
scripts/integration/shell-agent/deploy-tool/setup-rpi.sh --help
```

Run a non-modifying plan after physically identifying the board revision:

```sh
scripts/integration/shell-agent/deploy-tool/setup-rpi.sh --dry-run
```

Run required validation without changing the system:

```sh
scripts/integration/shell-agent/deploy-tool/setup-rpi.sh --check
```

The complete option set is:

| Option | Required/default | Effect |
|---|---|---|
| `--profile robot_hat_v4\|robot_hat_v5` | `robot_hat_v4` | Selects the HAT profile |
| `--runtime-user USER` | `xwalk` | Selects an existing unprivileged runtime user |
| `--gpio-device DEVICE` | `/dev/gpiochip4` | Selects one `/dev/gpiochipN` controller |
| `--i2c-device DEVICE` | `/dev/i2c-1` | Selects one `/dev/i2c-N` controller |
| `--spi-device DEVICE` | `/dev/spidev0.0` | Selects one `/dev/spidevN.N` controller |
| `--config FILE` | `/var/lib/xwalk/picar-x.conf` | Selects mutable deployment configuration |
| `--template-config FILE` | `/etc/xwalk/picar-x.conf` | Selects the read-only manifest template |
| `--template-fragments DIRECTORY` | `/etc/xwalk/picar-x.d` | Selects the read-only fragment templates |
| `--camera csi\|usb` | `csi` | Selects `rpicam-apps` or `ffmpeg` as the camera dependency |
| `--with-vosk` | Disabled | Installs the explicitly selected repository-controlled Vosk assets |
| `--vosk-library-source FILE` | Required with Vosk | Selects the architecture-matched Vosk library source |
| `--vosk-model-source DIRECTORY` | Required with Vosk | Selects the Vosk model source |
| `--validate-ollama` | Disabled | Validates the selected user's installed Ollama executable and manifest |
| `--dry-run` | Default | Prints the plan without changing the system |
| `--check`, `--validate` | Optional mode | Validates required target state without changing it |
| `--apply` | Optional mode | Performs the reported privileged changes |
| `--help`, `-h` | Optional | Prints usage and exits |

The setup workflow:

- identifies the operating system and Raspberry Pi model;
- refuses an unverified Robot HAT v5 profile;
- rejects a v4 profile when the supported v5 UUID is detected;
- reports required and optional packages separately;
- validates I2C, SPI, GPIO, configuration, camera, voice, and model prerequisites;
- preserves existing boot configuration and rejects conflicting disabled interfaces;
- plans narrowly scoped groups and udev rules for selected device nodes;
- initializes only writable deployment copies from explicitly selected templates;
- never installs, enables, disables, or guesses a Robot HAT overlay.

`--apply` may install packages, enable base I2C and SPI interfaces, create groups, update membership, install a
generated udev rule, and update deployment configuration. It requires root or `sudo` and must be reviewed from
the preceding dry-run output. It must not be invoked by host tests or CI.

### Hardware identity provisioning

`provision-hardware.sh` is the focused configuration updater used by setup after devices are available. It
requires an explicit v4/v5 profile and an existing writable configuration file:

```sh
scripts/integration/shell-agent/deploy-tool/provision-hardware.sh --help
```

Example after the target devices and board revision have been verified:

```sh
scripts/integration/shell-agent/deploy-tool/provision-hardware.sh --profile robot_hat_v4 --config /var/lib/xwalk/picar-x.conf --gpio-device /dev/gpiochip0 --i2c-device /dev/i2c-1 --spi-device /dev/spidev0.0
```

`--profile` and `--config` are mandatory. The device options select exact device nodes. If
`--gpio-device` is omitted, automatic selection succeeds only when exactly one GPIO chip exists. An omitted
I2C or SPI option leaves that configuration value absent or blank instead of guessing a device.

It validates selected device-path syntax, requires `gpiodetect`, checks that the selected GPIO chip has a
usable label and at least 28 lines, and replaces the configuration atomically. It never moves an actuator or
claims GPIO, I2C, SPI, PWM, servo, or motor outputs.

The Raspberry Pi deployment guide remains the authoritative end-to-end procedure:
[Deployment Guide](../devloper-note/xwalk-rpi5-note/Doc/note/Deployment%20Guide.md).

## xWalk-rpi5-iw generator status

`xHal_Rpi5CarIwGenerator` is an executable Python 3 tool for validating xWalk-rpi5-iw
Protobuf/XML contracts and generating routed C++ Protobuf and gRPC sources. Its
supported actions are:

```sh
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarIwGenerator --help
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarIwGenerator --check
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarIwGenerator --generate-cpp
```

The default input root is `xWalk-rpi5-iw`. The aggregate build validates its
schema contract and compiles the generated C++ library. The module README is the
authoritative protocol, generation, build, and test guide.

Generation additionally requires `protoc`, `grpc_cpp_plugin`, the imported Protobuf schemas, and writable
output directories. Generated files belong under the selected module's `auto-gen/include` and `auto-gen/src`
directories and must not be treated as handwritten production sources.

## Device Tree overlay assets

The two `.dtbo` files are compiled Raspberry Pi Device Tree blobs, not executable host tools and not C++
libraries. They are not activated by `setup-rpi.sh`, the CMake install rules, or host CI. The dependency
installer can install and activate only the Robot HAT v5 blob under the guarded workflow described above.

| File | Board role |
|---|---|
| `sunfounder-robothat5.dtbo` | SunFounder Robot HAT 5 boot-time configuration |
| `sunfounder-servohat+.dtbo` | SunFounder Servo HAT+ boot-time configuration |

Never infer Robot HAT v4 from failed v5 discovery. Never activate both overlays: they configure overlapping
I2C, SPI, I2S, and audio resources. Overlay installation requires physical board verification followed by a
reviewed dry-run, reboot, and hardware acceptance.

## Installation behavior

The release installation includes the environment loader and two target
provisioning scripts:

```text
/usr/lib/xwalk/setup-rpi.sh
/usr/lib/xwalk/provision-hardware.sh
/usr/lib/xwalk/scripts/integration/shell-agent/env-tool/license/xWalkEnv.sh
/usr/lib/xwalk/scripts/integration/py-agent/dev-tool/xWalkLicenseTool
/usr/lib/xwalk/scripts/integration/shell-agent/env-tool/license/xWalkLicense.cfg
```

The cleanup, coverage, generator, and overlay files remain source-development assets. They are not
required by the installed CLI. Mutable runtime configuration remains under `/etc/xwalk` and `/var/lib/xwalk`,
not under this source directory.

## Safe verification

The following checks do not access physical hardware:

```sh
find scripts/integration/shell-agent -type f -name '*.sh' -print0 | xargs -0 bash -n
scripts/integration/shell-agent/repo-tool/clean-build.sh --dry-run
scripts/integration/shell-agent/quality-tool/run-host-coverage.sh --help
scripts/integration/shell-agent/deploy-tool/setup-rpi.sh --help
scripts/integration/shell-agent/deploy-tool/provision-hardware.sh --help
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarIwGenerator --help
bash scripts/integration/shell-agent/deploy-tool/test/setup-rpi-test.sh
bash scripts/integration/shell-agent/deploy-tool/test/environment-loader-test.sh
```

Do not run `setup-rpi.sh --apply`, direct overlay installation, hardware-labelled CTest targets, or actuator
commands during ordinary host verification.
