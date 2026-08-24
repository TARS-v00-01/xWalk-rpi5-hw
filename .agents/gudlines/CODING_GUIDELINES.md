# xWalk HAL Coding Guidelines

## Purpose and authority

This guide records the conventions already established in `xWalk-rpi5-hw/xWalkLibrary/common`,
`xWalkI2c`, `xWalkPwm`, and `xWalkServo`. Apply it to new code and to code changed during
maintenance. Preserve the surrounding file's local style when it differs, but
do not copy accidental inconsistencies such as trailing whitespace or uneven
indentation.

These guidelines describe the current project rather than a generic C++ style.
If a deliberate architectural or project-wide convention changes, update this
file in the same change. Do not rewrite the guide merely to justify a one-off
exception.

## Change publication workflow

Gerrit is the sole review and publication entry point for repository changes.
After implementation and host verification, commit the code locally and upload
the commit only to Gerrit:

```bash
git push origin HEAD:refs/for/master
```

Active patch-set uploads trigger Gerrit CI automatically. When verification
must be deferred, upload the change as WIP:

```bash
git push origin HEAD:refs/for/master%wip
```

Source `xWalk-git-env.sh` once per checkout to install the repository-local
Gerrit push transport. With `XWALK_GIT_AUTO_START=true`, every ordinary Gerrit
push starts the server stack installed on the current machine before SSH:
personal workstations start their local profile, the college host starts its
managed profile, and clients without a local installation connect to the
configured remote endpoint without attempting remote service management.

For a WIP change, use Gerrit's **Mark As Active** button as the Activate action.
The WIP-to-active transition triggers CI for the current patch set. Moving an
active change into WIP does not trigger CI.

Never push a component change to GitHub. GitHub contains only the configured
integrated repository. During migration, `xWalkPiCarAI/master` is the active
integration branch; the final target is `xWalk-rpi5-hw/master`. A Gerrit change may
be submitted only after its current patch set satisfies the configured review
and automatic verification requirements. The dedicated synchronization
service may fast-forward only the exact submitted, approved, CI-verified
integration revision to the matching GitHub branch.

Every component Gerrit patch set must use a module-scoped Host Quality graph containing Preparation, only the
reviewed component's checks, and the Host Quality Gate. Do not execute unrelated module suites in a component
review. Dependency checkout may initialize exact pinned integration gitlinks needed by the selected component's
standalone build, but that does not authorize their quality suites. Automatic CI must remain host-safe and must
not select hardware-labelled tests.

Every submitted component change must enter `xWalkPiCarAI/master` through a
separate uplift review that replaces only the owning module source tree. The
active uplift patch set runs the complete integrated CI graph. Submission
requires the CI account's `Verified +1`, an authorized `Code-Review +2`, no
unresolved blocking comments, a current mergeable patch set, and Gerrit's
complete submit policy. Only the exact resulting merged commit may be
synchronized to the configured GitHub `xWalkPiCarAI/master` branch.

## Language and compiler expectations

- Write C++17. Declare `cxx_std_17` on every public library target that needs to
  propagate this requirement.
- Keep code warning-clean with GCC and Clang under `-Wall`, `-Wextra`,
  `-Wpedantic`, `-Wconversion`, and `-Wsign-conversion`.
- Use the fixed project types from `xHal_Rpi5CarTypes.h`, such as `boolean`,
  `uint8`, `uint16`, `uint32`, `int32`, `float64`, and `size`, instead of adding
  unrelated spellings throughout the modules.
- Qualify shared types through the owning layer's concise namespace: `hal::`
  in xWalkHal, `agent::` in xWalkAgent, and `ctrl::` in xWalkController. The
  common type header exports the same underlying generic aliases into
  `xwalk::hal`, `xwalk::agent`, and `xwalk::controller`; do not use `hal::int32`
  or another HAL-qualified generic alias from Agent or Controller code.
- Declare every reusable standard-library data type behind a documented alias
  in `xWalk-rpi5-hw/xWalkLibrary/common/xHal_Rpi5CarTypes.h`. Production modules and tests use
  the project alias instead of spelling the standard type directly. This
  includes containers, exceptions, streams, filesystem paths and metadata,
  synchronization types, and error codes.
- Put module-specific aggregate aliases and their related data structures in a
  documented type header under that submodule's `include` directory. For
  example, LineTracker fixed arrays, its non-owning ADC-pointer array, and
  `XWalkLineCalibration` belong in `xHal_Rpi5CarLineTrackerTypes.h`.
- Direct `std::` qualification remains appropriate for standard functions,
  algorithms, namespace constants, and the underlying type on the right side
  of an alias declared in `xWalk-rpi5-hw/xWalkLibrary/common`. Doxygen `@throws` fields use the real
  standard exception name presented to API callers, except where a public
  project exception alias such as `filesystemerror` is part of the interface.
- Make narrowing and signed/unsigned conversions explicit with `static_cast`.
- Break multi-stage hardware calculations into named `const` intermediate
  values. Convert constants and integer operands explicitly to the calculation
  type before arithmetic, and keep one conceptual multiplication or division
  per assignment. Name derived divisors and ratios so units and formula intent
  remain reviewable.
- Add an unsigned suffix to unsigned integer constants where conversion matters,
  for example `8U`, `0xFFU`, and `72'000'000.0`.
- Use `nullptr`, `noexcept`, `const`, and value initialization (`{}`) whenever
  their guarantees apply.
- Keep assertions enabled in every host verification configuration, including
  Release. New tests evaluate state-changing operations before asserting their
  results so static analysis and reviewers can see both the action and check.
- Use `xwalk::hal::test::requireTestCondition()` for legacy and standalone test
  requirements that must remain active when a non-host Release configuration
  defines `NDEBUG`. Do not retain a value that becomes unused only because a
  required test check was compiled out.

## Project structure

Keep each C++ module independently configurable with its own `CMakeLists.txt`
and README. The `xWalk-rpi5-hw/CMakeLists.txt` product entry point composes every
HAL module and
maps the `XWALK_HAL_BUILD_HOST` and `XWALK_HAL_BUILD_RPI` flags to module
verification options. The `xWalkHal` directory intentionally has no aggregate
`CMakeLists.txt`. Both aggregate flags default to `OFF` and must not be enabled
in the same build directory. The default aggregate build contains production
libraries only. A host build must register every submodule host and unit test so plain
`ctest` runs the complete host suite. An RPI build must register every submodule
hardware test so plain `ctest` runs the complete hardware suite after deployment
and safety approval. The `Doc` directory has no build system. Use the existing
layout:

```text
.vscode/                     workspace configuration for HAL and CLI
xWalk-rpi5-hw/.project                     Eclipse CDT product and host-build configuration
xWalk-rpi5-hw/.cproject                    Eclipse CDT C++17 indexing and include-path configuration
xWalk-rpi5-hw/.settings/                   Eclipse CDT project preferences
xWalk-rpi5-hw/eclipse-build.sh             Eclipse CDT host-build helper
xWalk-rpi5-hw/<component>/.project         independently importable Eclipse component loader
xWalk-rpi5-hw/<component>/.cproject        C/C++ component indexing configuration when applicable
devloper-note/xwalk-rpi5-note/Doc/note/ C++ Markdown documentation mirroring upstream pages
devloper-note/xwalk-rpi5-note/index.md  C++ architecture and module documentation index
devloper-note/gerrit-note/              Gerrit administration and CI documentation
devloper-note/mkdocs.yml                searchable developer-note wiki configuration
Doc/image/                   hardware and project images referenced by documentation
xWalk-rpi5-tool/                   independently reviewed Gerrit tooling component uplifted at the integration root
xWalk-rpi5-tool/cpp-tool/          grouped C++ quality probes, fuzz harnesses, corpora, and documentation
xWalk-rpi5-tool/cpp-tool/fuzz/     C++ fuzz harnesses and seed corpora
xWalk-rpi5-tool/cpp-tool/quality/  host quality documentation and sanitizer availability probes
xWalk-rpi5-tool/doc-tool/          developer-note wiki launch, verification, and dependency tooling
xWalk-rpi5-tool/py-agent/          grouped Python development, board-integration, and Gerrit administration tooling
xWalk-rpi5-tool/py-agent/board-tool/ host-only board tooling with the importer package under py-src/xWalkJiraImport
xWalk-rpi5-tool/py-agent/dev-tool/ executable dependency, interface-generation, licence utilities, and host tests
xWalk-rpi5-tool/py-agent/gerrit-tool/   Gerrit server, CI, review-control, and multi-repository administration tooling
xWalk-rpi5-tool/shell-agent/       host-safe repository automation and configuration
xWalk-rpi5-tool/shell-agent/jira-tool/ source launcher for the Jira importer
xWalk-rpi5-tool/shell-agent/gerrit-tool/ Gerrit and GitHub Host Quality dispatch and metadata checks
xWalk-rpi5-tool/shell-agent/deploy-tool/ provisioning, packaging assets, and deployment tests
xWalk-rpi5-tool/shell-agent/env-tool/ grouped environment assets and configuration
xWalk-rpi5-tool/shell-agent/env-tool/dtoverlays/ reviewed Raspberry Pi boot overlay blobs
xWalk-rpi5-tool/shell-agent/env-tool/license/ model template and authenticated environment loader
xWalk-rpi5-tool/shell-agent/env-tool/playbooks/ repository-controlled Zuul Ansible playbooks
xWalk-rpi5-tool/shell-agent/env-tool/quality/ Clang-Tidy, Cppcheck, and gcovr configuration
xWalk-rpi5-tool/shell-agent/quality-tool/ host quality, sanitizer, coverage, and analysis runners
xWalk-rpi5-tool/shell-agent/repo-tool/ repository maintenance utilities
xWalk-rpi5-hw/xWalkAgent/                  application coordinators composed from caller-owned HAL objects
xWalk-rpi5-hw/xWalkAgent/xWalkVehicle/     movement and autonomous-response Agent group
xWalk-rpi5-hw/xWalkAgent/xWalkVehicle/xWalkPicarx/ complete PiCar-X movement and sensing coordinator
xWalk-rpi5-hw/xWalkAgent/xWalkVehicle/xWalkLineTracking/ bounded grayscale line following
xWalk-rpi5-hw/xWalkAgent/xWalkVehicle/xWalkMoveExample/ bounded movement example
xWalk-rpi5-hw/xWalkAgent/xWalkVehicle/xWalkKeyboardControl/ keyboard-driven movement coordination
xWalk-rpi5-hw/xWalkAgent/xWalkVehicle/xWalkObstacleAvoidance/ ultrasonic movement decisions
xWalk-rpi5-hw/xWalkAgent/xWalkVehicle/xWalkCliffDetection/ grayscale cliff-response state machine
xWalk-rpi5-hw/xWalkAgent/xWalkVehicle/xWalkSelfDrive/ preset gestures, sounds, and action flow
xWalk-rpi5-hw/xWalkAgent/xWalkCalibration/ sensor, servo, and motor calibration Agent group
xWalk-rpi5-hw/xWalkAgent/xWalkCalibration/xWalkGrayscaleCalibration/ grayscale reference calibration
xWalk-rpi5-hw/xWalkAgent/xWalkCalibration/xWalkServoMotorCalibration/ servo and motor calibration
xWalk-rpi5-hw/xWalkAgent/xWalkCalibration/xWalkServoZeroing/ ordered Robot HAT servo zeroing
xWalk-rpi5-hw/xWalkAgent/xWalkVision/      camera, detection, tracking, and video Agent group
xWalk-rpi5-hw/xWalkAgent/xWalkVision/xWalkComputerVision/ color, face, QR, and photograph coordination
xWalk-rpi5-hw/xWalkAgent/xWalkVision/xWalkFaceTracking/ face-to-camera-servo coordination
xWalk-rpi5-hw/xWalkAgent/xWalkVision/xWalkBullFight/ red-target pursuit coordination
xWalk-rpi5-hw/xWalkAgent/xWalkVision/xWalkTreasureHunt/ color driving and spoken-prompt coordination
xWalk-rpi5-hw/xWalkAgent/xWalkVision/xWalkVideoRecording/ continuous OpenCV AVI coordination
xWalk-rpi5-hw/xWalkAgent/xWalkVision/xWalkVideoCar/ camera-assisted driving coordination
xWalk-rpi5-hw/xWalkAgent/xWalkVision/xWalkCameraCapture/ camera-to-voice image callback adaptation
xWalk-rpi5-hw/xWalkAgent/xWalkMedia/       sound and music Agent group
xWalk-rpi5-hw/xWalkAgent/xWalkMedia/xWalkSoundBackgroundMusic/ sound and background music coordination
xWalk-rpi5-hw/xWalkAgent/xWalkVoice/       speech and conversational Agent group
xWalk-rpi5-hw/xWalkAgent/xWalkVoice/xWalkLocalVoiceChatbot/ local voice-assistant loop
xWalk-rpi5-hw/xWalkAgent/xWalkVoice/xWalkVoicePromptCar/ spoken movement demonstration
xWalk-rpi5-hw/xWalkAgent/xWalkVoice/xWalkStorytellingRobot/ narrated movement sequence
xWalk-rpi5-hw/xWalkAgent/xWalkVoice/xWalkVoiceControlledCar/ Vosk wake-word movement commands
xWalk-rpi5-hw/xWalkAgent/xWalkVoice/xWalkTextVisionTalk/ image-grounded Ollama conversation
xWalk-rpi5-hw/xWalkAgent/xWalkVoice/xWalkOnlineLlmTest/ OpenAI-compatible text conversation
xWalk-rpi5-hw/xWalkAgent/xWalkVoice/xWalkVoiceActiveCar/ sensor-aware Rolly voice car
xWalk-rpi5-hw/xWalkAgent/xWalkVoice/xWalkVoiceActiveCarGpt/ English GPT Buddy voice car
xWalk-rpi5-hw/xWalkAgent/xWalkVoice/xWalkGptCar/ upstream GPT PiCar-X assistant
xWalk-rpi5-hw/xWalkAgent/xWalkConnectivity/ external-control and transaction Agent group
xWalk-rpi5-hw/xWalkAgent/xWalkConnectivity/xWalkAppControl/ mobile-app vehicle coordination
xWalk-rpi5-hw/xWalkAgent/xWalkConnectivity/xWalkSpiTransfer/ bounded SPI transaction coordination
xWalk-rpi5-hw/xWalkAgent/xWalkPlatform/    process composition Agent group
xWalk-rpi5-hw/xWalkAgent/xWalkPlatform/xWalkBoot/ host-stub and Raspberry Pi process composition
xWalk-rpi5-hw/xWalkController/             standalone command-line aggregate that imports xWalkAgent
xWalk-rpi5-hw/xWalkController/xWalkConfig/ layered controller deployment and calibration configuration
xWalk-rpi5-hw/xWalkController/xWalkHandler/ typed handler implementation and direct host test
xWalk-rpi5-hw/xWalkController/xWalkApp/     command parsing, entry points, generated help, and application tests
xWalk-rpi5-hw/xWalkController/xWalkTest/xGoogleTest/ centralized CLI host-test runner and XML selection
xWalk-rpi5-hw/xWalkController/xWalkTest/xSequenceTest/ bounded CLI command-sequence verification
xWalk-rpi5-hw/xWalkAudioResources/music/   packaged background-music resources
xWalk-rpi5-hw/xWalkAudioResources/sounds/  packaged sound-effect resources
xWalk-rpi5-iw/                     I2C and Controller Protobuf DTOs and gRPC interface definitions
xWalk-rpi5-hw/xWalkLibrary/                common public headers, portable dependencies, models, and native assets
xWalk-rpi5-hw/xWalkLibrary/common/         common interface target, headers, configuration, and documentation
xWalk-rpi5-hw/CMakeLists.txt    product and HAL aggregate build
xWalk-rpi5-hw/xWalkHal/interface/          low-level platform interfaces and common services
xWalk-rpi5-hw/xWalkHal/device/             hardware device abstractions
xWalk-rpi5-hw/xWalkHal/sensor/             sensor and actuator components
xWalk-rpi5-hw/xWalkHal/layer1/             higher-level robot services and features
xWalk-rpi5-hw/xWalkHal/layer1/xWalkBoardControl/ board control, discovery, and firmware information
xWalk-rpi5-hw/xWalkHal/sensor/xWalkBuzzer/ active GPIO and passive PWM buzzer control
xWalk-rpi5-hw/xWalkHal/device/xWalkCamera/ backend-neutral capture plus Linux CSI and USB providers
xWalk-rpi5-hw/xWalkHal/interface/xWalkConfig/ section-aware and flat key-value configuration persistence
xWalk-rpi5-hw/xWalkHal/layer1/xWalkGPT/    speech coordination plus Linux Vosk and Espeak providers
xWalk-rpi5-hw/xWalkHal/sensor/xWalkLed/    GPIO and three-channel PWM LED control
xWalk-rpi5-hw/xWalkHal/interface/xWalkLanguageModel/ provider-neutral conversation and prompting control
xWalk-rpi5-hw/xWalkHal/interface/xWalkWebSearch/ bounded loopback SearXNG retrieval and sanitization
xWalk-rpi5-hw/xWalkHal/layer1/xWalkMusic/  music theory, PCM tone, and injected audio control
xWalk-rpi5-hw/xWalkHal/layer1/xWalkRobot/  coordinated multi-servo robot control
xWalk-rpi5-hw/xWalkHal/layer1/xWalkSpeaker/ bounded asynchronous audio-file playback control
xWalk-rpi5-hw/xWalkTrace/                  filtered callback-based embedded diagnostics
xWalk-rpi5-hw/xWalkHal/device/xWalkUserButton/ active-low button events and press timing
xWalk-rpi5-hw/xWalkHal/device/xWalkUltrasonic/ two-pin ultrasonic distance measurement
xWalk-rpi5-hw/xWalkHal/interface/xWalkUtils/ injected platform utilities and bounded lazy caching
xWalk-rpi5-hw/xWalkHal/layer1/xWalkVoiceAssistant/ synchronous speech, model, and response coordination
xWalk-rpi5-hw/xWalkHal/sensor/xWalkLineTracker/ grayscale sensing and line-position estimation
xWalk-rpi5-hw/xWalkHal/device/xWalkAdc/    Robot HAT analog-to-digital converter module
xWalk-rpi5-hw/xWalkHal/interface/xWalkAudio/ shared ALSA PCM and mixer ownership
xWalk-rpi5-hw/xWalkHal/interface/xWalkGpio/ Robot HAT digital GPIO module and Linux backend
xWalk-rpi5-hw/xWalkHal/interface/xWalkSpi/ bounded callback-driven SPI and Linux spidev backend
xWalk-rpi5-hw/xWalkHal/sensor/xWalkMotor/  single and paired Robot HAT motor control
xWalk-rpi5-hw/xWalkHal/<Group>/xWalk<Module>/include/ public module headers
xWalk-rpi5-hw/xWalkHal/<Group>/xWalk<Module>/src/ hardware-independent implementation
xWalk-rpi5-hw/xWalkHal/<Group>/xWalk<Module>/test/ host-side tests and test helpers
xWalk-rpi5-hw/xWalkHal/<Group>/xWalk<Module>/hardware/ optional platform backend and hardware tests
xWalk-rpi5-hw/xWalkHal/xWalkTest/xGoogleTest/ centralized HAL host/hardware runner and XML selection
xWalk-rpi5-hw/xWalkHal/xWalkTest/xExample/ centralized ported examples with core and hardware layers
xWalk-rpi5-hw/xWalkHal/xWalkTest/xSequenceTest/ bounded opt-in sequence and integration tests
```

For a module with `core` and `hardware` layers, keep the hardware-independent
interface under `core/` and Linux-specific ownership and system calls under
`hardware/`.

Split implementation files by responsibility rather than allowing one source
file to grow indefinitely. Follow the established suffixes:

- `xHal_Rpi5Car<Component>.cpp` for normal behavior.
- `xHal_Rpi5Car<Component>Lifecycle.cpp` for constructors and destructors.
- A descriptive suffix such as `Timer`, `Output`, or `Validation` for a cohesive
  behavior group.
- The same responsibility-based split for test files.

Keep every xWalk Controller `XWALK_handler<CommandOrModuleName>` member in its
own source file under the `xWalkHandler/src` functionality directory that owns
the command: `vehicle`, `vision`, `voice`, `media`, `connectivity`,
`calibration`, or `platform`. Keep shared cancellation support under `common`
and lifecycle in the root `xWalkHandler/src` directory. Keep CLI-to-request
parsing and shared Controller output formatting in `xWalkApp/parse/src`. Keep
top-level and PiCar-X Controller command routing as documented free functions
under `xWalkApp/activate/include` and `xWalkApp/activate/src`; grant only those application
routers friend access rather than making protected handlers public. List every
source explicitly in the `xWalkController` CMake target.

Whenever files are added, update the module tree and responsibility table in
its README.

Keep AddressSanitizer/UndefinedBehaviorSanitizer, leak-enabled verification,
ThreadSanitizer, GCC coverage, and Clang coverage in separate host build
directories. Never combine TSan with another sanitizer or coverage in one
executable. Verify LSan and TSan availability with the dedicated negative
probes, and classify runtime initialization failures as environment blocks
rather than passes. Use the GCC sanitizer runtime for LSan and TSan on the
reviewed Ubuntu host. Run TSan probe and test processes with per-process ASLR
disabled through `setarch -R`; never change the host-wide kernel ASLR setting.
Use the root presets for repeat-under-load host verification so a failure stops
the bounded repetition immediately.

Keep GitHub and Gerrit/Zuul Host Quality behavior aligned through
`xWalk-rpi5-tool/shell-agent/gerrit-tool/run-host-ci-job.sh`. GitHub retains its workflow under
`.github/workflows`, while Gerrit uses repository-controlled `.zuul.yaml` jobs
and Ansible playbooks. Use `dependencies:` for Zuul execution ordering;
`parent:` remains limited to job inheritance. Keep every CI job device-free and
retain the controller's `--diagnose --no-hardware` validation.

Keep HAL unit-test implementations in each owning module's existing `test/`
tree. The central `xGoogleTest` target may compile those sources and adapt
legacy entry points, but it must contain only common runner code, use one
central `main()`, list sources explicitly, and remain disabled with
`BUILD_TESTING=OFF`. Physical hardware executables stay separate, use a
separate disabled-by-default XML profile, and require explicit runtime
selection.

Keep cross-module HAL interaction tests below each architectural group's
`test` directory. Give interface, device, sensor, and layer1 one
GoogleTest/GoogleMock executable each, register the executable with CTest, and
apply the owning `<group>-group` label plus `group-tests` and
`host`. Compose real production coordinators over deterministic caller-owned
fakes, keep build-local file fixtures isolated per target, and do not replace
or invoke physical hardware from these suites.

Sequence tests that observe or manipulate physical hardware must use a bounded
runtime, carry the CTest `hardware;sequence` labels, and remain disabled in the
hardware XML profile until explicitly selected. Keep reusable, host-testable
logic under `core/include` and `core/src`; keep platform adapters and physical
implementations under `hardware/include` and `hardware/src`. Keep the single
sequence-runner process entry point at `xWalk-rpi5-hw/xWalkHal/xWalkTest/xSequenceTest/main.cpp`.
Keep CLI usage, argument validation, and selector dispatch in the dedicated
hardware-layer `XWalkSequenceTestRunner`; `main.cpp` only delegates to it.

Port upstream example programs under `xWalk-rpi5-hw/xWalkHal/xWalkTest/xExample`, keeping reusable
behavior in `core` and Raspberry Pi composition in `hardware`. Keep its only
process entry point at `xWalk-rpi5-hw/xWalkHal/xWalkTest/xExample/main.cpp`; individual example
sources must not define `main()`. Add only real supplied examples. Select them
through the `xExample` executable using their formal selector names. Keep
default board, AI, and bounded selector arguments in the module YAML file and
accept an explicit YAML-path override; validated positional arguments remain a
compatibility override. Do not add xExample XML manifests, CTest registrations,
or xGoogleTest inventory entries. Keep CLI usage, argument validation,
environment lookup, and selector dispatch in the hardware-layer
`XWalkExampleRunner`; `main.cpp` only delegates to it. Place example contracts
and adapters in `namespace xwalk::hal::example`; reserve
`namespace xwalk::hal::test` for test implementations.

Keep reviewed portable third-party dependencies and offline AI runtime assets under the root-level
`xWalkLibrary`. Store the workspace-wide common public headers, architecture-independent models, and
configuration directly under `common`; keep the `xWalkLibraryCommon` interface target, its CMake definition,
and module documentation in `xWalk-rpi5-hw/xWalkLibrary/common`. Store native `bin`, `include`, `lib`, and
`share` content under an explicit `x86_64` or `aarch64` prefix. Record the upstream version, architecture,
source URL, checksum, license, and runtime path in that directory.
Architecture-specific native libraries must never be loaded by a mismatched target. Let
`XWalkDependencies.cmake` select the target prefix, prefer it through `CMAKE_PREFIX_PATH`, retain normal
system discovery as the fallback for unbundled portable libraries, and add its native library directories
to the build-tree RPATH. Keep compilers, build tools, kernel interfaces, ALSA integration, udev rules,
camera tools, Device Tree overlays, services, and package utilities system-managed. Generate absolute
deployment paths into build-local configuration so execution does not depend on the current working
directory. Do not modify third-party model or binary contents locally.

When an application path macro is supplied by CMake but its source is also
parsed outside that target, declare a guarded non-CMake default in the owning
configuration header. CMake target definitions remain authoritative. Mirror
test-only resource macros in supported editor configurations rather than adding
runtime fallbacks that could hide a missing test-target definition.

Name handwritten project YAML configuration files
`xHal_Rpi5Car<Component>Config.yml`, where `<Component>` matches the owning
module or runner, such as `Example`, `GoogleTest`, or `SequenceTest`. Keep
generated copies under the same filename so runtime diagnostics and deployment
instructions identify one stable configuration artifact.

Keep generated Protobuf and gRPC sources under the owning module's `auto-gen`
tree. Regenerate them from reviewed schemas, never edit them by hand, and
exclude them from handwritten-source coverage and static-analysis gates while
retaining normal compiler warnings and compilation checks.

Define every xWalk-rpi5-iw request, confirmation, and rejection signal through the
typed `XWalkSignalNumber` Protobuf enumeration. Name its values
`CXX_XWALK_<SHORT_NAME>_REQ`, `CXX_XWALK_<SHORT_NAME>_CFM`, or
`CXX_XWALK_<SHORT_NAME>_REJ`, bind messages through the `(cxx_signal)` option,
and keep each numeric value synchronized with the matching XML signal registry.
Do not repeat numeric signal literals in message option declarations. A
transport-only diagnostic that is not routed as a request counterpart, such as
`XWalkTraceRej`, must omit `(cxx_signal)` and be validated separately from the
request, confirmation, and rejection XML registries. Keep its
`XWalkErrorSignalNumber` Protobuf selector values synchronized with the
trace-owned C++ enumeration in `xHal_Rpi5CarErrorSignals.h`; these stable
transport values must not depend on platform POSIX signal numbers.

## Files and naming

- Name HAL headers and sources `xHal_Rpi5Car<Component>.h` and
  `xHal_Rpi5Car<Component>.cpp`. Name Controller-owned files
  `xController<Component>.h` and `xController<Component>.cpp`; omit the
  redundant `Agent`, `Rpi5Car`, and repeated `Controller` words.
- Define every project class and structure in a header; never define a type in
  a `.cpp`, `.cc`, or `.cxx` source file. Source files contain member-function
  implementations and may declare objects of existing types, including C-style
  declarations such as `struct stat pathStatus`.
- Keep at most one class definition in each physical header. Give each
  additional class its own consistently named file and include that file
  explicitly wherever the class is used. Supporting enums and structures may
  remain with the single class that owns their contract.
- Put every project-owned header under the owning scope's `include` directory;
  never place a `.h`, `.hpp`, or `.hxx` file under `src`. This applies to public,
  private, test, hardware, simulation, and example headers. Put an
  implementation-private type in a narrowly scoped companion type header with
  a named namespace and expose that directory only to the targets that require
  it. Never use an anonymous namespace in a header. For test fixtures, fake
  state, mappings, callbacks, and factories, follow the repository-wide
  `<Component>TestSupport.h` layout instead.
- Use include guards derived from the file name:

  ```cpp
  #ifndef XHAL_RPI5CAR_COMPONENT_H
  #define XHAL_RPI5CAR_COMPONENT_H

  // Declarations.

  #endif  // XHAL_RPI5CAR_COMPONENT_H
  ```

- Put production declarations in `namespace xwalk::hal`. Put tests in
  `namespace xwalk::hal::test`. End a namespace with a named comment.
- Put every non-member production function in `xWalk-rpi5-hw/xWalkLibrary/common` under
  `namespace xwalk::hal::common`. Call it with the `common::` qualifier from a
  module, except the file facilities described below, which live directly in
  `xwalk::hal`. Do not add anonymous or module-local free production helpers.
  Class-specific behavior remains a method on its owning class. Test scenarios,
  test-only callbacks, and the required global `main()` stay with their tests.
- Keep application entry functions that dispatch a configured `XWalkController`
  and return its generated usage text under `xWalkApp`; these functions are the
  Controller-specific exception to the reusable common-library free-function
  rule and remain in `namespace xwalk::ctrl`. Because the Controller namespace
  has the same short name as the global `ctrl` namespace
  alias, qualify shared Controller primitive types as `::ctrl::*` inside it.
- Keep process-argument and global-option parsing shared in
  `xControllerApplicationArguments.cpp` for host and Raspberry Pi application
  targets. Keep each other application command free function in its own
  responsibility-focused file in the appropriate `xWalkApp` group.
  Never place a function call, member-function call, callback invocation, or
  function-like macro invocation directly in an `if` or `while` condition.
  Evaluate the complete decision expression first and assign its result to a
  clearly named Boolean variable before entering the control-flow statement.
  This rule also applies to pure queries such as `empty()`,
  `size()`, `isfinite()`, and file-state predicates. Keep the `if` or `while`
  condition limited to variables, literals, casts, and operators. For a
  `while`, refresh the named condition at the top of every iteration so
  `continue` preserves condition re-evaluation. Use the owning layer's
  `boolean` alias and an explicit `== false` failure check where applicable.
  Validate the complete project-owned source tree with
  `python3 xWalk-rpi5-tool/py-agent/dev-tool/xWalkConditionCheck xWalk-rpi5-hw`.
  Host `main()` delegates to the shared host application function. Raspberry Pi
  `main()` consumes the same parsed argument structure and retains only signal
  setup, resource validation, boot selection, and hardware composition.
- Put reusable filesystem operations in
  `xWalk-rpi5-hw/xWalkLibrary/common/xHal_Rpi5CarFileFunctions.h`. Production modules and
  tests call these functions directly through `xwalk::hal`, matching project
  types such as `uint32`; do not place file facilities in a nested `common`
  namespace. Keep filesystem data types behind the aliases declared in
  `xHal_Rpi5CarTypes.h`.
- Keep file stream modes and filesystem operation options behind common typed
  constants. Use `FILE_OPEN_WRITE_TRUNCATE` and `FILE_PERMISSION_REPLACE`
  instead of spelling `std::ios` or
  `std::filesystem::perm_options` outside `xWalk-rpi5-hw/xWalkLibrary/common`. Use
  `readFileLine()` instead of calling `std::getline` on a file stream
  from a module.
- Use `FILE_OPEN_READ_BINARY` and `readFileContents()` when binary property data
  can contain terminal null bytes. Use `listFilesystemEntryNames()` for direct
  child enumeration rather than exposing filesystem iterators to a module.
- Name classes in PascalCase with the `XWalk` prefix, for example `XWalkI2c` and
  `XWalkPwmTimerState`.
- Name functions and local variables in lower camel case: `setPulseWidth`,
  `timerIndex`, and `requestedAddress`.
- Name local Boolean predicates for their domain meaning and true-state polarity,
  such as `optionValueMissing`, `operationMayContinue`, or `frameReadyToWrite`.
  Do not derive predicate names from source locations or use placeholders such
  as `conditionResult`, `conditionMet`, or `predicate`.
- Name stored scalar members with a descriptive `Value` suffix when it
  distinguishes state from a similarly named accessor or parameter:
  `addressValue`, `channelValue`, and `frequencyHzValue`.
- Keep project type aliases lowercase, following `bytevector`,
  `optionaluint8`, `filesystempath`, and `pwmtimerstatepointer`.
- Prefix public preprocessor constants and function-like macros with
  `XHAL_RPI5CAR_` or the narrower established `XHAL_` prefix. Use uppercase
  snake case.
- Use explicit units in names when a value could otherwise be ambiguous, such
  as `frequencyHz`, `pwmClockHz`, and `pulseWidthPercentValue`.

## Formatting

- Indent with four spaces for each indentation level; never use tabs. Indent
  every nested namespace, class, structure, function, method, condition, loop,
  switch, and other block.
- Indent `public:`, `protected:`, and `private:` inside their class. Indent class
  members four additional spaces beneath their access specifier.
- Limit every line in `.cpp`, `.cc`, `.cxx`, `.h`, `.hpp`, and `.hxx` files to
  120 characters. Wrap longer declarations, function calls, conditions,
  expressions, strings, and comments with continued indentation.
- Limit every line in CMake files and repository documentation to 115
  characters, except complete shell commands inside fenced Markdown code
  blocks. Wrap any other line that would exceed this limit.
- Count leading indentation and all other characters when measuring a line. Do
  not wrap a C++ statement, declaration, condition, call, or expression when
  the complete construct fits within 120 characters. When wrapping is required,
  keep as much of the construct as practical on each line without exceeding its
  applicable limit.
  In `.md` files only, keep each fenced shell-command example on one physical
  line without a continuation backslash. A complete command in such a block may
  exceed 115 characters when required to preserve its one-line form.
- Use Allman braces for namespaces, classes, structures, functions, methods,
  conditions, loops, switches, and every other block. Place each opening brace
  on the next line aligned with its block declaration. Align each closing brace
  with the corresponding opening brace, and indent the enclosed content by four
  additional spaces.
- Always use braces, including when a control-flow body contains only one
  statement. Never use a single-line block.
- Use the repository-root `.clang-format` for mechanical formatting. Exclude
  generated sources below `auto-gen` or `generated` directories and any
  vendored or third-party code from repository-wide formatting operations.
  This exclusion includes dependency-prefix headers below
  `xWalkLibrary/x86_64` and `xWalkLibrary/aarch64`.
- Before completing any C++ change, run the repository-owned formatter:

  ```bash
  xWalk-rpi5-tool/py-agent/dev-tool/styler-tool/xWalkStyler format
  ```

- Before submitting or merging any C++ change, run its non-mutating CI check:

  ```bash
  xWalk-rpi5-tool/py-agent/dev-tool/styler-tool/xWalkStyler check
  ```

  ```cpp
  namespace xwalk::hal
  {
      class XWalkExample
      {
          public:
              void update(const boolean enabled)
              {
                  if (enabled)
                  {
                      performUpdate();
                  }
              }
      };
  }
  ```

- Put one space after commas and around binary operators. Do not leave trailing
  whitespace.
- Keep related declarations together and separate logical groups with one blank
  line. Avoid repeated blank lines.
- In C++ protocol-mirrored enums and payload structures, place a complete
  multi-line Doxygen block before every enumerator and data member. Use the same
  `/**`, `@brief`, optional non-empty `@details`, and `*/` form used for function
  contracts. Do not use trailing `/**< ... */` comments or single-line
  `/** @brief ... */` comments for these C++ declarations.
- In Protocol Buffer schemas, place a multi-line Doxygen block with `@brief` and
  useful `@details` immediately above every message, enum, and service. Document
  every message field, enum value, and RPC declaration with a same-line `//@@`
  comment after its semicolon. Do not use a Doxygen block for those members.
- Wrap long parameter lists and expressions onto continuation lines. Align for
  readability without depending on tabs.
- Use aligned assignments only for a short, closely related block when it makes
  comparisons clearer.
- Keep small, unambiguous read-only accessors inline in the header. Put behavior,
  validation, locking, I/O, and non-trivial calculations in a source file.
- Prefer direct, compact comments that explain a constraint, compatibility
  choice, hardware behavior, or ownership decision. Do not narrate obvious code.
- Give every member-function definition in a `.cpp` file a complete
  Doxygen-compatible contract, even when its header declaration is already
  documented. Keep both contracts consistent as required by
  `DOCUMENTATION_GUIDELINES.md`.

## Headers and dependencies

- Include a source file's matching public header first.
- Add a blank line before additional project headers when they form a separate
  dependency group.
- Include project headers by their public basename, for example
  `#include "xHal_Rpi5CarPwm.h"`; let CMake provide include directories.
- Keep standard-library headers centralized in
  `xHal_Rpi5CarStandardHeaders.h`. Module code includes its project header and
  normally does not add direct standard-library includes.
- Directly include a standard header in a translation unit when that header is
  required to complete an implementation-only type and relying on a transitive
  include produces an incomplete-type diagnostic. Keep the matching project
  header first, then add a separate standard-header group. For example, a file
  that instantiates `std::ifstream` or `std::ofstream` includes `<fstream>`;
  `<iosfwd>` and the stream declarations exposed by `<filesystem>` are not
  complete definitions.
- Include `<filesystem>` directly in every public header that exposes or stores
  a `std::filesystem` type and in every translation unit that calls filesystem
  operations. Do not rely on another standard header to expose filesystem
  declarations transitively.
- Keep Linux-only headers centralized in `xHal_Rpi5CarLinuxHeaders.h` and out of
  hardware-independent source.
- Expose reusable standard operations through the existing common facilities.
  Use the `XHAL_*` math macros instead of introducing direct `std::` calls
  throughout module code. Controller, Agent, and HAL code use their exception
  type and string aliases after emitting the corresponding component error
  trace.
- Avoid unnecessary transitive coupling. Link each CMake target publicly only
  to dependencies used by its public interface; keep implementation-only and
  test dependencies private.

### VS Code IntelliSense configuration

- Treat the configured CMake build as the authoritative C++ result. IntelliSense
  diagnostics are editor assistance and do not replace compilation with the
  project's warning flags.
- When adding or renaming a module, add its public and test include directories
  to `../.vscode/c_cpp_properties.json`. Update both `includePath` and `browse.path`
  in the same change.
- Keep `compilerPath`, `cppStandard`, and `intelliSenseMode` consistent with the
  compiler and C++ language version selected by CMake. This project currently
  uses `/usr/bin/c++`, C++17, and `linux-gcc-x64`.
- Ensure IntelliSense can reach `xWalk-rpi5-hw/xWalkLibrary/common`. Project aliases such as
  `uint8`, `uint16`, `uint32`, and `float64` are declared there and are expected
  to be available through the module include chain.
- An unknown project type followed by an incorrect function signature or an
  `expected a ';'` message is usually a cascading parser diagnostic. First check
  whether the matching class header and its dependency headers are resolved.
- An `incomplete type is not allowed` diagnostic for a standard-library object
  usually means only its forward declaration is visible. Include the defining
  standard header directly in the translation unit, such as `<fstream>` for
  `std::ifstream` and `std::ofstream`, or `<filesystem>` for
  `std::filesystem::path`, `file_status`, and filesystem operations. Then
  confirm the same file still compiles with the configured CMake target.
- Do not modify valid C++ declarations merely to silence an IntelliSense-only
  diagnostic when the configured compiler accepts the translation unit. Correct
  the editor include configuration and confirm the result with a clean build.
- Validate `../.vscode/c_cpp_properties.json` after editing it. Do not leave stale,
  duplicated, or nonexistent module paths in the configuration.
- If corrected paths do not clear stale diagnostics, run
  `C/C++: Reset IntelliSense Database` from the VS Code Command Palette and then
  reload the VS Code window.
- A new module is not complete until its sources compile and its public types are
  resolved without IntelliSense errors when the `MyPiCarX` parent directory is
  opened as the VS Code workspace.

### Eclipse CDT configuration

- Keep `xWalk-rpi5-hw/.project`, `xWalk-rpi5-hw/.cproject`, and
  `xWalk-rpi5-hw/.settings` synchronized with the integrated product layout.
  Eclipse builds use `xWalk-rpi5-hw/eclipse-build.sh`; CMake remains the authoritative build and
  test configuration.
- Keep a uniquely named `.project` in each supported component repository root so it can be imported
  independently. C/C++ components also own `.cproject` and CDT indexer preferences.
  `xWalkAudioResources` uses a resource project plus UTF-8 preferences. The documentation component
  intentionally has no Eclipse metadata.
- Component Eclipse loaders provide indexing and navigation only. Do not attach an unverified standalone
  builder to a component whose CMake entry point is not independently configurable. Use the integration
  loader for the complete build and test workflow.
- Store project-wide Eclipse text encoding in
  `xWalk-rpi5-hw/.settings/org.eclipse.core.resources.prefs` and keep it set to UTF-8.
- Keep project-specific CDT indexer settings in
  `xWalk-rpi5-hw/.settings/org.eclipse.cdt.core.prefs`. Use the Fast Indexer and index source
  files outside the active build plus unused C++ headers so newly added modules
  remain navigable before their first successful build.
- Keep generated `build*` and `CMakeFiles` trees excluded in `xWalk-rpi5-hw/.cproject`. Do not
  add generated sources or build output as Eclipse source roots.
- When adding or moving a module, update its public and test include paths in
  `xWalk-rpi5-hw/.cproject` in the same change. Remove stale paths and preserve the C++17
  language setting.
- Validate the integration and component `.project` and `.cproject` files as XML after editing them.
  Validate each `.prefs` file as unique `key=value` entries with no malformed lines.

## Class design and ownership

- Prefer small concrete, non-virtual objects unless runtime polymorphism is a
  real requirement.
- Continue the I2C dependency-injection pattern: a context pointer plus C-style
  callbacks separates hardware-independent behavior from the backend.
- Keep the default PWM simulation device-free. Compose `XWalkPwm` with an
  in-memory I2C callback backend and never open `/dev/i2c-*` or access a Robot
  HAT unless an explicit hardware-test target is selected.
- Keep the non-throwing PWM fail-safe write path free of trace operations and
  exception handling. Trace ordinary timer and output operations only after
  their state change and I2C write have succeeded.
- Keep the default ADC simulation device-free. Compose `XWalkAdc` with an
  in-memory I2C callback backend and validate address selection, sample
  assembly, and voltage conversion without opening `/dev/i2c-*`.
- Keep the default Servo simulation device-free. Compose `XWalkServo` through
  real PWM and I2C interfaces backed by an in-memory callback recorder. It must
  not open `/dev/i2c-*` or move a physical actuator.
- Keep the default ADXL345 simulation device-free. Exercise configuration,
  discarded reads, signed conversion, and axis ordering through an in-memory
  register-read callback backend without opening `/dev/i2c-*`.
- I2C consumers that acquire device data use the shared read callback. A raw read
  returns bytes in bus order and must reject a zero-byte request at the interface boundary.
- Continue the GPIO dependency-injection pattern: one `XWalkGpio` stores a
  non-owning backend context and validated callback set. A Linux GPIO backend is
  dedicated to one GPIO object because it owns that line's descriptor and event
  worker. Create the backend before the GPIO object in the composition root.
- Keep Linux GPIO system calls behind an injected `XWalkGpioDevice` boundary.
  Production uses `XWalkGpioDeviceLinux`; host tests and the safe standalone
  simulation inject `XWalkGpioHostStub` so the real Linux line-request and
  digital-I/O logic executes without opening `/dev/gpiochip*`.
- Continue the SPI dependency-injection pattern: one `XWalkSpi` stores a
  non-owning backend context and required full-duplex callback. Keep device,
  mode, clock, bits-per-word, and chip-select selection in deployment and the
  Linux owner. Bound one transfer to 256 bytes and require equal request and
  response lengths.
- Keep Linux SPI system calls behind an injected `XWalkSpiDevice` boundary.
  Production uses `XWalkSpiDeviceLinux`; host tests and the safe standalone
  simulation inject `XWalkSpiHostStub` so the real Linux configuration and
  request-building logic executes without opening `/dev/spidev*`.
- Compose the CLI SPI command through its dedicated SPI-only boot mode. It must
  not detect or reset the Robot HAT, claim GPIO, construct actuators, or start
  audio, camera, speech, or model services.
- Compose the CLI Doctor command through a dedicated bounded preflight mode. It
  may validate the configured GPIO chip, pulse only `hardware_mcu_reset_pin`
  low for 10 ms and then high, wait `hardware_mcu_reset_settle_ms`, open
  configured device descriptors, inspect metadata, read firmware, and sample
  battery ADC A4. It must not construct or move actuators, transfer SPI data,
  enable audio, capture media, or contact a model endpoint. Its safety result
  must disclose the MCU reset GPIO activation.
- GPIO interrupt application contexts are non-owning. They must outlive the
  registration, and handlers invoked by a backend worker must not throw or block
  indefinitely. Cancel the registration before destroying the handler context.
- Keep the default UserButton simulation device-free. Drive one active-low
  input through a named in-memory GPIO callback backend and verify bounded press
  and release observation without opening `/dev/gpiochip*`. Keep trace work out
  of the `noexcept` polling worker and its callbacks.
- Motor drivers receive caller-created PWM and GPIO objects by reference and
  store non-owning pointers. Select PWM-and-direction or dual-PWM mode through
  typed constructor dependencies rather than an unchecked numeric mode value.
- Keep the default Motor simulation device-free. Compose real I2C, PWM, GPIO,
  and Motor interfaces over named in-memory callbacks without opening device
  nodes or moving an actuator. Never add trace work to `stopSafely()` or a
  motor destructor because those fail-safe paths are non-throwing.
- Keep ordinary `stop()` failure-reporting, but implement `stopSafely()` as a
  non-throwing best-effort boundary. A single motor independently attempts every
  speed PWM output, paired motors independently attempt both motors, and both
  destructors invoke their safe-stop operation without releasing dependencies.
  Route these attempts through explicit Boolean I2C and PWM status operations;
  do not intercept exceptions to implement fail-safe cleanup.
- Bound final PiCar-X motor PWM magnitude through the deployment key
  `picarx_max_motor_output_percent`, using 20 percent by default for first-run
  safety. Apply the bound after compatibility scaling and calibration. Do not
  permit a limit above 20 percent until the calibration workflow persists
  `picarx_calibration_verified = true` after raised-wheel motor-direction,
  steering-center, and motor-balance checks.
- Persist signed motor balance through `picarx_motor_speed_calibration` in the
  range -100 through 100 percentage points. Positive values reduce the left
  side and negative values reduce the right side. Persist confirmed stationary
  grayscale and cliff samples through `line_reference` and `cliff_reference`.
- Latch PiCar-X emergency stop before attempting safe shutdown. Suppress later
  motor and servo commands until the application explicitly starts a fresh
  operation, and arm one `XWalkPicarxSafetyGuard` for every non-SPI CLI command.
- Keep persistent motor role and reversal configuration outside the motor
  objects. Pass configuration values into `XWalkMotors`, and let
  `XWalkConfigStore` own filesystem access when persistence is required.
- Create `XWalkConfigStore` in `main()` or the application composition root.
  Load strings there, convert them to validated typed configuration, and pass
  those values into hardware consumers. Hardware drivers must not open
  configuration files.
- Keep configuration paths as owned standard-library values. A configuration
  store may contain its own mutex by value because a mutex is synchronization
  state, not an injected project-class dependency.
- Validate configuration names as non-empty, single-line keys without `=` or
  leading or trailing whitespace. Validate persisted values as single-line
  text. Preserve comments and unrelated entries when updating a file.
- Split controller deployment settings by functionality below `picar-x.d` and
  select one generic AI-provider profile through relative `include` directives
  in `picar-x.conf`. Included files must use the `.conf` extension, remain below
  the including directory, avoid cycles, and stay within eight include levels.
  Persist runtime calibration overrides only in the primary configuration file.
- Keep generic AI model selections and credentials out of provider
  configuration files. Provider profiles name deployment-owned environment
  variables, and runtime composition reads their values without logging or
  persisting credentials. Do not duplicate AI values in the tracked systemd
  environment file.
- Store AI model selections only in the authenticated
  `xWalk-rpi5-hw/xWalkLibrary/X_WALK_LICENSE.KEY` file produced by
  `xWalk-rpi5-tool/py-agent/dev-tool/xWalkLicenseTool`. Store API credentials only in the
  developer's mode-`0600` `~/.netrc` under the documented actual provider
  hostnames. Use a fresh SecretBox key and nonce, retain the versioned `XWL1` header,
  and keep the decryption key outside the repository. The committed
  `xWalk-rpi5-tool/shell-agent/env-tool/license/xWalkLicense.cfg` remains an empty model template.
  Keep `xWalk-rpi5-hw/xWalkLibrary/X_WALK_LICENSE.KEY` ignored and untracked because its
  authenticated ciphertext and serial are deployment-specific.
  `xWalkEnv.sh` must validate the complete model allowlist and supported netrc
  entries before exporting anything, skip missing or empty unused-provider
  credentials, never evaluate or print decrypted values, and remove its
  mode-`0600` temporary plaintext. Never use Base64,
  XOR, `.obj` files, compiled objects, generated source, or hardcoded keys as
  secret protection.
- Generate one licence serial per successful encryption in
  `XWALK-<UTC_YEAR>-<8_UPPERCASE_HEX>` form through `secrets.token_hex(4)`.
  Store that same value as authenticated `X_WALK_LICENSE_SERIAL` payload
  metadata and print it only after the encrypted file is durable. Treat the
  serial as a public identifier, never as key material, and print neither it
  nor the decryption key when encryption or output writing fails.
- Commit configuration updates through a replacement file in the same
  directory. Serialize operations performed through one store instance, and
  require external synchronization when separate instances or processes access
  the same file.
- Keep file permission and ownership policy outside `XWalkConfigStore`. Do not
  construct `sudo chmod` or `sudo chown` shell commands from application input.
- Preserve `XWalkConfigStore`'s Robot HAT compatibility rule that removes ASCII
  spaces from unquoted values. Use surrounding double quotes for deployment
  values whose internal spaces are significant; retrieval removes those quotes
  and retains the enclosed spaces.
- Use `XWalkConfig` for section-aware files and retain `XWalkConfigStore` for
  the flat key-value format. Provide
  both classes through the combined `xWalkConfig` module, but keep their headers,
  source files, tests, file grammars, and persistence contracts separate.
- Create `XWalkConfig` in `main()` or the application composition root. Its
  section and option containers are value-like state and remain stored by value;
  do not inject filesystem configuration directly into hardware drivers.
- Represent options before the first header through the empty default-section
  name. Validate named sections as non-empty trimmed text without brackets or
  line terminators, and validate option names as non-empty trimmed text without
  `=`, brackets, or line terminators.
- Keep `XWalkConfig` mutations explicit: `set()` and a missing-option `get()`
  update the memory image, `write()` persists it, and `read()` discards unsaved
  changes by reloading the file. Preserve comments, blank lines, unrelated
  options, and unrelated text during persistence.
- Create missing section-aware files with optional `# ` description comments.
  Reject malformed section headers conservatively, and use an empty string as
  the empty typed C++ default.
- Commit both configuration formats through a same-directory replacement file
  and preserve existing permission bits. Do not expose mode or owner constructor
  arguments, and never execute `chmod`, `chown`, or `sudo` through a shell.
  Deployment tooling owns file permission and ownership policy.
- Keep the standalone `xWalkConfig` simulation confined to its generated build
  directory. Exercise both section-aware and flat-store persistence there; do
  not read, replace, or create deployed application configuration paths.
- Keep `XWalkBoardControl`, `XWalkDevice`, and `XWalkFirmwareInfo` in the
  combined `xWalkBoardControl` module. Retain separate class headers, source
  files, tests, and responsibilities rather than combining them into one class.
- Keep `XWalkDevice` limited to Robot HAT device discovery. It owns a configurable
  device-tree root and value-like discovery result; it must not create GPIO, LED,
  speaker, motor, ADC, or board-control objects.
- Scan only direct children whose names contain `hat`, require a regular UUID
  property, and recognize Robot HAT v5 through its documented UUID. Publish
  detected metadata only after every selected property is read and validated.
- Preserve Robot HAT v4 board values as an explicit deployment profile: speaker
  enable GPIO 20 and motor mode 1. A recognized v5 board uses GPIO 12 and motor
  mode 2. Keep the separate `detected` state so defaults do not imply discovery,
  and never infer v4 merely because the supported v5 UUID is absent.
- Parse product ID and version as bounded unsigned 32-bit hexadecimal values.
  Accept one through eight digits with an optional `0x` prefix, and reject
  malformed or oversized properties without partially replacing prior state.
- Preserve the property-trimming distinction conservatively. UUID,
  product ID, and version may remove one terminal null byte; product and vendor
  data remain complete. Never remove a non-null final byte.
- Keep `XWalkBoardControl` limited to GPIO output, MCU reset, battery voltage,
  and speaker power. Do not add terminal formatting, process
  execution, network lookup, user lookup, error redirection, or lazy caching.
- Create the MCU-reset GPIO, board-selected speaker-enable GPIO, I2C interface,
  and A4 ADC in `main()`. Pass them to `XWalkBoardControl` by reference and
  store only non-owning pointers. Every dependency must outlive the controller.
- Validate hardware roles during construction. MCU reset uses GPIO 5, battery
  sensing uses ADC channel A4, and speaker enable uses GPIO 20 for Robot HAT v4
  or GPIO 12 for Robot HAT v5. Obtain the selected speaker pin from
  `XWalkDevice::information()` in the application composition root.
- Preserve the reset sequence as a logical low level for 10 milliseconds
  followed by a logical high level for 10 milliseconds. Document that a GPIO
  failure after assertion may leave the MCU held in reset.
- Calculate battery potential by naming the ADC voltage, divider ratio, and
  resulting battery voltage separately. Apply the hardware divider ratio of
  three without combining conversion and multiplication in one expression.
- Use a required, context-based callback for speaker priming. Enable the GPIO
  before requesting 500 milliseconds
  of priming output. A failed callback leaves speaker power enabled.
- Do not invoke `pinctrl`, `raspi-gpio`, `play`, `sudo`, or another shell command
  from board-control production code. Use the injected GPIO and audio contracts.
- Keep the standalone `xWalkBoardControl` simulation device-free. Exercise reset,
  battery conversion, speaker priming, firmware acquisition, and device discovery
  through named in-memory callbacks and a build-local synthetic device tree. Do
  not access GPIO, I2C, ALSA, or `/proc/device-tree` from the host simulation.
- Emit board-control operation, discovery, firmware, simulation, and host-test
  records through xWalk trace macros. Preserve trace selector state in the
  generated XML catalogue so a later no-argument run reloads it automatically.
  Keep disable, destructor, cleanup, and callback paths trace-free.
- Keep non-hardware platform behavior in the separate `xWalkUtils` module. Do not
  move terminal, command, executable, network,
  username, standard-error, or lazy-cache behavior into `xWalkBoardControl`.
- Inject terminal output, volume control, command execution, executable lookup,
  IPv4 lookup, username lookup, monotonic time, and standard-error redirection.
- Keep the default standalone `xWalkUtils` simulation bound to
  `XWalkUtilsHostStub`. It must mirror output, volume, commands, executable and
  network queries, and username lookup in memory without invoking a shell,
  changing mixer state, redirecting descriptors, or querying the host.
  The hardware-independent module must not call `sudo`, `amixer`, `which`, a
  shell, environment lookup, network command, or descriptor API directly.
- Treat command text as security-sensitive. Forward it without modification so
  compatibility is explicit, but require the application backend to validate
  all untrusted input before invoking a process or shell.
- Preserve volume clamping to zero through one hundred percent. Preserve
  ordered IPv4 lookup with an empty string for not found, and consolidate the
  three executable checks behind one typed backend operation.
- Implement `ignore_stderr` as the scope-bound `XWalkStderrGuard`. Redirect in
  construction, restore in destruction, and retain no ownership of the platform
  callback context. A throwing restore callback terminates the process.
- Keep `XWalkLazyReader<ValueType>` callback-based and generic. Acquire on the
  first read and refresh only when elapsed monotonic time is strictly greater
  than the configured millisecond interval. Cache only value-like data or a
  non-owning pointer, never a project component object by value. Require
  external serialization.
- Preserve linear-map extrapolation, but reject non-finite inputs and a zero-width
  input range instead of permitting undefined division behavior.
- Keep `XWalkFirmwareInfo` limited to firmware reads and static compatibility
  metadata. Do not add global device objects, command-line
  parsing, console output, process termination, or unrelated package imports.
- Create `XWalkI2c` in `main()`, pass it to `XWalkFirmwareInfo` by reference,
  and store only a non-owning pointer. The I2C object and its backend must outlive
  the firmware-information reader.
- Probe firmware addresses `0x14` and `0x15` in that order and retain the first
  responding address. Reject the no-device case instead of falling back to a
  known-unresponsive `0x14` address.
- Read exactly three bytes beginning at register `0x05` through one atomic
  `XWalkI2c::readRegister()` operation. Reject missing register-read support or
  a response that is not exactly three bytes before indexing it.
- Represent firmware version components as a documented structure containing
  unsigned major, minor, and patch bytes. Format each component through a shared
  Common conversion function and join them as `major.minor.patch`.
- Preserve Robot HAT compatibility version `2.5.5` as static non-owning metadata.
  Do not confuse this package version with the firmware bytes read from hardware.
- Keep the process-wide `XWalkTrace` macro runtime synchronous and free of a
  console backend or worker thread. Serialize configuration lookup, timing
  capture, formatting, and append-only
  `<build-directory>/log/xWalkTrace.log` writes. Generate the path through the
  owning CMake build so running a binary from the source root never creates
  source-tree log artifacts. Invoke an optional application callback only after
  releasing the file lock.
- Use `RPI.<digits>` UIDs with HAL macros, `CTRL.<digits>` UIDs with Controller
  macros, `RPIAGENT.<digits>` UIDs with Agent macros, and `LIB.<digits>` UIDs
  with Library macros. Source files below `xWalkHal`, `xWalkController`,
  `xWalkAgent`, and `xWalkLibrary` must use their owning macro family. The
  numeric value must be unique within its tag across the complete repository
  regardless of module, submodule, or priority. IDs `RPI.001`, `CTRL.001`,
  `RPIAGENT.001`, and `LIB.001` are valid together because their tags differ;
  `RPI.001` and `RPI.1` conflict because their numeric values are equal.
  The `UIDn` suffix is the exact count of formatting arguments after the UID
  and format string. Keep priority zero as highest and priority three as lowest
  in the central xWalkTrace priority catalogue. Emit a tagged record only when
  its resolved global, module, and individual UID state is enabled.
- Keep warning, error, and numeric assertion-signal macros independent of normal
  trace registry state. Capture the public macro's `__FILE__` and `__LINE__`; store only
  the source basename in logs and retain project-relative paths in generated XML.
- Route every project-owned diagnostic through the source tree's existing xWalk
  trace macro family. Normal, informational, status, progress, success, and
  debug records use one registered UID macro; warnings use the singular
  selector-tagged `WARNING` macro, errors use the selector-tagged `ERROR`
  macro, and `ASSERT` is reserved for genuine invariant failures. Do not
  use direct standard streams, C printing, platform logging, local diagnostic
  macros, or callback-based console printing for diagnostics. Functional CLI
  and protocol output remains separate at application and Agent interaction
  boundaries: preserve help, version text, protocol responses, and conversation
  output when trace decoration would change their interface contract.
  `xWalk-rpi5-hw/xWalkController/xWalkHandler` is trace-only for its own status, result,
  warning, and failure records; it must not call its output callback for those
  records.
- Keep `XWALK_VERBOSE(format, ...)` only as a disabled no-op for source
  compatibility. Normal diagnostics use one scanner-registered UID macro so
  their formatting arguments are not evaluated while disabled.
- Format wall time as UTC with milliseconds and elapsed time from one
  `steady_clock` initialization point with microseconds. Do not describe one
  trace call as an operation-duration measurement.
- Run the class-based
  `xWalk-rpi5-hw/xWalkTrace/pre-compiler/xHal_Rpi5CarTracePreCompiler.py` before trace
  compilation. Its
  token-aware scan covers the complete project root, including generated
  project sources and participating nested repositories, rejects every
  duplicate numeric or malformed UID, generates the deterministic mutable
  `generated/xwalk-traces.xml` catalogue, removes absent UIDs, preserves valid
  states for retained UIDs, and avoids rewriting unchanged content. Newly
  discovered normal traces default disabled.
- Apply repeatable Controller `--trace VALUE` options before constructing the
  boot graph. Accept `all.<state>`, `<module>.<state>`,
  `<module>.<digits>.<state>`, and `.json` paths, with exact `enable` or
  `disable` states. Retain `--trace-enable UID` and `--trace-disable UID` as
  legacy aliases. Start with the saved XML state, process arguments left to
  right, and make the last applicable setting win. JSON applies global, module,
  then tag states and rejects Boolean states and unknown catalogue IDs. Persist each
  complete update atomically in the generated XML and update the synchronized
  shared registry only when persistence succeeds. Load saved states once on the
  next process run; never parse XML or JSON on each trace call.
- Let standalone diagnostic binaries accept an exact `--trace` selector when
  runtime trace control is required. Use individual, module, global, or JSON
  selectors, validate them before opening hardware, and atomically persist only
  scanner-known module and UID states in the configured XML.
- Preserve the compatibility severity ordering from zero through four:
  critical, error, warning, info, and debug. Accept exact lowercase names, use
  warning by default, and retain threshold behavior for explicit `XWalkTrace`
  object calls.
- Keep speech recognition and speech synthesis in the combined `xWalkGPT`
  module. Retain `XWalkSpeechToText` and `XWalkTextToSpeech` as separate classes,
  headers, source files, and test executables within that module so each class
  preserves one responsibility and each file contains only one class definition.
- Keep `XWalkTextToSpeech` limited to the common behavior required by Piper,
  Pico2Wave, Espeak, OpenAI TTS, and EdgeTTS providers. Consolidate those
  providers into one coordinator rather than duplicating five
  classes whose only Robot HAT responsibility is speaker activation.
- Keep the standalone `xWalkGPT` simulation device-free. Exercise readiness,
  bounded recognition, file transcription, cancellation, speaker priming, and
  speech dispatch through named in-memory callbacks. Never open ALSA devices,
  load models, invoke providers, access a network, or produce audible output.
- Emit GPT coordinator lifecycle and completed-operation records through xWalk
  trace macros. Persist trace selector changes in XML and load them on the next
  no-argument run. Keep transcript and speech content behind an explicit
  privacy-sensitive deployment setting that defaults to disabled. Never log
  captured PCM, credentials, provider requests, callback bodies, cancellation
  cleanup, or destructors.
- Create `XWalkBoardControl` and the speech backend in `main()`. Pass board
  control by reference, store only a non-owning pointer, and inject speech output
  through a non-null synchronous callback with an optional non-owning context.
- Validate the speech callback before changing hardware. Enable and prime speaker
  output during construction, propagate board-control failures, and do not disable
  shared speaker power automatically during destruction.
- Forward speech text without modifying its encoding, language, content, or empty
  state. The backend owns its text limits, model, voice, synthesis, playback,
  process, filesystem, and network policy and must not retain the text view.
- Do not link the hardware-independent coordinator directly to Piper, Pico2Wave,
  Espeak, OpenAI, EdgeTTS, ONNX, process-execution, or network libraries. Supply
  those capabilities through an application-owned platform backend.
- Serialize access externally when a board controller or speech backend is shared
  between tasks. Do not claim real-time or interrupt safety for an arbitrary TTS
  backend, because synthesis, playback, and network operations can block.
- Keep `XWalkVoiceAssistant` limited to synchronous orchestration of caller-created
  `XWalkSpeechToText`, `XWalkLanguageModel`, and `XWalkTextToSpeech` objects.
  Create those objects in `main()`, pass them by reference, and store non-owning
  pointers that remain non-null and valid for the coordinator's full lifetime.
- Keep the standalone VoiceAssistant simulation device-free. Compose GPIO, I2C,
  recognition, language-model, and speech-output seams through named in-memory
  callbacks without ALSA, models, providers, processes, network, or audible output.
- Emit VoiceAssistant lifecycle and completed-round records through trace macros.
  Persist trace selection in generated XML and load it on the next no-argument run.
  Never trace recognized text, prompts, model responses, speech text, audio,
  fixtures, credentials, callback bodies, cancellation cleanup, or destructors.
- Put reusable VoiceAssistant host-test state and callbacks in the named
  `xwalk::hal::test::voiceassistant` namespace under `test/include` and `test/src`.
  Keep scenario assertions in the test entry-point source.
- Preserve one-round flow as listen, skip silence, prompt, optionally parse, speak
  non-empty output, and report completion. Optional null lifecycle callbacks are
  no-ops, and a null response parser returns an unmodified owned response copy.
- Compose the target pipeline in this order: shared ALSA audio, ALSA
  speech-to-text adapter and coordinator, Ollama provider and coordinator, ALSA
  text-to-speech adapter and coordinator, then `XWalkVoiceAssistant`. Preserve
  reverse destruction order so the assistant is destroyed first.
- Keep the full-stack hardware smoke test explicit and opt-in. Require capture,
  playback, mixer, Ollama endpoint, model, approved prompt, and response-fixture
  selection; never emit captured PCM, prompts, responses, fixtures, or credentials.
- Keep wake detection, trigger policies, keyboard polling, camera capture,
  continuous loops, streaming, threads, and scheduling in the application or an
  injected backend. Require external serialization because injected operations
  may block and are not assumed to be thread-safe or interrupt-safe.
- Keep `XWalkSpeechToText` limited to synchronous readiness queries, bounded
  microphone listening, audio-file transcription, and explicit stop control.
  Do not infer platform ownership or hidden setup behavior in this coordinator.
- Inject one complete callback table for speech readiness, microphone listening,
  file transcription, and stop control. Reject a table containing any null
  callback during construction; the optional context pointer is non-owning and
  may be null when the backend does not require state.
- Accept listen timeouts from 1 through 300,000 milliseconds and use 30,000
  milliseconds by default. Reject an empty audio-file path before invoking the
  backend, but preserve an empty transcript because it can represent silence or
  unrecognized speech rather than an interface failure.
- Keep microphone enumeration, capture resources, speech models, language
  selection, streaming partial results, wake-word threads, filesystem access,
  process execution, and network access inside the application-owned backend.
- Call the speech stop callback during destruction. A throwing callback
  terminates the process because destructors do not install exception handlers.
  Backends must tolerate stop requests while idle and repeated stop requests.
- Serialize access externally when a speech-to-text object is shared between
  tasks. Listening and transcription callbacks may block and must not be called
  from interrupt context unless a backend explicitly proves that use safe.
- Keep real microphone ownership in `XWalkSpeechToTextAlsa`. Capture 16 kHz mono
  signed-16 PCM, limit one ALSA read to 1,024 frames, feed each completed period
  to one bounded streaming recognition session, and treat the coordinator's
  listen timeout as a hard upper bound. Release both capture and recognition
  resources on every completion, cancellation, and error path.
- Prefer native Vosk endpoint acceptance. When the deployed C API has no endpoint
  timing setters, arm the bounded trailing-silence fallback only after a non-empty
  Vosk partial transcript so quiet initial input cannot create an utterance. Keep
  fallback timing and signed-16 peak threshold finite, positive, ordered, and
  deployment-configurable without accumulating the full recording.
- Inject one complete recognizer operation table into the ALSA adapter. The
  application selects one local or remote provider and owns its model, process
  or HTTP transport, credentials, language policy, and provider-specific data.
- Make capture recovery and cancellation bounded. A stop request may interrupt
  capture or recognition, repeated cancellation must be tolerated, and normal
  diagnostics must never contain microphone PCM or credentials.
- Implement synthesis playback in `XWalkTextToSpeechAlsa`, which observes one
  caller-owned `XWalkAudioAlsa`. The audio owner outlives the adapter, and the
  adapter outlives `XWalkTextToSpeech`.
- Inject one non-null synthesis operation returning at most 16 MiB of interleaved
  signed sixteen-bit little-endian PCM. Require positive sample rate, one through
  eight channels, complete frames, and no more than 1,024 frames per ALSA write.
- Keep models, voices, credentials, process or HTTP transport, provider formats,
  and generated-file policy in the selected application-owned synthesis provider.
  Empty provider PCM completes without opening a stream or changing mixer volume.
- Keep `XWalkLanguageModel` limited to provider-neutral system instructions,
  welcome text, retained-message limits, conversation messages, and synchronous
  final-response prompting. Consolidate general, Deepseek, Grok,
  Doubao, Gemini, Qwen, OpenAI, and Ollama classes behind one coordinator.
- Inject one complete callback table for instructions, welcome text, message
  limits, message insertion, and prompting. Reject a table containing any null
  callback during construction; the optional context pointer is non-owning and
  may be null when the backend does not require state.
- Represent conversation participants with `XWalkLanguageModelRole`. Preserve
  system, user, and assistant roles without forwarding unchecked role strings.
- Use 20 retained messages by default and reject zero. Leave any provider- or
  deployment-specific upper limit to the backend instead of inventing one in
  the hardware-independent interface.
- Preserve empty instructions, welcome text, message content, prompt content,
  and final responses. Use an empty image-path view to represent no attached
  image and keep image validation and encoding inside the backend.
- Keep credentials, authorization, provider URLs, model selection, HTTP, JSON,
  process execution, image encoding, history storage, history truncation,
  streaming delivery, and provider errors inside the application-owned backend.
  Never compile credentials into a module or write them to diagnostic output.
- Serialize access externally when a language-model object is shared between
  tasks. Prompt callbacks may block on inference, a process, or network I/O and
  must not be used from interrupt context.
- Use `XWalkLanguageModelOllama` as the first concrete provider. It owns bounded
  history, Ollama JSON conversion, optional base64 image conversion, and real
  libcurl HTTP transport while remaining separate from the neutral coordinator.
- Limit Ollama state to 200 messages, each text value to 256 KiB, one raw image
  to 4 MiB, one JSON request to 8 MiB, and one HTTP response to 1 MiB. Bound
  request timeout to 1 through 300,000 milliseconds and default to 120,000.
- Send non-streaming `/api/chat` requests and retain a prompt and final response
  only after successful parsing. The built-in transport sends no authorization
  header; deployment owns endpoint protection, TLS, proxies, and credentials.
- Never emit Ollama requests, responses, images, prompts, or credentials through
  normal diagnostics. Require explicit endpoint, model, and prompt selection in
  the opt-in provider smoke test.
- Keep the default LanguageModel simulation provider-neutral and in memory. It
  may mirror coordinator operations for verification, but must not select a
  provider, read credentials, start a process, or perform a network request.
- Validate both left and right commands before changing either motor. A failed
  range or finite-value check must not leave only one motor updated.
- Do not embed one project class as a by-value object or reference data member
  inside another project class. Store an injected class dependency as a
  non-owning pointer.
- Accept every required class dependency as a constructor reference, then store
  its address in the non-owning pointer member. The constructor reference makes
  null invalid at the API boundary; the pointer supports the project's explicit
  dependency representation inside the class. The Agent PiCar-X coordinator is
  the composition exception: accept one `xAgentContext`, validate all required
  PiCar-X pointers before use, and retain those pointers without taking ownership.
- Create concrete backends, interfaces, shared state, and consumers in `main()`
  or the equivalent test entry point. Construct dependencies before consumers,
  pass them by reference, and ensure consumers are destroyed first.
- Keep ownership outside dependent classes. A dependent class must not allocate,
  delete, or otherwise release its injected pointer.
- Register variable-count Robot servo dependencies individually through
  `XWalkRobot::addServo(XWalkServo&)`. Store them as bounded non-owning pointers,
  complete registration before `initialize()`, and prohibit registration after
  initialization. The application creates PWM and Servo objects before the
  Robot and destroys the Robot first.
- Keep the standalone `xWalkRobot` simulation device-free. Use a named in-memory
  I2C adapter, one simulated Servo/PWM chain, and a build-local configuration
  store. Never open Linux I2C devices or cause physical servo movement there.
- Emit Robot lifecycle, completed movement, action, calibration, persistence,
  simulation, and host-test records through xWalk trace macros. Persist selector
  changes in XML and load them automatically on the next no-argument run. Keep
  interpolation-loop writes, callbacks, cleanup, and destructors trace-free.
- Keep articulated-robot configuration separate from hardware construction.
  Inject `XWalkConfigStore` by reference, derive a robot-specific offset key,
  and reject malformed or incorrectly sized persisted offset lists.
- Limit coordinated Robot motion to a bounded servo count and validate every
  complete frame before changing hardware. Interpolate all registered servos
  using one shared completion ratio so a failed frame cannot partially change
  only a subset because of a length or finite-value error.
- Construct ultrasonic trigger and echo GPIO objects in the application, pass
  them to `XWalkUltrasonic` by reference, and store only non-owning pointers.
  Configure the trigger as an output and the echo as a pull-down input without
  constructing replacement GPIO objects inside the sensor.
- Use a monotonic microsecond clock for ultrasonic pulse timing. Generate the
  inactive settling interval and active trigger pulse explicitly, apply one
  bounded timeout to both echo transitions, and leave the trigger inactive.
- Preserve the ultrasonic result contract: return `-1.0` for timeout,
  retry timeout results only, and return `-2.0` without retry when no complete
  pulse can be measured. Document all successful values in centimeters.
- Keep the default Ultrasonic simulation device-free. Compose the public GPIO
  and Ultrasonic interfaces with named in-memory callbacks, model a bounded
  echo pulse, and validate trigger sequencing and the converted distance.
  Trace-selector changes must persist in the generated XML and load on the next
  run without requiring the selector again.
- Construct the three line-tracker ADC channels in the application, pass them
  by reference in left, middle, and right order, and store bounded non-owning
  pointers. Use fixed three-element project types for readings, statuses,
  slopes, and offsets so incomplete channel data is not representable.
- Validate line-tracker calibration coefficients before storing them. Perform
  calibration arithmetic in `float64`, round only at the documented boundary,
  and reject a result before conversion when it exceeds the signed count range.
- Preserve strict tracker comparisons: a cliff value is below its
  threshold, a line requires spread greater than the configured difference,
  and a grayscale value equal to its reference is classified as black.
- Keep the default LineTracker simulation device-free. Compose the public I2C,
  ADC, grayscale, and tracker interfaces over a named in-memory bus and verify
  channel ordering and position without opening `/dev/i2c-*`.
- This rule applies to project component classes. Value-like standard-library
  state such as containers, mutexes, optionals, and fixed arrays remains stored
  by value.
- State ownership and lifetime through construction. Do not hide opening of
  hardware devices inside hardware-independent objects.
- Delete copy and move operations for objects whose callbacks, references,
  mutexes, or OS handles make relocation unsafe.
- Use RAII for resources. Acquire a Linux file descriptor in construction,
  validate it immediately, and close it in destruction.
- Keep every class data member private. A `private` access section must contain
  variables only; do not declare constructors, destructors, operators, static
  helpers, or other member functions there.
- Declare every non-public member function in a `protected` access section,
  including validation, conversion, lifecycle, and hardware helper functions.
  This project convention applies even when no derived class currently uses the
  function. Do not change a function's implementation merely to change access.
- Mark getters `const`; mark non-throwing accessors `noexcept`.
- Use function-local static state when project-wide shared state needs safe C++11
  initialization, as in the default PWM timer state.

## Validation, errors, and numeric behavior

- Do not use `try` or `catch` statements in workspace production code or tests.
  Controller, Agent, and HAL functions throw through their exception aliases.
  Ordinary callers let those failures escape. Provide
  cleanup through scope-bound guards and destructors so stack cleanup requests
  actuator shutdown without exception interception.
- Controller, Agent, HAL, and traced Library paths pass one public error signal
  from `xHal_Rpi5CarErrorSignals.h` and an owned message to their component
  `ERROR` macro. Use `XWALK_INVAL`, `XWALK_RANGE`, `XWALK_LOGIC`, or
  `XWALK_RUNTIME` for the common validation and runtime categories; the error
  signal header documents the additional supported selectors. The macro evaluates the
  formatting arguments once, records the diagnostic, and throws the selected
  C++ exception. Operating-system signal selectors only report the matching
  signal condition and never raise the signal again. Use `XWALK_EXCEPTION` for
  a generic error that intentionally returns a status or continues without
  throwing. Do not add a separate
  `throw` or insert an `ASSERT` around an ordinary validation, configuration,
  backend, or runtime exception. The foundational
  `xWalkLibraryCommon` headers and xWalkTrace's own implementation remain exempt
  because tracing from either layer would introduce a dependency cycle or
  recursive trace failure.
- When an operation must continue after one failed backend attempt, provide an
  explicit non-throwing Boolean status operation. The fail-safe I2C/PWM write
  path and the SelfDrive delay callback use this pattern. Callers must check the
  status, attempt every independent safety output, and latch failure for the
  controlling thread.
- Callbacks invoked by unrelated destructors or `noexcept` workers remain
  non-throwing; a violation terminates the process.
- Verify expected validation failures in host tests with
  `xwalk::hal::test::expectFailure()`, which isolates the operation in a child
  process and asserts that it does not complete successfully.

For hardware formulas, do not combine multiple conversions, multiplications,
or divisions in one expression. First convert every input to the intended
calculation type, then name each derived quantity:

```cpp
const float64 pwmClockHz = static_cast<float64>(XHAL_RPI5CAR_PWM_CLOCK_HZ);
const float64 servoFrequencyHz = static_cast<float64>(XHAL_RPI5CAR_SERVO_FREQUENCY_HZ);
const float64 servoPeriod = static_cast<float64>(XHAL_RPI5CAR_SERVO_PERIOD);
const float64 servoTimerDivisor = servoFrequencyHz * servoPeriod;
const float64 prescaler = pwmClockHz / servoTimerDivisor;
```

This pattern applies to clock, frequency, period, prescaler, duty-cycle, timing,
unit-conversion, and register-scaling calculations. Intermediate names must
include units when applicable and must describe the physical or mathematical
meaning rather than the order of evaluation. Do not use names such as `temp`,
`value1`, or `result2`.

- Validate inputs at the public boundary or before acquiring a resource.
- Reject invalid states with the corresponding Controller, Agent, or HAL
  exception alias:
  - invalid form, null callback, or impossible argument: invalid argument;
  - numeric or container limit violation: out of range;
  - failed hardware operation after retries: runtime error.
- Make exception messages concise and specific. Include the subsystem and the
  violated constraint when useful.
- Check floating-point inputs with `XHAL_IS_FINITE` before conversion or range
  comparison.
- Preserve externally visible behavior intentionally. Document a compatibility
  choice where the C++ result might otherwise look accidental.
- Use `XWalkI2c::readRegister()` for register-addressed sensor acquisition.
  Hardware backends perform register selection and data transfer atomically
  under their bus lock; do not compose a register write and sequential read in
  separate unlocked calls.
- Preserve the ADXL345 discarded first sample for every returned
  axis value. Decode the second sample as a signed little-endian 16-bit count
  and scale it by 256 counts per unit of standard gravity.
- Preserve the RGB LED port's component-array, packed `0xRRGGBB`, and
  hexadecimal-text inputs. Strip surrounding `#` characters from text before
  requiring exactly six hexadecimal digits.
- Keep `XWalkLed` and `XWalkRgbLed` in the combined `xWalkLed` submodule. Build,
  test, document, and configure both through the `XWALK_LED_*` options; retain
  `xWalkRgbLed` only as a CMake target alias for compatible consumer linkage.
- Keep the default LED simulation device-free. Compose real GPIO, I2C, PWM,
  single-color LED, and RGB LED interfaces over named in-memory callbacks
  without opening device nodes or changing physical light outputs. Keep trace
  work out of the LED destructor and its `noexcept` blink worker.
- Convert each RGB component independently to a PWM percentage. Invert the
  eight-bit component before scaling for common-anode wiring; do not invert it
  for common-cathode wiring.
- Construct the red, green, and blue PWM objects in the application entry point
  and pass them by reference to `XWalkRgbLed`. The controller stores only
  non-owning pointers, and the PWM objects must outlive it.
- Represent active and passive buzzers with separate `XWalkBuzzer` constructor
  overloads. Accept an `XWalkGpio&` for an active buzzer or an `XWalkPwm&` for a
  passive buzzer, and store the selected dependency as a non-owning pointer.
- Keep the default Buzzer simulation device-free and silent. Compose real GPIO,
  I2C, PWM, active-buzzer, and passive-buzzer interfaces over named in-memory
  callbacks without opening device nodes or producing physical sound. Keep the
  buzzer destructor free of trace and hardware operations.
- Place every buzzer into the inactive state during construction. Use logical
  GPIO polarity for active buzzers and zero or 50 percent PWM duty cycles for
  passive-buzzer off or on operations respectively.
- Permit frequency selection and playback only for passive buzzers. Playback
  without duration remains active; finite playback divides its total seconds
  into equal sounding and silent microsecond intervals.
- Validate playback duration before changing frequency or output state. Reject
  non-finite, negative, and unrepresentable duration values.
- Construct an LED GPIO in the application entry point and pass it by reference
  to `XWalkLed`. The LED controller stores a non-owning pointer and must not
  release or reconfigure ownership of the caller's GPIO.
- Stop and join an existing LED worker before direct on, off, toggle, close, or
  replacement-blink operations. Normal worker shutdown leaves the LED inactive.
- Keep LED blink continuation and output state atomic. Backend operations on the
  `noexcept` worker must not throw; a violation terminates the process.
- Divide each LED blink sequence into two transitions per requested cycle,
  followed by the inactive pause. Use bounded delay chunks so stop latency does
  not exceed the documented worker polling interval during normal scheduling.
- Call mutating `XWalkLed` operations from one controlling execution context.
  Only its atomic state accessors are intended for concurrent observation.
- Construct the USER GPIO as a pull-up input in the application entry point and
  pass it by reference to `XWalkUserButton`. The monitor stores a non-owning
  pointer and must not close or release the caller-owned GPIO.
- Poll the active-low user button at the shared 50-millisecond interval. Record
  press timing with the common monotonic clock and report durations in seconds.
- Treat the first GPIO sample after `start()` as the transition baseline and do
  not dispatch an event for that sample, preserving the established behavior.
- Clamp the shared user-button long-press threshold to 2.0 through 5.0 seconds.
  Capture the configured threshold and whether long callbacks exist when a
  press begins; later callback configuration does not alter the active press.
- Dispatch button callbacks outside the state mutex on the monitoring worker.
  Callback contexts are non-owning and must remain valid until cleared and the
  worker is joined. Callbacks must not stop or destroy their own monitor.
- Require GPIO and callback operations on the user-button worker to be
  non-throwing. A violation terminates the process.
- Keep `XWalkMusic` independent of `pygame`, `pyaudio`, and platform audio
  libraries. The application creates an audio backend and passes one non-owning
  context plus a complete `XWalkMusicCallbacks` operation table. Validate the
  full table before invoking the output-enable callback during construction.
- Keep sound-file interpretation, asynchronous playback, streamed transport,
  and physical PCM output inside the injected music backend. Keep time
  signatures, tempo, key displacement, note-frequency calculations, volume
  normalization, and PCM sample generation in the hardware-independent class.
- Preserve the music tone-data contract deliberately: halve the requested
  duration, generate truncated signed 16-bit mono sine frames at 44,100 Hertz,
  then append `frameCount % sampleRate` silent frames. Emit explicit
  little-endian bytes and document this compatibility behavior.
- Do not disable or release the injected music backend during destruction. The
  backend is caller-owned, and speaker activation has no matching destruction
  operation.
- Keep the default Music simulation device-free, file-free, and silent. Exercise
  the real theory, playback, transport, and PCM-generation interface over named
  in-memory callbacks without opening ALSA or reading audio resources. Keep the
  Music destructor free of trace and backend operations.
- Implement Linux music callbacks in `XWalkMusicAlsa`, which observes one
  caller-owned `XWalkAudioAlsa`. The audio owner outlives the adapter, and the
  adapter outlives `XWalkMusic`; no adapter releases the shared audio owner.
- Keep file decoding injectable for device-free host tests. The built-in music
  decoder accepts non-empty uncompressed 16-bit PCM RIFF/WAVE data with one
  through eight channels and rejects incomplete frames and malformed chunks.
- Provide compressed Music formats through the optional stateless libsndfile
  decoder operation. Convert decoded samples explicitly to signed 16-bit
  little-endian interleaved PCM, retain at most 64 MiB per operation, and keep
  libsndfile out of the hardware-independent Music target.
- Retain at most one background sound worker and one streamed-music worker.
  Write at most 1,024 frames per ALSA operation, observe pause and stop between
  writes, join replaced workers, and close every temporary PCM stream.
- Keep `XWalkSpeaker` independent of `pyaudio`, `soundfile`, `librosa`, and
  NumPy. Inject one non-owning backend context with callbacks for output power,
  decoding, stream opening, bounded frame writing, stream closing, and unique
  task identifiers.
- Bound one speaker controller to eight retained tasks and each backend write to
  1,024 complete frames. Decode before occupying a task slot, require complete
  interleaved frames with finite samples, and reject zero sample rates or
  channel counts.
- Treat backend stream handles as opaque, nullable values until open succeeds.
  The backend owns each opened stream; the speaker controller must close it
  exactly once without deleting or casting the handle.
- Call speaker task mutations from one controlling execution context. Coordinate
  playback workers through the state mutex. Backend operations on `noexcept`
  workers and during destruction must not throw; a violation terminates the
  process.
- Keep the default Speaker simulation device-free and silent. Exercise the real
  task controller over named in-memory decoder and stream callbacks with only a
  build-local fixture. Keep trace work out of `playbackLoop()`, task cleanup,
  output disable, worker callbacks, and destruction.
- Preserve the speaker format groups: WAV, FLAC, and OGG use the SoundFile
  decoder family; MP3, M4A, AAC, and WMA use the compressed-audio family.
- Implement Linux Speaker callbacks in `XWalkSpeakerAlsa`, which observes one
  caller-owned `XWalkAudioAlsa`. The audio owner outlives the adapter, and the
  adapter outlives the controller and all controller-owned workers.
- Bound the built-in PCM WAVE decoder to 16 MiB of input and 2,000,000 decoded
  interleaved samples per task. Require optional FLAC, OGG, or compressed codec
  libraries behind the injected decoder operation instead of linking the core.
- Convert normalized `float64` samples to explicit float32 little-endian PCM at
  the adapter boundary. Preserve the controller's 1,024-frame write limit and
  close every shared-audio stream exactly once through the adapter callback.
- Keep reusable Linux PCM and mixer ownership in `xWalkAudio`. Do not make
  Music depend on Speaker or Speaker depend on Music to obtain audio output.
- Create `XWalkAudioAlsa` before every audio adapter and consumer. Its injected
  ALSA-operation context is non-owning and must outlive the backend.
- Keep all libasound calls behind `XWalkAudioAlsaOperations`. Production uses
  the system operation table; host tests and the default standalone simulation
  inject `XWalkAudioHostStub` so ownership, playback, and mixer behavior run
  without opening an audio endpoint or changing host volume.
- Select PCM device, mixer device, and simple-element names through deployment
  configuration. Do not assume ALSA card zero; `default` and `PCM` are only
  configurable defaults.
- Retain at most eight PCM playback handles. Negotiate interleaved signed
  sixteen-bit little-endian or float32 little-endian samples, positive rate,
  one through eight channels, a period of at most 4,096 frames, and positive
  latency before publishing a stream handle.
- Bound each PCM write to one configured period, complete short writes, and
  allow at most three ALSA recovery attempts. Destruction closes every retained
  stream before the persistent mixer, and close callbacks must not throw.
- Use named register, address, clock, retry, and protocol constants from
  `xHal_Rpi5CarCommon.h`. Do not scatter unexplained hardware literals through
  production code.
- Place public hardware constants shared by module declarations, sources, or
  tests in `xWalk-rpi5-hw/xWalkLibrary/common/xHal_Rpi5CarCommon.h`. Module headers must not
  redeclare those constants. This includes ultrasonic sound-speed, timing,
  attempt-count, timeout-result, and invalid-pulse-result macros.
- Make byte order explicit when encoding register data.

## Concurrency and hardware I/O

- Protect a shared device handle or shared timer state with the project
  `mutexhandle` and `mutexlock` types.
- Keep lock scope large enough to make a complete hardware transaction atomic,
  including address selection and the following operation.
- Keep platform calls qualified with the global scope operator, for example
  `::open`, `::ioctl`, and `::close`.
- Bound retry loops with the configured retry count. Return immediately on
  success and throw a runtime error only after all write attempts fail.
- Keep hardware code optional, Linux-gated, and separate from host logic.

## Tests

- Add or update host tests for every behavior change. Host tests must use
  in-memory callbacks and must not open `/dev/i2c-*`.
- Configuration-store host tests may use the real filesystem only below their
  module-local CMake binary directory. They must not write to `/opt`, a user
  directory, or a deployed robot configuration path.
- Use small test functions named `test<Behavior>` and plain `assert` checks,
  matching the existing lightweight test executables.
- Keep reusable fake hardware in test helper classes such as
  `XWalkPwmTestI2c`. Record the interaction needed for assertions: probes,
  addresses, registers, and payloads.
- Keep reusable test callback state, fake-backend structures, mapping records,
  callback declarations, and callback-table factories in a dedicated
  `<Component>TestSupport.h` under the owning module's `test/include` directory.
  Put their non-trivial function definitions in the matching
  `<Component>TestSupport.cpp` under `test/src`; scenario test sources contain
  fixtures and test cases rather than reusable callback implementations.
- Put shared test support in the owning layer's named component namespace, such
  as `xwalk::hal::test::gpio`. Never place an anonymous namespace in a header:
  it creates a different type and function identity in every translation unit.
  Component nesting also prevents helper-name collisions in aggregate test
  runners. List the support source explicitly in standalone and aggregate test
  targets. Apply this layout across `xWalkHal`, `xWalkAgent`, and
  `xWalkController` whenever a test is added or modified.
- Test public results and observable bus traffic, including register selection,
  byte order, state shared between channels, and validation failures.
- Add a selector in the test main and a separately named CTest entry when adding
  a PWM or Servo test scenario.
- Label simulated tests `host` and physical-device tests `hardware`.
- Keep all hardware-test build options `OFF` by default. Never run a hardware
  test as part of ordinary verification or without the correct Raspberry Pi and
  Robot HAT safety setup.
- Compile-check the hardware targets after changes to `xWalk-rpi5-hw/xWalkLibrary/common`, `xWalkI2c`, `xWalkSpi`,
  `xWalkAudio`, `xWalkMusic`, `xWalkSpeaker`, `xWalkPwm`, `xWalkServo`, `xWalkGpio`,
  `xWalkUltrasonic`,
  `xWalkLineTracker`, `xWalkAdxl345`, `xWalkBuzzer`, `xWalkLed`,
  `xWalkUserButton`, `xWalkBoardControl`, `xWalkTrace`, `xWalkGPT`,
  `xWalkLanguageModel`, `xWalkVoiceAssistant`, `xWalkUtils`, their public
  headers, or their CMake configuration.
  Compilation is safe on a Linux host and does not access the physical I2C
  device.
- Use `ctest -N -L hardware` only to list registered hardware tests during a
  compile check. Do not omit `-N`, because doing so would execute the tests.
- In the aggregate host build directory, run plain `ctest` to execute every
  registered host and unit test.
- In the aggregate RPI build directory, run plain `ctest` only on the connected
  target after the hardware setup has passed its safety review. This executes
  every registered hardware test.

## CMake conventions

- Require at least CMake 3.16 and declare `LANGUAGES CXX` for concrete modules.
- Use target-based commands: `target_include_directories`,
  `target_compile_features`, `target_link_libraries`, and
  `target_compile_options`.
- Use `PUBLIC`, `PRIVATE`, and `INTERFACE` deliberately; do not introduce global
  include directories or compiler flags.
- Let a module add an adjacent dependency only when its target does not already
  exist. Give the dependency a dedicated binary directory.
- Resolve the workspace-level `xWalkLibraryCommon` target source from
  `../../../xWalkLibrary/common` when configuring an individual grouped HAL
  submodule. The workspace root imports it from `xWalk-rpi5-hw/xWalkLibrary/common`.
- Name feature options `XWALK_<MODULE>_BUILD_<MODE>_TESTS` and default them to
  `OFF`.
- Register tests with descriptive stable names and labels.
- In `.md` files only, keep every fenced shell-command example on one physical
  line. Do not use a trailing backslash to wrap CMake configure, build, or CTest
  commands. These command lines are exempt from the 115-character limit.
- Use module-local build directories such as `xWalkServo/build-host` and
  `xWalkServo/build-rpi` in documented commands. Do not require `/tmp` paths.
- Use the workspace root and its presets for release-wide sanity, Clang-Tidy,
  sanitizer, coverage, staging, and package builds. Keep those outputs in the
  corresponding `build-host/<purpose>` or `build-rpi/cmake` directory and use
  `cmake --fresh` when changing source trees or build modes.
- Install mutable deployment configuration separately from read-only binaries,
  media, and documentation. Default the active PiCar-X configuration to an
  explicitly writable system location rather than a source-tree path.
- Use `GNUInstallDirs`, `/usr` as the package prefix, and `DESTDIR` for local
  staging. Install immutable resources under the configured data directory,
  administrator configuration under `/etc/xwalk`, and runtime state under
  `/var/lib/xwalk`, `/var/cache/xwalk`, or `/run/xwalk`.
- Keep Raspberry Pi setup idempotent and dry-run-first. Maintain the reviewed
  Robot HAT v4, `xwalk` runtime-user, device-node, and CSI-camera defaults in
  `xWalk-rpi5-tool/shell-agent/deploy-tool/rpi-defaults.conf`; preserve explicit
  command-line overrides and do not infer or install a board overlay from
  failed discovery.
- Grant device permissions through standard operating-system groups and exact
  configured I2C, GPIO, and SPI node matches. Do not add broad device wildcards.

## Command-line application conventions

- Keep the standalone `xWalkController` aggregate beside `xWalkAgent` and `xWalkHal`.
  Keep its reusable controller contract, implementation, and direct in-memory
  test under `xWalkHandler`. Keep host entry behavior in `xWalkApp/cli/host`, Raspberry
  Pi entry behavior in `xWalkApp/cli/hardware`, command parsing in `xWalkApp/parse`, boot
  composition in `xWalkApp/boot`, command activation in `xWalkApp/activate`, and
  executable-level application tests in `xWalkApp/test`. Keep executable targets
  and CTest registration in `xWalkApp/CMakeLists.txt`. Do not place these directories
  inside `xWalkAgent`.
- Give `xWalkApp` one host GoogleTest executable with the `XWalkAppGroup`
  suite. Resolve the sibling host CLI relative to `/proc/self/exe`, launch
  each scenario in an isolated child process, and register the complete
  executable once with CTest. Keep physical hardware unavailable in these
  application tests.
- Keep the one tracked controller deployment file at
  `xWalk-rpi5-hw/xWalkController/xWalkConfig/picar-x.conf`. Select Robot HAT revisions through
  its `hardware_board` value; do not maintain separate board-profile files.
- Keep CLI-owned unit tests under `xWalk-rpi5-hw/xWalkController/xWalkTest/xGoogleTest`. Let
  that directory own the `xCliGoogleTest` process entry point so it can coexist
  with the HAL `xGoogleTest` target. Compile assertion-based unit-test entry
  points with distinct renamed functions, isolate them in child processes, and
  select tests through the complete strict XML inventory owned by the unit-test
  directory. Name each GoogleTest suite after its owning Controller or Agent
  functional group. Build and register this runner only in CLI host mode.
- Keep bounded multi-command CLI verification under
  `xWalk-rpi5-hw/xWalkController/xWalkTest/xSequenceTest`. Let that directory own the
  independent `xCliSequenceTest` process entry point and GoogleTest sequence
  registration plus complete host and disabled-hardware XML inventories. Name
  sequence suites after their owning Controller or Agent functional group and
  load enabled suites and cases from the sequence directory's strict XML.
  Validate the complete command list before execution, accept no more than 32
  non-empty commands, retain one caller-owned controller through a non-owning
  pointer, and stop at the first non-zero command status. Do not add a physical
  CLI sequence until its command flow, runtime bound, hardware composition, and
  safety conditions are reviewed.
- Let `xWalkController` import the sibling `xWalkAgent` aggregate. Agent owns
  `xWalkPicarx`, `xWalkLineTracking`, `xWalkSelfDrive`, and `xWalkBoot`; Controller links
  those targets without duplicating their source directories.
- Keep `XWALK_CLI_BUILD_HOST` and `XWALK_CLI_BUILD_RPI` mutually exclusive and
  `OFF` by default. Map them to the Controller test options and use separate
  `build-host` and `build-rpi` directories. Label the RPI test `hardware` and
  do not execute it on Ubuntu.
- Use `xwalk-picarx-control <command> [options]` as the stable command shape.
- Accept named options as `--name value`, `--name=value`, or `name=value`.
  Accept one flat JSON object through `--config FILE.json`; direct options take
  precedence over JSON values.
- Keep JSON parsing bounded to scalar configuration. Reject nested arrays and
  objects rather than silently ignoring unsupported configuration.
- Execute a command only when the CLI owns a complete safe composition. Return
  a distinct backend-unavailable status for optional services such as audio.
- Route every non-help production Controller command through
  `xWalkController/xWalkScheduler`. Use separate stable Controller, Agent, and
  HAL mailbox IDs, create one scheduler child per registered mailbox, and keep
  same-mailbox requests sequential while allowing separate mailboxes to run in
  parallel. A `cxx_xWalk*Send_LPP` name identifies its destination module.
  Keep the native scheduler signal, module interfaces, and tests independent of
  Protobuf, gRPC, and server code; a future server is only a transport adapter.
  Keep direct Controller command-runner calls limited to scheduler child
  adapters and focused in-memory tests; application entry points must not invoke
  a handler or xWalkBoot directly.
- Fork the scheduler child before constructing xWalkBoot, Agent, HAL, listener,
  camera, GPIO, I2C, SPI, audio, or motor resources. Open and release those
  resources in the owning child. Use fixed-size pointer-free `SOCK_SEQPACKET`
  messages, fixed-capacity FIFO and status tables, tracked positive PIDs,
  bounded graceful shutdown, exact-PID `SIGTERM`, and `waitpid()` reaping. Do
  not add a thread-based Controller handler dispatcher or process-name killing.
- Enter RPI backend composition through one automatic `XWalkBootRpi` object.
  Pass one `xAgentContext` to every Boot `run*` interface, invoke its application
  callback at most once, consume a failed run attempt, and retain the stack-owned
  backend graph until command completion. Return help before constructing the
  boot object so discovery claims no platform resource.
- Construct `XWalkPicarx` from one `xAgentContext`. Populate `config`, `motors`,
  `dirServo`, `panServo`, `tiltServo`, `grayscale`, and `ultrasonic`; each field
  is required and non-owning, and every referenced object must outlive the
  coordinator.
- Boot every backend required by the selected command exactly once. Do not
  initialize HAL backends that lack a CLI command or explicit deployment
  configuration, including microphone, recognizer, synthesizer, model endpoint,
  and unrelated GPIO roles.
- Load deployment configuration before opening hardware. Pass configured I2C,
  GPIO, and Device Tree paths into their Linux owners. Never select the first
  `/dev/gpiochip*`; verify optional exact chip identity and fail before MCU
  reset when automatic board detection cannot establish a supported mapping.
- Provide explicit Robot HAT v4 and v5 deployment profiles. Automatic and v5
  selection require the supported v5 UUID; v4 selection must be explicit and
  must reject a detected v5 overlay. Provision one GPIO path, kernel chip name,
  and label before actuator boot, then retain runtime validation before reset.
- Select camera deployment through configuration. Use `csi` for a Raspberry Pi
  Camera Serial Interface device and `usb` for a V4L2 webcam. Keep capture
  executables and device paths outside the Agent, invoke providers without a
  shell, and enforce the HAL capture deadline in the parent process.
- Keep the default Camera simulation device-free. Compose `XWalkCamera` with a
  named in-memory capture callback and validate the destination and bounded
  settings without opening a camera, starting a process, or creating an image
  file. Persist trace-selector changes in generated XML for the next run.
- Keep host command parsing independent of Linux hardware headers. Inject
  console, timing, cancellation, and audio callbacks into `XWalkController`.
  Store the
  caller-owned PiCar-X coordinator and callback context as non-owning pointers.
- Use one process cancellation query for every moving CLI command. Poll it in
  delay slices no longer than 20 milliseconds for move, turn, and self-drive,
  latch emergency stop on cancellation, and install SIGINT and SIGTERM handlers
  before any non-help Raspberry Pi command boots hardware.
- Add command-specific Agent services through constructor-reference overloads.
  Store their addresses as nullable non-owning pointers, report status three
  when a command is invoked without its service, and compose only the service
  selected by the process command.
- Keep `line-track` limited to `start` and `stop`. Run `start` in the foreground
  by repeatedly calling the bounded line-tracking step while the injected
  cancellation query permits it, report each returned grayscale sample and
  classified state, and finish with the upstream 100-millisecond delay after
  stopping the motors. Let the RPI application map SIGINT and SIGTERM to that
  cancellation query.
- Keep `computer-vision` independent of the PiCar-X actuator graph. Compose only
  the configured camera and OpenCV provider, retain source-compatible keys and
  500-millisecond post-key timing, and never start an implicit web listener.
  Store photographs only under the configured local directory and keep physical
  camera execution outside ordinary host verification.
- Keep `stare-at-you` on the base PiCar-X graph plus the configured OpenCV
  provider. Preserve the upstream frame-relative correction formula, clamp
  retained pan and tilt commands to 35 degrees, and stop both the provider and
  motors on every foreground exit. Keep physical camera and servo execution
  outside ordinary host verification.
- Keep `bull-fight` on the base PiCar-X graph plus configured OpenCV red
  detection. Preserve the upstream camera correction, 35-degree camera bounds,
  direct pan-angle steering call, 50-percent requested speed, and 50 ms sample
  delay. Apply the normal calibration output cap and require explicit hardware
  test approval because successful observations move the vehicle.
- Keep `record-video` camera-only. Run continuous capture in the provider so
  blocking terminal input does not interrupt frame acquisition, preserve the
  upstream start/pause/continue/stop transitions and delays, and keep output
  under the configured local directory. Never run physical recording in host
  verification.
- Keep `app-control` on the base PiCar-X graph with injected transport, camera,
  and sound providers. Preserve the SunFounder A-Q widget mapping, bind the
  WebSocket listener only to the explicitly configured address and port, bound
  messages and line-loss recovery, and never start an implicit video server.
  Default to loopback and require an explicit deployment change for LAN access.
- Keep `sound-background-music` on the shared `XWalkMusic` abstraction and
  explicitly configured sound/music directories. Preserve the upstream Space
  synchronous horn, `c` background horn, `q` music toggle, 20-percent music
  volume, and 50 ms post-horn delay. Stop active music on every foreground exit
  and never open a physical audio endpoint in host verification.
- Keep `voice-prompt-car` in its standalone Agent with caller-owned PiCar-X and
  text-to-speech services. Preserve the source greeting, prompt order, 30-percent
  requested speed, two-second movement duration, and minus/plus 20-degree turns.
  Stop the motors and centre steering on every exit, and require explicit
  approval before physical speech or movement testing.
- Keep `storytelling-robot` in its standalone Agent with caller-owned PiCar-X
  and text-to-speech services. Preserve the Piper `en_US-amy-low` default,
  source narration order, two three-second forward legs, six-second backward
  leg, and 30-percent requested speed. Slice movement delays for cancellation,
  stop and centre on every exit, and keep Piper process execution in the HAL
  provider rather than the portable Agent.
- Keep `text-vision-talk` in its standalone camera-and-language-model Agent.
  Preserve the source instructions, welcome, 20-message history, two-second
  warm-up, 1280-by-720 capture, `/tmp/llm-img.jpg` replacement, and normalized
  `exit` or `quit` termination. Keep Ollama transport and physical camera
  ownership in the optional Raspberry Pi boot composition.
- Keep `online-llm-test` in its standalone language-model Agent. Preserve the
  source instructions, welcome, 20-message history, `gpt-4o` default, and
  externally cancelled text-only prompt loop. Read the credential only from
  `OPENAI_API_KEY`; never place it in arguments, configuration, or diagnostics.
- Keep `servo-zeroing` in its standalone callback-driven Agent. Preserve MCU
  reset, channels zero through eleven in ascending order, the 10-degree and
  zero-degree commands with 100 ms delays, and the cancellable idle loop.
  Physical verification requires explicit Robot HAT safety confirmation.
- Keep `voice-active-car-gpt` as the example-21 Jarvis profile over the shared
  sensor/action coordinator. Preserve the ten-centimetre trigger, `hey jarvis`
  wake phrase, Jarvis wake acknowledgement, filtered action instructions,
  Gemini `gemini-3.6-flash`, and Piper `en_GB-alan-medium`. Read the Gemini
  credential only from `GEMINI_API_KEY`. Keep this profile permanently text-only:
  do not read camera configuration, construct camera services, install an image
  callback, or attach an image path. Preserve concise 256-token spoken responses
  and a bounded continuous session with configured idle, round, miss, and
  sleep-phrase exits. Sleep phrases must bypass the model and action parser;
  every session-ending path must stop vehicle output.
- Keep `voice-active-car` as the canonical `voice_active_car.py` Rolly profile
  over the shared sensor/action coordinator. Preserve the ten-centimetre
  trigger, image input, `hey rolly` wake phrase, `Hi there` wake response,
  English recognition setting, full assistant instructions, and OpenAI
  `gpt-4o-mini`. Read credentials only from `OPENAI_API_KEY`, and require the
  wake phrase before every ordinary model round.
- Keep `gpt-car` as the `gpt_examples/gpt_car.py` profile over the shared
  voice-car and SelfDrive coordinators. Preserve voice and keyboard input,
  optional image attachment, the JSON `actions` and `answer` response contract,
  all preset gestures and sound effects, and environment-only OpenAI credentials.
- Execute `self-drive <action>` synchronously through one caller-owned
  `XWalkSelfDrive`. Publish every action with a canonical hyphenated CLI name,
  normalize hyphens to the Agent's exact spaced action name, and continue to
  accept separate action words for compatibility. Let the Agent validate the
  complete upstream action name before changing hardware.
- Build the `xWalkBootRpi` composition root only for RPI mode. Enable the
  Linux I2C and GPIO backend targets through the PiCar-X hardware dependency.
- Never claim GPIO lines, move actuators, enable powered outputs, start audio,
  or contact an external service merely to discover a command or report status.
- Construct project objects in `XWalkBootRpi::run()`, progressively populate
  the non-owning dependency pointers in a copied `xAgentContext`, and preserve
  the same ownership and lifetime rules as any other application composition
  root. Each `run*` stage requires only its documented context fields.
  Command-specific optional graphs may remain in their selected branch but must
  outlive the command invocation.
- Keep Agent modules physically nested under the documented functional group
  directory matching their primary responsibility. Each group owns only its
  source-tree organization and interface target; it must not merge coordinators,
  rename child targets or public headers, or weaken module test boundaries. Keep
  `xWalk::Agent` as the complete aggregate and allow focused consumers to link
  the documented group aliases. Give every group one GoogleTest host executable
  with one named case per child module and link it only through the group
  interface target. Reuse deterministic child tests in isolated processes and
  test public behavior directly where no child test exists. Resolve child test
  executables relative to `/proc/self/exe`; do not expose their build paths as
  C++ preprocessor identifiers. Label these tests `host;agent-group`. Give every
  group matching GoogleTest Raspberry Pi
  build-profile cases under `test/hardware` and label the executable
  `hardware;agent-group`. Keep physical device behavior in the owning child
  hardware tests and never execute it without the required safety approval.
  Give the root Agent aggregate one GoogleTest case per functional group. Run
  each group executable in an isolated process, label the host aggregate
  `host;agent;agent-aggregate`, and provide a matching opt-in hardware aggregate
  labelled `hardware;agent;agent-aggregate`.

## Agent conventions

- Keep `xWalkAgent` beside `xWalkHal`. Normal Agent modules coordinate caller-owned
  HAL objects and must not duplicate physical I/O backends or own injected
  project dependencies. `xWalkBoot` is the intentional composition-boundary
  exception: its optional RPi target owns platform backends only for one
  synchronous application callback, while its core target remains device-free.
- Name agent public headers and sources `xAgent_Rpi5Car<Component>.h` and
  `xAgent_Rpi5Car<Component>.cpp`. Put production declarations in
  `namespace xwalk::agent` while retaining project scalar and container types
  from `xwalk::hal`.
- Give every agent submodule independent host and hardware test options. The
  aggregate `XWALK_AGENT_BUILD_HOST` and `XWALK_AGENT_BUILD_RPI` options must be
  mutually exclusive and default to `OFF`.
- Keep MCU reset and other temporary hardware claims in `xWalkBootRpi`
  root when a later dependency must claim the same physical resource. Destroy
  the temporary backend before constructing the long-lived dependency.
- Keep CLI parsing and sequencing hardware-independent. Inject console, delay,
  audio, and other platform operations, and bind Linux hardware only in the
  optional `xWalkBootRpi` composition target. Application `main()` selects a
  boot mode and consumes non-owning services during the boot callback.
- Keep `XWalkSelfDrive` limited to named gesture, movement, sound, status, and
  queue behavior. Inject `XWalkPicarx`,
  `XWalkMusic`, and timing; the coordinator must not create hardware, audio,
  clock, random, or process backends.
- Preserve the preset action names, ordered actuator commands, relative sound
  paths, volumes, and millisecond delays. Reject unknown queued actions without
  partial execution. The worker delay callback is a non-throwing Boolean status
  operation. A false result latches emergency stop, terminates action processing,
  and makes `waitActionsDone()` return false. Other worker callbacks must remain
  non-throwing because workspace code does not install exception handlers.
- Keep `XWalkLineTracking` limited to line-status decision behavior. Inject
  `XWalkPicarx` and timing, expose one
  bounded step, and leave repeated scheduling, cancellation, and diagnostics
  in the application.
- Preserve line-status priority, steering signs, default movement values, and
  last-direction recovery. Bound recovery sampling and stop the motors when it
  reaches that bound or has no prior left or right direction.

## Documentation and change checklist

Follow the complete Doxygen and MISRA C++-oriented comment standard in
[`DOCUMENTATION_GUIDELINES.md`](DOCUMENTATION_GUIDELINES.md). That document is
authoritative for file headers, section comments, API documentation, namespace
comments, ownership statements, and documentation review.

For a new implementation or a changed public behavior:

1. Place the declaration and implementation in the correct responsibility
   files.
2. Move reusable non-member production logic into `xWalk-rpi5-hw/xWalkLibrary/common` and
   `xwalk::hal::common`; keep class-specific logic in methods.
3. Preserve dependency injection and the host/hardware boundary.
4. Validate inputs, conversions, register limits, and ownership assumptions.
5. Add host coverage and, only when necessary, an opt-in hardware test.
6. Add new sources and tests to CMake with the correct visibility and label.
7. Update the module README when its API, layout, build options, test commands,
   hardware behavior, or validation status changes.
8. Update `Doc` when cross-module API mapping, board behavior, protocol,
   installation, project architecture, or safety guidance changes. Keep
   `PORTING_MANIFEST.md` aligned with the upstream documentation coverage.
9. Build with warnings enabled and run the relevant host CTest suite.
10. Re-read this guide. Update it only if the change deliberately establishes a
   reusable project convention.

Typical host verification commands are:

```bash
cmake -S xWalkController -B xWalk-rpi5-hw/xWalkController/build-host -DXWALK_CLI_BUILD_HOST=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalk-rpi5-hw/xWalkController/build-host --parallel
ctest --test-dir xWalk-rpi5-hw/xWalkController/build-host --output-on-failure

cmake -S xWalkAgent -B xWalk-rpi5-hw/xWalkAgent/build-host -DXWALK_AGENT_BUILD_HOST=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalk-rpi5-hw/xWalkAgent/build-host --parallel
ctest --test-dir xWalk-rpi5-hw/xWalkAgent/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/interface/xWalkI2c -B xWalk-rpi5-hw/xWalkHal/interface/xWalkI2c/build-host -DXWALK_I2C_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkI2c/build-host --parallel
ctest --test-dir xWalkI2c/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/interface/xWalkSpi -B xWalk-rpi5-hw/xWalkHal/interface/xWalkSpi/build-host -DXWALK_SPI_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkSpi/build-host --parallel
ctest --test-dir xWalkSpi/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/interface/xWalkAudio -B xWalk-rpi5-hw/xWalkHal/interface/xWalkAudio/build-host -DXWALK_AUDIO_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkAudio/build-host --parallel
ctest --test-dir xWalkAudio/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/layer1/xWalkMusic -B xWalk-rpi5-hw/xWalkHal/layer1/xWalkMusic/build-host -DXWALK_MUSIC_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkMusic/build-host --parallel
ctest --test-dir xWalkMusic/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/layer1/xWalkSpeaker -B xWalk-rpi5-hw/xWalkHal/layer1/xWalkSpeaker/build-host -DXWALK_SPEAKER_BUILD_HOST_TESTS=ON
cmake --build xWalkSpeaker/build-host --parallel
ctest --test-dir xWalkSpeaker/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/device/xWalkPwm -B xWalk-rpi5-hw/xWalkHal/device/xWalkPwm/build-host -DXWALK_PWM_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkPwm/build-host --parallel
ctest --test-dir xWalkPwm/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/device/xWalkServo -B xWalk-rpi5-hw/xWalkHal/device/xWalkServo/build-host -DXWALK_SERVO_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkServo/build-host --parallel
ctest --test-dir xWalkServo/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/device/xWalkAdc -B xWalk-rpi5-hw/xWalkHal/device/xWalkAdc/build-host -DXWALK_ADC_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkAdc/build-host --parallel
ctest --test-dir xWalkAdc/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/interface/xWalkGpio -B xWalk-rpi5-hw/xWalkHal/interface/xWalkGpio/build-host -DXWALK_GPIO_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkGpio/build-host --parallel
ctest --test-dir xWalkGpio/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/sensor/xWalkMotor -B xWalk-rpi5-hw/xWalkHal/sensor/xWalkMotor/build-host -DXWALK_MOTOR_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkMotor/build-host --parallel
ctest --test-dir xWalkMotor/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/interface/xWalkConfig -B xWalk-rpi5-hw/xWalkHal/interface/xWalkConfig/build-host -DXWALK_CONFIG_BUILD_HOST_TESTS=ON
cmake --build xWalkConfig/build-host --parallel
ctest --test-dir xWalkConfig/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/layer1/xWalkBoardControl -B xWalk-rpi5-hw/xWalkHal/layer1/xWalkBoardControl/build-host -DXWALK_BOARD_CONTROL_BUILD_HOST_TESTS=ON
cmake --build xWalkBoardControl/build-host --parallel
ctest --test-dir xWalkBoardControl/build-host --output-on-failure

cmake -S xWalkTrace -B xWalk-rpi5-hw/xWalkTrace/build-host -DXWALK_TRACE_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalk-rpi5-hw/xWalkTrace/build-host --parallel
ctest --test-dir xWalk-rpi5-hw/xWalkTrace/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/layer1/xWalkGPT -B xWalk-rpi5-hw/xWalkHal/layer1/xWalkGPT/build-host -DXWALK_GPT_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkGPT/build-host --parallel
ctest --test-dir xWalkGPT/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/interface/xWalkLanguageModel -B xWalk-rpi5-hw/xWalkHal/interface/xWalkLanguageModel/build-host -DXWALK_LANGUAGE_MODEL_BUILD_HOST_TESTS=ON
cmake --build xWalkLanguageModel/build-host --parallel
ctest --test-dir xWalkLanguageModel/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/layer1/xWalkVoiceAssistant -B build/xWalkVoiceAssistant-host -DXWALK_VOICE_ASSISTANT_BUILD_HOST_TESTS=ON
cmake --build build/xWalkVoiceAssistant-host --parallel
ctest --test-dir build/xWalkVoiceAssistant-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/interface/xWalkUtils -B build-utils-host -DXWALK_UTILS_BUILD_HOST_TESTS=ON
cmake --build build-utils-host --parallel
ctest --test-dir build-utils-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/layer1/xWalkRobot -B xWalk-rpi5-hw/xWalkHal/layer1/xWalkRobot/build-host -DXWALK_ROBOT_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkRobot/build-host --parallel
ctest --test-dir xWalkRobot/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/device/xWalkUltrasonic -B xWalk-rpi5-hw/xWalkHal/device/xWalkUltrasonic/build-host -DXWALK_ULTRASONIC_BUILD_HOST_TESTS=ON
cmake --build xWalkUltrasonic/build-host --parallel
ctest --test-dir xWalkUltrasonic/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/sensor/xWalkLineTracker -B xWalk-rpi5-hw/xWalkHal/sensor/xWalkLineTracker/build-host -DXWALK_LINE_TRACKER_BUILD_HOST_TESTS=ON
cmake --build xWalkLineTracker/build-host --parallel
ctest --test-dir xWalkLineTracker/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/device/xWalkAdxl345 -B xWalk-rpi5-hw/xWalkHal/device/xWalkAdxl345/build-host -DXWALK_ADXL345_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkAdxl345/build-host --parallel
ctest --test-dir xWalkAdxl345/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/sensor/xWalkBuzzer -B xWalk-rpi5-hw/xWalkHal/sensor/xWalkBuzzer/build-host -DXWALK_BUZZER_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkBuzzer/build-host --parallel
ctest --test-dir xWalkBuzzer/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/sensor/xWalkLed -B xWalk-rpi5-hw/xWalkHal/sensor/xWalkLed/build-host -DXWALK_LED_BUILD_HOST_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkLed/build-host --parallel
ctest --test-dir xWalkLed/build-host --output-on-failure

cmake -S xWalk-rpi5-hw/xWalkHal/device/xWalkUserButton -B xWalk-rpi5-hw/xWalkHal/device/xWalkUserButton/build-host -DXWALK_USER_BUTTON_BUILD_HOST_TESTS=ON
cmake --build xWalkUserButton/build-host --parallel
ctest --test-dir xWalkUserButton/build-host --output-on-failure

```

Typical Linux hardware compilation commands are:

```bash
cmake -S xWalkController -B xWalk-rpi5-hw/xWalkController/build-rpi -DXWALK_CLI_BUILD_RPI=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalk-rpi5-hw/xWalkController/build-rpi --parallel
ctest --test-dir xWalk-rpi5-hw/xWalkController/build-rpi -N -L hardware

cmake -S xWalkAgent -B xWalk-rpi5-hw/xWalkAgent/build-rpi -DXWALK_AGENT_BUILD_RPI=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalk-rpi5-hw/xWalkAgent/build-rpi --parallel
ctest --test-dir xWalk-rpi5-hw/xWalkAgent/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/interface/xWalkI2c -B xWalk-rpi5-hw/xWalkHal/interface/xWalkI2c/build-rpi -DXWALK_I2C_BUILD_HARDWARE_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkI2c/build-rpi --parallel
ctest --test-dir xWalkI2c/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/interface/xWalkSpi -B xWalk-rpi5-hw/xWalkHal/interface/xWalkSpi/build-rpi -DXWALK_SPI_BUILD_HARDWARE_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkSpi/build-rpi --parallel
ctest --test-dir xWalkSpi/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/interface/xWalkAudio -B xWalk-rpi5-hw/xWalkHal/interface/xWalkAudio/build-rpi -DXWALK_AUDIO_BUILD_HARDWARE_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkAudio/build-rpi --parallel
ctest --test-dir xWalkAudio/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/layer1/xWalkMusic -B xWalk-rpi5-hw/xWalkHal/layer1/xWalkMusic/build-rpi -DXWALK_MUSIC_BUILD_HARDWARE_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkMusic/build-rpi --parallel
ctest --test-dir xWalkMusic/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/layer1/xWalkSpeaker -B xWalk-rpi5-hw/xWalkHal/layer1/xWalkSpeaker/build-rpi -DXWALK_SPEAKER_BUILD_HARDWARE_TESTS=ON
cmake --build xWalkSpeaker/build-rpi --parallel
ctest --test-dir xWalkSpeaker/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/device/xWalkPwm -B xWalk-rpi5-hw/xWalkHal/device/xWalkPwm/build-rpi -DXWALK_PWM_BUILD_HARDWARE_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkPwm/build-rpi --parallel
ctest --test-dir xWalkPwm/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/device/xWalkServo -B xWalk-rpi5-hw/xWalkHal/device/xWalkServo/build-rpi -DXWALK_SERVO_BUILD_HARDWARE_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkServo/build-rpi --parallel
ctest --test-dir xWalkServo/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/device/xWalkAdc -B xWalk-rpi5-hw/xWalkHal/device/xWalkAdc/build-rpi -DXWALK_ADC_BUILD_HARDWARE_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkAdc/build-rpi --parallel
ctest --test-dir xWalkAdc/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/interface/xWalkGpio -B xWalk-rpi5-hw/xWalkHal/interface/xWalkGpio/build-rpi -DXWALK_GPIO_BUILD_HARDWARE_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkGpio/build-rpi --parallel
ctest --test-dir xWalkGpio/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/sensor/xWalkMotor -B xWalk-rpi5-hw/xWalkHal/sensor/xWalkMotor/build-rpi -DXWALK_MOTOR_BUILD_HARDWARE_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkMotor/build-rpi --parallel
ctest --test-dir xWalkMotor/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/interface/xWalkConfig -B xWalk-rpi5-hw/xWalkHal/interface/xWalkConfig/build-rpi -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkConfig/build-rpi --parallel

cmake -S xWalk-rpi5-hw/xWalkHal/layer1/xWalkBoardControl -B xWalk-rpi5-hw/xWalkHal/layer1/xWalkBoardControl/build-rpi -DXWALK_BOARD_CONTROL_BUILD_HARDWARE_TESTS=ON
cmake --build xWalkBoardControl/build-rpi --parallel
ctest --test-dir xWalkBoardControl/build-rpi -N -L hardware

cmake -S xWalkTrace -B xWalk-rpi5-hw/xWalkTrace/build-rpi -DXWALK_TRACE_BUILD_HARDWARE_TESTS=ON
cmake --build xWalk-rpi5-hw/xWalkTrace/build-rpi --parallel
ctest --test-dir xWalk-rpi5-hw/xWalkTrace/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/layer1/xWalkGPT -B xWalk-rpi5-hw/xWalkHal/layer1/xWalkGPT/build-rpi -DXWALK_GPT_BUILD_HARDWARE_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkGPT/build-rpi --parallel
ctest --test-dir xWalkGPT/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/interface/xWalkLanguageModel -B xWalk-rpi5-hw/xWalkHal/interface/xWalkLanguageModel/build-rpi -DXWALK_LANGUAGE_MODEL_BUILD_HARDWARE_TESTS=ON
cmake --build xWalkLanguageModel/build-rpi --parallel
ctest --test-dir xWalkLanguageModel/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/layer1/xWalkVoiceAssistant -B build-va-rpi -DXWALK_VOICE_ASSISTANT_BUILD_HARDWARE_TESTS=ON
cmake --build build-va-rpi --parallel
ctest --test-dir build-va-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/interface/xWalkUtils -B build-utils-rpi -DXWALK_UTILS_BUILD_HARDWARE_TESTS=ON
cmake --build build-utils-rpi --parallel
ctest --test-dir build-utils-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/layer1/xWalkRobot -B xWalk-rpi5-hw/xWalkHal/layer1/xWalkRobot/build-rpi -DXWALK_ROBOT_BUILD_HARDWARE_TESTS=ON -DCMAKE_BUILD_TYPE=Debug
cmake --build xWalkRobot/build-rpi --parallel
ctest --test-dir xWalkRobot/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/device/xWalkUltrasonic -B xWalk-rpi5-hw/xWalkHal/device/xWalkUltrasonic/build-rpi -DXWALK_ULTRASONIC_BUILD_HARDWARE_TESTS=ON
cmake --build xWalkUltrasonic/build-rpi --parallel
ctest --test-dir xWalkUltrasonic/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/sensor/xWalkLineTracker -B xWalk-rpi5-hw/xWalkHal/sensor/xWalkLineTracker/build-rpi -DXWALK_LINE_TRACKER_BUILD_HARDWARE_TESTS=ON
cmake --build xWalkLineTracker/build-rpi --parallel
ctest --test-dir xWalkLineTracker/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/device/xWalkAdxl345 -B xWalk-rpi5-hw/xWalkHal/device/xWalkAdxl345/build-rpi -DXWALK_ADXL345_BUILD_HARDWARE_TESTS=ON
cmake --build xWalkAdxl345/build-rpi --parallel
ctest --test-dir xWalkAdxl345/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/sensor/xWalkBuzzer -B xWalk-rpi5-hw/xWalkHal/sensor/xWalkBuzzer/build-rpi -DXWALK_BUZZER_BUILD_HARDWARE_TESTS=ON
cmake --build xWalkBuzzer/build-rpi --parallel
ctest --test-dir xWalkBuzzer/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/sensor/xWalkLed -B xWalk-rpi5-hw/xWalkHal/sensor/xWalkLed/build-rpi -DXWALK_LED_BUILD_HARDWARE_TESTS=ON
cmake --build xWalkLed/build-rpi --parallel
ctest --test-dir xWalkLed/build-rpi -N -L hardware

cmake -S xWalk-rpi5-hw/xWalkHal/device/xWalkUserButton -B xWalk-rpi5-hw/xWalkHal/device/xWalkUserButton/build-rpi -DXWALK_USER_BUTTON_BUILD_HARDWARE_TESTS=ON
cmake --build xWalkUserButton/build-rpi --parallel
ctest --test-dir xWalkUserButton/build-rpi -N -L hardware

```

These commands compile the Linux backend and hardware-test executables but do
not run them. A successful Servo hardware build also compiles its PWM and I2C
hardware dependencies. `xWalkConfig` has no physical-hardware tests; its target
command compiles only the production filesystem library.

## Current verification status

As of 2026-08-06:

- The standalone xWalkController host suite passes, and its Controller executable
  builds in the aggregate host and Ubuntu/RPI configurations.
- The CLI `xCliGoogleTest` runner passes its isolated Controller unit case
  through strict XML group selection. The independent `xCliSequenceTest`
  runner passes the bounded command-sequence cases selected from its own strict
  grouped XML inventory. No CLI-owned physical sequence is registered.
- The xWalk Agent PiCar-X host suite passes with in-memory I2C and GPIO
  callbacks, and its Linux/RPI hardware test compiles without being executed.
- The xWalk SelfDrive host suite passes with in-memory timing, audio, I2C, and
  GPIO callbacks, and its Linux/RPI production library compiles successfully.
- The xWalk LineTracking host suite passes with in-memory timing, I2C, and GPIO
  callbacks, and its Linux/RPI production library compiles successfully.
- The PiCar-X CLI host suite passes with injected console, delay, audio,
  I2C, and GPIO backends. Its Raspberry Pi main executable compiles, while
  physical execution remains opt-in.
- The aggregate host suite includes CLI parsing and dispatch for PiCar-X,
  foreground line tracking, and preset self-drive actions. External-service
  commands remain unavailable until their safe process-level backends are composed.
- The I2C Linux backend and `xWalkI2cLinuxHardwareTest` compile successfully.
- The GPIO core and Linux backend host suite passes through an injected device
  mirror, and the standalone stub simulation runs without opening hardware.
  The Linux GPIO backend and opt-in hardware test compile without execution.
- The xWalk-rpi5-iw Protobuf/XML contract validates, its generated gRPC C++ library
  compiles, and its host schema test passes in the aggregate suite.
- The SPI core and Linux backend host suite passes through an injected device
  mirror, and the standalone stub simulation runs without opening hardware.
  The Agent transaction service and CLI dispatch host tests pass with injected
  transfers; the Linux spidev backend and opt-in hardware test compile.
- The CLI `spi transfer <HEX>` path compiles in the complete Raspberry Pi
  executable without initializing the Robot HAT or other PiCar-X services.
- The shared ALSA backend host suite passes with injected operations and the
  standalone stub simulation runs without opening an audio device or changing
  mixer state. Its silent hardware test and hardware simulation compile without
  being executed.
- The section-aware Config and flat ConfigStore host suites pass, and their
  standalone simulation persists and reloads values only below its build tree.
  xWalkConfig has no physical-hardware backend or hardware test.
- The Utils callback and safe Linux software suites pass, and the standalone
  host-stub simulation runs without shell, mixer, descriptor, network, or user
  database side effects. Its hardware target compiles without execution.
- The PWM host suite and standalone in-memory simulation pass with persistent
  trace selection. The hardware target and `xWalkPwmHardwareTest` compile and
  are listed without execution.
- The Servo host suite and standalone in-memory simulation pass with persistent
  trace selection. Its hardware-test target compiles and is listed without
  execution.
- The ADC, GPIO, and Motor hardware-test targets compile successfully.
- The Motor host suite and standalone in-memory simulation pass with persistent
  trace selection. Its PWM, I2C, and GPIO hardware dependencies compile and are
  listed without moving physical motors.
- The ADC host suite and standalone in-memory simulation pass with persistent
  trace selection. Its hardware-test target compiles and is listed without
  execution.
- The I2C, PWM, Servo, ADC, GPIO, Motor, and combined Config host suites pass.
- The combined BoardControl, Device, and FirmwareInfo host suites pass with their dependencies.
- Their combined target and Linux ADC, I2C, and GPIO dependencies compile successfully.
- The Trace host suite passes, and its hardware-independent target compile test builds successfully.
- Trace output remains callback-defined; the port has no physical-hardware test or built-in console backend.
- The GPT host suites and their BoardControl, ADC, I2C, and GPIO dependency suites pass.
- The GPT microphone and playback targets compile and require explicit devices before physical access.
- The LanguageModel coordinator and Ollama provider host suites pass with an
  in-memory coordinator backend and fake HTTP transport. Its standalone
  simulation runs without provider, credential, process, or network access.
- The Ollama hardware-test target compiles and is listed without execution. It
  requires explicit endpoint, model, and prompt before network access.
- The VoiceAssistant host suite and standalone in-memory simulation pass with
  persistent trace selection; completed ALSA/Ollama composition remains device-free.
- The VoiceAssistant full-stack target compiles and requires explicit microphone,
  playback, model, and fixture input.
- The Utils host suite passes with injected platform, clock, and standard-error backends.
- The Utils target compile test builds without executing platform or operating-system services.
- The Robot host suite and its Servo, PWM, I2C, and Config dependency suites pass.
- The combined Config target-oriented production library compiles successfully.
- The Robot target and its Servo, PWM, and I2C hardware dependencies compile successfully.
- The Ultrasonic host suite and standalone in-memory simulation pass with
  persistent trace selection. Its target and Linux GPIO hardware dependency
  compile and are listed without executing physical-device tests.
- The Camera host suite and standalone in-memory simulation pass with persistent
  trace selection. Its Linux CSI/USB backend and opt-in hardware test compile
  and are listed without capturing an image.
- The LineTracker host suite and standalone in-memory simulation pass with
  persistent trace selection. Its target, ADC, and Linux I2C dependencies
  compile and are listed without physical sensor execution.
- The ADXL345 host suite and its I2C dependency suite pass.
- Its standalone in-memory simulation passes with persistent trace selection.
  The ADXL345 target and Linux I2C hardware dependency compile and are listed
  without execution.
- The Buzzer host suite and standalone in-memory simulation pass with persistent
  trace selection. Its PWM, I2C, and GPIO dependency suites pass.
- The Buzzer target and its PWM, I2C, and GPIO hardware dependencies compile
  and are listed without producing physical sound.
- The combined LED host suites and standalone in-memory simulation pass with
  persistent trace selection. Its GPIO, PWM, and I2C dependency suites pass.
- The combined LED target and its Linux GPIO and I2C hardware dependencies
  compile and are listed without changing physical light outputs.
- The UserButton host suite and standalone in-memory simulation pass with
  persistent trace selection. Its target and Linux GPIO hardware dependency
  compile and are listed without executing physical button monitoring.
- The bounded D0 button-event sequence passes with an in-memory host backend,
  and its Linux adapter and central hardware selector compile successfully;
  physical button events have not been exercised.
- The three-servo initialization-angle sequence passes with in-memory GPIO and
  I2C backends. Its MCU-reset and PWM hardware composition compiles; physical
  servo movement has not been exercised.
- The bounded Robot HAT v5 four-motor sequence passes with an in-memory I2C
  backend and guaranteed cleanup attempts. Its physical dual-PWM composition
  compiles; motor movement has not been exercised.
- The bounded Robot HAT two-motor sequence passes with in-memory I2C and GPIO
  backends and guaranteed cleanup attempts. Its P13/D4 and P12/D5 physical
  composition compiles; motor movement has not been exercised.
- The bounded Robot HAT servo sequence passes with in-memory GPIO and I2C
  backends across all 16 PWM servos and five ADC channels. Its physical
  composition compiles; MCU reset and servo movement have not been exercised.
- The bounded 12-channel servo sweep passes with an in-memory I2C backend and
  verifies progressive channel order at negative and positive 20 degrees. Its
  physical composition compiles; servo movement has not been exercised.
- The Piper stream-comparison sequence passes with injected provider, clock,
  and output callbacks. No physical case is registered because the workspace
  has no C++ Piper provider supporting both streamed and buffered modes.
- The 17-measure Robot HAT tone sequence passes through the real Music
  abstraction with an in-memory audio backend. Its ALSA hardware composition
  compiles and remains disabled by default; physical playback has not been exercised.
- The ported Robot HAT LED example passes with injected LED, timing, and output
  callbacks. Its GPIO26 Linux composition and central example selector compile;
  the physical 19-second LED flow remains disabled by default and has not run.
- The ported DeepSeek chat example passes with an injected language model and
  console. Its authenticated HTTPS adapter and central example selector compile;
  the disabled live case has not sent prompts or consumed provider service.
- The ported Doubao image-chat example passes with injected camera, language
  model, and console dependencies. Its camera and authenticated HTTPS adapters
  compile; the disabled live case has not captured or uploaded an image.
- The ported Doubao text-chat example passes with an injected language model
  and console. Its authenticated HTTPS adapter compiles; the disabled live case
  has not sent a prompt or consumed provider service.
- The ported Gemini chat example passes with an injected language model and
  console. Its authenticated OpenAI-compatible HTTPS adapter compiles; the
  disabled live case has not sent a prompt or consumed provider service.
- The ported Grok chat example passes with an injected language model and
  console. Its authenticated OpenAI-compatible HTTPS adapter compiles; the
  disabled live case has not sent a prompt or consumed provider service.
- The ported Ollama text-chat example passes with an injected language model
  and console. Its native Ollama adapter compiles with the upstream localhost
  endpoint and `deepseek-r1:1.5b` model; the disabled live case has not sent a
  prompt.
- The ported Ollama image-chat example passes with injected camera, language
  model, and console dependencies. Its 1280-by-720 camera and native Ollama
  adapters compile; the disabled live case has not captured or uploaded an image.
- The ported OpenAI image-chat example passes with injected camera, language
  model, and console dependencies. Its 640-by-480 camera and authenticated
  OpenAI-compatible HTTPS adapters compile; the disabled live case has not
  captured or uploaded an image.
- The ported OpenAI text-chat example passes with an injected language model
  and console. Its authenticated OpenAI-compatible HTTPS adapter compiles; the
  disabled live case has not sent a prompt or consumed provider service.
- The ported generic-provider chat template passes with an injected language
  model and console. Its runtime-selected OpenAI-compatible HTTPS adapter
  compiles; the disabled live case has not sent a prompt or consumed provider
  service.
- The upstream GPT-car Agent profile passes JSON response, keyboard-input,
  no-image, action-dispatch, and Controller sequence tests with simulated HAL.
  Its OpenAI, speech, camera, LED, Music, and SelfDrive Raspberry Pi graph is
  registered but has not been physically executed.
- The ported Qwen chat example passes with an injected language model and
  console. Its configurable DashScope OpenAI-compatible HTTPS adapter compiles;
  the disabled live case has not sent a prompt or consumed provider service.
- The ported pin-input example passes with injected input, timing, and reporting
  operations. Its bounded D3/GPIO22 pull-up adapter compiles; the disabled live
  case has not opened or sampled a physical GPIO line.
- The ported servo example passes with injected angle, timing, and reporting
  operations. Its bounded PWM-channel-one adapter compiles; the disabled live
  case has not opened I2C or moved a physical servo.
- The Music host suite and standalone silent simulation pass with persistent
  trace selection, and its hardware-independent target compiles successfully.
- Music callbacks are connected to shared ALSA and its opt-in hardware target compiles.
- Native Music MP3 decoding is covered by a device-free libsndfile host test.
- The xWalkBoot host stub passes one-shot lifecycle tests, and its RPi composition target compiles.
- The Speaker host suite and standalone silent simulation pass with persistent
  trace selection, and its hardware-independent target compiles successfully.
- Speaker decoding and shared-ALSA playback are covered by host and opt-in hardware targets.
- The host and hardware compilation paths are warning-clean under the configured
  GCC warning options.
- Host coverage passes enforced minimums of 79 percent for lines and 40 percent
  for branches.
- Hardware tests have not been executed as part of this verification.
