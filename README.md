# xWalk Raspberry Pi 5 PiCar-X

xWalk is a C++17 control and automation workspace for the SunFounder PiCar-X on Raspberry Pi 5. The repository
contains the complete product integration, host-safe simulation and tests, deployment configuration, documentation,
and development tooling.

Normal host builds use simulated or software backends and do not actuate physical hardware.

## Repository layout

```text
MyPiCarX/
├── xWalk-rpi5-hw/             Integrated Raspberry Pi 5 product
│   ├── CMakeLists.txt         Product build entry point
│   ├── CMakePresets.json      Supported host and Raspberry Pi build presets
│   ├── xWalkAgent/            Product behavior and feature agents
│   ├── xWalkAudioResources/   Versioned sound and music resources
│   ├── xWalkController/       CLI and application composition
│   ├── xWalkHal/              Hardware abstraction and simulation backends
│   ├── xWalkLibrary/          Shared libraries and external dependencies
│   ├── xWalkTrace/            Shared tracing implementation
│   └── cmake/                 Shared CMake modules and toolchains
├── devloper-note/             Developer documentation components
│   ├── gerrit-note/           Gerrit administration and CI documentation
│   └── xwalk-rpi5-note/       C++ architecture, build, and deployment documentation
├── xWalk-rpi5-iw/             Interface schemas and generated bindings
└── scripts/integration/           CI, Gerrit, deployment, quality, and maintenance tools
```

## Prerequisites

The supported host workflow requires Linux, CMake 3.25 or newer, Ninja, a C++17 compiler, Python 3, and the
development libraries used by the complete product.

On Ubuntu or Debian, install the core host dependencies with:

```bash
sudo apt-get update
sudo apt-get install build-essential cmake ninja-build pkg-config python3 libasound2-dev libcurl4-openssl-dev libprotobuf-dev libgrpc++-dev libgtest-dev libjson-c-dev libtinyxml2-dev libyaml-cpp-dev
```

See the [dependency guide](devloper-note/xwalk-rpi5-note/Doc/note/Dependency%20Installer%20Guide.md) for optional
quality tools, generators, Raspberry Pi packages, and dependency troubleshooting.

## Build the complete repository

Run all commands from the repository root. The `sanity` preset enables the complete Debug host build, tests,
compile commands, and strict compiler warnings. The preset is loaded from the `xWalk-rpi5-hw` product source tree.

```bash
cmake --fresh -S xWalk-rpi5-hw --preset sanity
cmake --build build-host/sanity --parallel
ctest --test-dir build-host/sanity --output-on-failure --no-tests=error
```

The generated files are written below `build-host/sanity`.

For an optimized host build:

```bash
cmake --fresh -S xWalk-rpi5-hw --preset host-release
cmake --build build-host/release --parallel
ctest --test-dir build-host/release --output-on-failure --no-tests=error
```

## Host-safe diagnostic

After building the `sanity` preset, validate the deployment configuration without opening hardware devices or
contacting external services:

```bash
build-host/sanity/xWalkController/xWalkApp/xwalk-picarx-control --deployment-config="$PWD/xWalk-rpi5-hw/xWalkController/xWalkConfig/picar-x.conf" --diagnose --no-hardware
```

The diagnostic must finish with `[SIMULATED]`. Do not remove `--no-hardware` during ordinary host validation.

## Installation

Create and test a staged Release installation without modifying the host system:

```bash
cmake --fresh -S xWalk-rpi5-hw --preset host-release
cmake --build build-host/release --parallel
DESTDIR="$PWD/build-host/deploy" cmake --install build-host/release
```

The staged filesystem is created under `build-host/deploy`. After reviewing that layout, an administrator may
install the same build into the configured `/usr` prefix:

```bash
sudo cmake --install build-host/release
```

System installation does not authorize hardware tests or actuator operation. Raspberry Pi setup, permissions,
services, configuration, and rollback are documented in the
[deployment guide](devloper-note/xwalk-rpi5-note/Doc/note/Deployment%20Guide.md).

## Raspberry Pi build

On a compatible Raspberry Pi build host, configure and compile the product with:

```bash
cmake --fresh -S xWalk-rpi5-hw --preset rpi-release
cmake --build build-rpi/cmake --parallel
ctest --test-dir build-rpi/cmake -N -L hardware
```

The RPi preset uses Robot HAT v4, runtime user `xwalk`, `/dev/gpiochip4`,
`/dev/i2c-1`, `/dev/spidev0.0`, and a CSI camera unless explicitly overridden
with the corresponding `XWALK_RPI_*` CMake cache value.

The final command lists hardware tests; it does not execute them. Run hardware-labelled tests only after explicitly
confirming the Raspberry Pi model, Robot HAT revision, wiring, power, clear movement area, and emergency-stop plan.

## Additional documentation

- [Open the published xWalk Developer Notes wiki](https://jochuuu.github.io/xWalkPiCarAI/)
- [C++ documentation index](devloper-note/xwalk-rpi5-note/index.md)
- [Build and open the developer-note wiki](devloper-note/README.md)
- [Build and installation guide](devloper-note/xwalk-rpi5-note/Doc/note/Installation.md)
- [Controller and CLI overview](xWalk-rpi5-hw/xWalkController/README.md)
- [Development and maintenance tools](scripts/integration/README.md)
- [Repository instructions](AGENTS.md)

## Run Gerrit and Gerrit CI

### Start the local Gerrit server

Load the repository Git environment once in each checkout. It configures the
repository-local Gerrit push transport so an ordinary `git push` starts the
Gerrit stack installed on the current machine before opening the Gerrit SSH
connection:

```bash
source xWalk-git-env.sh
```

On a personal workstation this starts its local Gerrit profile. On the college
host it starts that machine's managed Gerrit profile. A client without a local
Gerrit installation connects to its configured remote server without attempting
to manage that server. Set `XWALK_GIT_AUTO_START=false` in the machine-local Git
environment override to disable push-triggered startup.

Assess the local host before the first installation:

```bash
scripts/integration/py-agent/gerrit-tool/local-linux/gerrit-local.sh assess
```

Install and start a local Gerrit instance when it has not been installed previously:

```bash
scripts/integration/py-agent/gerrit-tool/local-linux/gerrit-local.sh install
```

Start an existing local Gerrit instance after a reboot or shutdown:

```bash
scripts/integration/py-agent/gerrit-tool/local-linux/gerrit-local.sh start
```

After installation, use the generated management commands to inspect and control the server:

```bash
"$HOME/bin/gerrit-status"
"$HOME/bin/gerrit-check"
"$HOME/bin/gerrit-logs"
"$HOME/bin/gerrit-stop"
"$HOME/bin/gerrit-start"
```

Print the configured browser URL:

```bash
git config --file "$HOME/gerrit-site/etc/gerrit.config" --get gerrit.canonicalWebUrl
```

The local profile normally exposes Gerrit SSH on port `29419`. Installation details and troubleshooting are in the
[local Gerrit guide](scripts/integration/py-agent/gerrit-tool/local-linux/README.md). Administrators operating the managed
server profile should use the separate [Gerrit administration guide](scripts/integration/py-agent/gerrit-tool/README.md).

### Run Gerrit Host Quality CI

The current local Gerrit integration uses the repository-owned Python event worker. It listens to Gerrit's SSH
event stream, checks each active patch set in an isolated checkout, runs the module-oriented Host Quality graph,
serves the existing `/ci/changes/<change>/<patch-set>` results page, and reports `Verified +1` or `Verified -1`.
Gerrit does not execute the GitHub Actions workflow.

Starting Gerrit does not start this worker. Start and inspect it separately:

```bash
"$HOME/bin/gerrit-ci-control" start
"$HOME/bin/gerrit-ci-control" status
"$HOME/bin/gerrit-ci-logs"
```

Verify the server-rendered dashboard health without exposing credentials:

```bash
curl --fail --show-error --silent --cacert "$HOME/gerrit-site/etc/gerrit-self-signed.crt" "https://192.168.1.158:18443/ci/health"
```

The worker configuration and least-privilege `xwalk-ci` SSH identity are administrator-owned. See the
[Gerrit CI configuration guide](devloper-note/gerrit-note/Doc/note/Gerrit%20CI%20Configuration.md)
for installation, module mapping, dashboard routes, `Verified` calculation, and restart instructions. The retained
`.zuul.yaml` is usable only if an administrator deliberately deploys Zuul; repository YAML does not install or
activate Zuul, and two CI backends must never vote on the same project.

After Gerrit and the selected CI worker are online, create a signed-off commit and upload an active patch set. The
upload triggers Host Quality automatically:

```bash
git add <files>
git commit -s
git push gerrit HEAD:refs/for/master
```

Upload work in progress without triggering CI by adding `%wip`:

```bash
git push gerrit HEAD:refs/for/master%wip
```

Selecting **Mark As Active** in Gerrit triggers CI for the current WIP patch set. CI does not submit a change.

Run representative repository-owned checks locally before uploading:

```bash
scripts/integration/shell-agent/gerrit-tool/run-host-ci-job.sh preparation
scripts/integration/shell-agent/gerrit-tool/run-host-ci-job.sh developer-note-wiki
scripts/integration/shell-agent/gerrit-tool/run-host-ci-job.sh deployment-scripts
scripts/integration/shell-agent/gerrit-tool/run-host-ci-job.sh build-and-test gcc Debug
```

These checks are host-safe and do not authorize physical hardware tests.

## License

See [LICENSE](LICENSE) for the repository license terms.
