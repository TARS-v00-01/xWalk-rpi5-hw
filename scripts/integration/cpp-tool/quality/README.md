# Host quality instrumentation

These checks execute only host-safe tests. They do not validate Raspberry Pi,
Robot HAT, camera, sensor, servo, or motor hardware.

## Ubuntu 24.04 prerequisites

Repository scripts report missing tools but never install them. Install the
reviewed tool set manually on an Ubuntu 24.04 host or VM:

```bash
sudo apt update
sudo apt install -y ansible-core clang clang-format clang-tools llvm gcovr lcov python3-yaml valgrind shellcheck
```

Inspect paths, versions, and availability without changing the machine:

```bash
scripts/integration/shell-agent/quality-tool/check-host-quality-dependencies.sh
```

Every wrapper uses these result terms:

- `PASSED`: the tool executed fully and found no disallowed issue.
- `FAILED`: the tool executed and found a defect, build failure, or test failure.
- `SKIPPED_MISSING_TOOL`: a required executable was not installed.
- `BLOCKED_BY_ENVIRONMENT`: the executable exists but cannot initialize in the runtime.

Exit status is zero for `PASSED`, one for `FAILED`, two for
`SKIPPED_MISSING_TOOL`, and three for `BLOCKED_BY_ENVIRONMENT`.

## Sanitizers

ASan/UBSan, LSan verification, and TSan have separate build directories. TSan
must never be combined with ASan, LSan, UBSan, or coverage because their runtime
instrumentation and shadow-memory layouts are incompatible. Successful
compilation alone is not a sanitizer pass; the instrumented executable and the
appropriate negative verification probe must run.

```bash
scripts/integration/shell-agent/quality-tool/run-host-sanitizer.sh asan
scripts/integration/shell-agent/quality-tool/run-host-sanitizer.sh lsan
scripts/integration/shell-agent/quality-tool/run-host-sanitizer.sh tsan
```

The ASan/UBSan mode deliberately uses `detect_leaks=0`; it is the separate mode
usable for ordinary sanitizer tests and restricted fuzz environments. The LSan
mode uses `detect_leaks=1`, first verifies that an intentional leak is rejected,
then runs the complete project suite. LeakSanitizer cannot operate while the
process is traced by GDB, `strace`, ptrace-based wrappers, or some restricted
containers. Such startup failures are `BLOCKED_BY_ENVIRONMENT`, never passed.

TSan first records `/proc/sys/kernel/randomize_va_space`, verifies an intentional
race, then runs focused streaming, observability, shutdown, simulator, and
lifecycle tests with `history_size=7`. Shadow-memory mapping failures are also
`BLOCKED_BY_ENVIRONMENT`. The scripts never change ASLR or sysctl settings.

The intentionally defective probes under `probes/` are verification fixtures;
they are not registered in the normal passing CTest suite.

## Coverage

GCC and Clang coverage use clean, independent build trees:

```bash
scripts/integration/shell-agent/quality-tool/run-host-coverage.sh run gcc
scripts/integration/shell-agent/quality-tool/run-host-coverage.sh run clang
```

The measured GCC baseline on 2026-08-11 is 80.7 percent lines, 85.2 percent
functions, and 66.6 percent branches. Regression floors are 75, 85, and 66
percent respectively in `scripts/integration/shell-agent/env-tool/quality/gcovr.cfg`. The report includes
all project production sources while excluding generated code, tests,
third-party sources, and non-executable assets. Important exercised paths
include configuration rejection, watchdog and emergency stops, camera loss and
EOF, streaming shutdown and disconnects, simulator I2C faults, and bounded
observability. Hardware-only backend failure branches and several host
composition branches remain uncovered. Branch coverage is not yet 75 percent.

Open the GCC detailed report at `build-host/coverage/coverage.html`. GCC also
produces Cobertura XML and JSON. Clang produces a terminal summary, HTML under
`build-host/coverage-clang/html/index.html`, LLVM profile data, and JSON export.

## Valgrind and static analysis

Run focused non-sanitized Debug tests with CTest MemCheck:

```bash
scripts/integration/shell-agent/quality-tool/run-host-valgrind.sh
```

The wrapper checks leaks, all leak kinds, origins, invalid memory access,
uninitialized values, and open descriptors. It excludes long soak and fuzz
workloads. CTest and CI runners may pass a variable number of report and command
descriptors to each child. The wrapper accepts descriptors that Valgrind names
and marks as inherited from the parent, while rejecting every non-standard
descriptor opened by the tested process and left open at exit. CTest labels all
`still reachable` records as potential leaks; the wrapper separately rejects
nonzero definite, indirect, or possible loss and nonzero Valgrind error
summaries. No suppression file is provided because no demonstrated
external-library false positive has been accepted.

Run the Clang Static Analyzer in its clean build directory:

```bash
scripts/integration/shell-agent/quality-tool/run-clang-static-analyzer.sh
```

Human-readable HTML and machine-readable plist reports are retained below
`build-host/clang-analyzer/reports`. `scan-build --status-bugs` makes actionable
findings fail the command.

## ShellCheck and combined verification

```bash
scripts/integration/shell-agent/quality-tool/run-host-shellcheck.sh
scripts/integration/shell-agent/quality-tool/run-host-quality.sh
```

ShellCheck uses null-delimited discovery, so paths containing spaces are safe.
It excludes only generated build trees, generated source, third-party code, and
reviewed architecture-specific dependency bundles. The combined command runs
all modes and preserves the strongest non-passing result.

CI uses the same wrappers. LSan and TSan jobs require a native Linux runner
whose security policy permits sanitizer initialization; a restricted runner
must report the environment block instead of converting it into success.

GitHub Actions and the repository-owned Gerrit event worker use the shared job
dispatcher so their substantive Host Quality commands remain aligned:

```bash
scripts/integration/shell-agent/gerrit-tool/run-host-ci-job.sh build-and-test gcc Debug
```

The GitHub workflow remains under `.github/workflows`. The current Gerrit
service uses `xWalkGerritCi.py`, `xWalkGerritQuality.py`, and the server-rendered
`xWalkGerritLogServer.py` dashboard; Gerrit does not execute the GitHub
workflow. See the Gerrit CI configuration guide for event triggers, module
state, log retention, service operation, and `Verified` permissions.

The ShellCheck job also runs the repository-owned `xWalkZuulValidator`, which
checks the retained optional Zuul definitions, execution dependencies, cycles,
playbook paths, and registration in both project pipelines. It then runs
`ansible-playbook --syntax-check` for every retained playbook. These checks do
not activate Zuul or make it the current Gerrit CI backend.
