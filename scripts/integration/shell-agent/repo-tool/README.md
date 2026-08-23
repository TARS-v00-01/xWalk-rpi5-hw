# Repository maintenance tools

This directory contains guarded maintenance commands for the complete
`MyPiCarX` workspace. Run commands from the repository root and preview every
destructive operation before applying it.

## Clean generated output

`clean-build.sh` discovers generated CMake build trees, in-source CMake output,
Python caches, test caches, coverage files, package metadata, and Python
distribution output. It verifies the xWalk workspace root before acting and
uses CMake removal for build output.

List every target without removing anything:

```bash
scripts/integration/shell-agent/repo-tool/clean-build.sh --dry-run
```

Interactive cleanup prints the same target list and requires confirmation:

```bash
scripts/integration/shell-agent/repo-tool/clean-build.sh
```

Non-interactive automation must opt in explicitly:

```bash
scripts/integration/shell-agent/repo-tool/clean-build.sh --yes
```

Do not use `--yes` until the dry-run output has been reviewed. The script is
intended only for generated CMake and Python output; it must not remove source,
Git metadata, credentials, submodules, downloaded dependency bundles, or user
documents.

## Verification

Inspect the supported interface:

```bash
scripts/integration/shell-agent/repo-tool/clean-build.sh --help
```

Check syntax and ShellCheck findings without running cleanup:

```bash
bash -n scripts/integration/shell-agent/repo-tool/clean-build.sh
shellcheck scripts/integration/shell-agent/repo-tool/clean-build.sh
```

After an approved cleanup, reconfigure from the relocated product source:

```bash
cmake --fresh -S xWalk-rpi5-hw -B build-host/xwalk-rpi5 -G Ninja -DCMAKE_BUILD_TYPE=Debug -DXWALK_ENABLE_STRICT_WARNINGS=ON
```

```bash
cmake --build build-host/xwalk-rpi5 --parallel
```

```bash
ctest --test-dir build-host/xwalk-rpi5 --output-on-failure --no-tests=error
```
