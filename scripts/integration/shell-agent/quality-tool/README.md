# Host Quality tools

This directory contains the shared host-safe quality wrappers used locally, by
GitHub Actions, and by Gerrit/Zuul. Run commands from the `MyPiCarX` repository
root. The wrappers configure the product from `xWalk-rpi5-hw` and keep generated
output below `build-host`.

These checks never authorize Raspberry Pi, Robot HAT, motor, servo, GPIO,
camera commissioning, or other physical hardware operations.

## Check prerequisites

Inspect tool availability and versions without installing or changing the
host:

```bash
scripts/integration/shell-agent/quality-tool/check-host-quality-dependencies.sh
```

The command reports missing tools and prints the reviewed Ubuntu 24.04 package
installation command. Package installation remains an explicit administrator
action.

GitHub Actions jobs install their dependencies through
`install-github-host-packages.sh`. The helper replaces the Azure-hosted Ubuntu
mirror with the official HTTPS Ubuntu archive before updating package indexes.
It refuses to run outside GitHub Actions so local package sources cannot be
changed accidentally.

## Run individual checks

AddressSanitizer and UndefinedBehaviorSanitizer:

```bash
scripts/integration/shell-agent/quality-tool/run-host-sanitizer.sh asan
```

LeakSanitizer and ThreadSanitizer use separate GCC runtimes and build
directories. ThreadSanitizer disables address-space randomization for only its
probe and test processes so the runtime can reserve its shadow-memory layout:

```bash
scripts/integration/shell-agent/quality-tool/run-host-sanitizer.sh lsan
scripts/integration/shell-agent/quality-tool/run-host-sanitizer.sh tsan
```

Generate GCC or Clang coverage reports:

```bash
scripts/integration/shell-agent/quality-tool/run-host-coverage.sh run gcc
scripts/integration/shell-agent/quality-tool/run-host-coverage.sh run clang
```

Run memory, static-analysis, and shell checks:

```bash
scripts/integration/shell-agent/quality-tool/run-host-valgrind.sh
scripts/integration/shell-agent/quality-tool/run-clang-static-analyzer.sh
scripts/integration/shell-agent/quality-tool/run-host-shellcheck.sh
```

The Valgrind descriptor validator can be tested independently:

```bash
bash scripts/integration/shell-agent/quality-tool/test/validate-valgrind-descriptors-test.sh
```

## Run the combined suite

The combined wrapper runs dependency inspection, all three sanitizer modes,
GCC coverage, Valgrind, Clang Static Analyzer, and ShellCheck while preserving
the strongest non-passing exit status:

```bash
scripts/integration/shell-agent/quality-tool/run-host-quality.sh
```

This is resource intensive. CI normally schedules independent jobs through
`scripts/integration/shell-agent/gerrit-tool/run-host-ci-job.sh` instead.

## Result statuses

| Status | Exit status | Meaning |
|---|---:|---|
| `PASSED` | `0` | The check completed without a disallowed finding. |
| `FAILED` | `1` | A build, test, probe, threshold, or analysis check failed. |
| `SKIPPED_MISSING_TOOL` | `2` | A required executable is unavailable. |
| `BLOCKED_BY_ENVIRONMENT` | `3` | Runtime restrictions prevent a valid check. |

Do not convert missing tools, restricted sanitizer initialization, timeouts, or
analysis findings into success. LSan and TSan may require a native Linux runner
that permits their runtime initialization.

## Reports

| Check | Report location |
|---|---|
| GCC coverage | `build-host/coverage/coverage.html` |
| Clang coverage | `build-host/coverage-clang/html/index.html` |
| Clang Static Analyzer | `build-host/clang-analyzer/reports` |
| Valgrind | `build-host/valgrind/Testing/Temporary` and CTest memcheck output |
| Sanitizers | Their respective build directory and `ctest.log` when retained |

The complete policy, prerequisites, coverage floors, probe behavior, and CI
constraints are documented in the
[Host Quality instrumentation guide](../../cpp-tool/quality/README.md).
