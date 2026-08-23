# xWalk Shell Agent

The scripts and deployment assets in this directory provide explicit repository maintenance, host
verification, Raspberry Pi provisioning, and licence-environment loading.
Run commands from the `MyPiCarX` repository root unless a section says to
source the script.

Hardware operations are opt-in. Do not apply Raspberry Pi or Robot HAT
changes until the exact board, HAT revision, wiring, and safe physical state
have been confirmed.

## Prerequisites

Use Bash and install the dependencies required by the selected operation.
CMake and CTest are needed for host builds. The complete sanitizer, coverage,
Valgrind, static-analysis, and ShellCheck prerequisites and commands are in the
[host quality guide](../cpp-tool/quality/README.md).

The licence environment loader additionally requires Python 3 and PyNaCl.
The recommended Python environment is documented in the
[Python agent support guide](../py-agent/README.md).

## Module inventory

| Module | Purpose | Safety boundary |
|---|---|---|
| [`jira-tool/`](jira-tool/README.md) | Runs the Jira history importer from source | Dry-run by default |
| [`gerrit-tool/`](gerrit-tool/README.md) | Prepares Gerrit reviews, dispatches Host Quality jobs, and validates submodule metadata | CI and host-only |
| [`deploy-tool/`](deploy-tool/README.md) | Provides provisioning, packaging assets, and deployment tests | `--apply` is privileged |
| [`env-tool/`](env-tool/README.md) | Groups quality, licence, boot-overlay, and Zuul configuration | Mixed; see its guide |
| `env-tool/dtoverlays/` | Stores Raspberry Pi Device Tree blobs | Target boot assets |
| `env-tool/license/` | Stores the model template and environment loader | Loader must be sourced |
| `env-tool/playbooks/` | Stores repository-controlled Zuul Ansible playbooks | Host-safe CI configuration |
| `env-tool/quality/` | Stores Clang-Tidy, Cppcheck, and gcovr settings | Host-safe configuration |
| [`repo-tool/`](repo-tool/README.md) | Finds and removes generated CMake and Python output | Use `--dry-run` first |
| [`quality-tool/`](quality-tool/README.md) | Runs coverage, sanitizers, static analysis, ShellCheck, and Valgrind | Host-only |

## Host maintenance

Preview cleanup without changing the workspace:

```sh
scripts/integration/shell-agent/repo-tool/clean-build.sh --dry-run
```

Interactive cleanup asks for confirmation. Automation must opt in explicitly:

```sh
scripts/integration/shell-agent/repo-tool/clean-build.sh --yes
```

Run the root host coverage preset and generate the configured report:

```sh
scripts/integration/shell-agent/quality-tool/run-host-coverage.sh run
```

Each script that provides option help can be queried directly, for example:

```sh
scripts/integration/shell-agent/repo-tool/clean-build.sh --help
scripts/integration/shell-agent/quality-tool/run-host-coverage.sh --help
```

Preview Jira board history without installing the package into the repository:

```sh
scripts/integration/shell-agent/jira-tool/xWalkJiraImport.sh --dry-run --max-commits 20 --output-report build/jira-import-preview
```

The launcher uses Python 3 and the checked-out `scripts/integration/py-agent/board-tool/py-src` package. Runtime dependencies may be
installed in an active environment located outside the repository.

## Raspberry Pi provisioning

`setup-rpi.sh` defaults to Robot HAT v4, runtime user `xwalk`,
`/dev/gpiochip4`, `/dev/i2c-1`, `/dev/spidev0.0`, a CSI camera, and dry-run
mode. Review that plan before using `--check` or privileged `--apply` mode:

```sh
scripts/integration/shell-agent/deploy-tool/setup-rpi.sh --dry-run
```

Explicit options preserve Robot HAT v5, alternate device nodes, USB cameras,
and other existing runtime users.

Use `provision-hardware.sh` only on a verified target. It validates the
selected profile and detected GPIO identity, then updates the specified
writable controller configuration:

```sh
scripts/integration/shell-agent/deploy-tool/provision-hardware.sh --profile robot_hat_v5 --config /var/lib/xwalk/picar-x.conf --gpio-device /dev/gpiochip0 --i2c-device /dev/i2c-1 --spi-device /dev/spidev0.0
```

Show the complete supported options before provisioning:

```sh
scripts/integration/shell-agent/deploy-tool/setup-rpi.sh --help
scripts/integration/shell-agent/deploy-tool/provision-hardware.sh --help
```

## GitHub integration metadata

GitHub Actions uses `validate-integration-metadata.sh` for metadata-only checks
and `checkout-gerrit-submodules.sh` when a read-only Gerrit identity is
available. The checkout helper validates metadata before it configures the
temporary SSH command and initializes the exact recorded submodule commits.

Neither helper pushes refs or configures GitHub remotes in component
submodules. Metadata-only validation can be exercised without credentials:

```sh
XWALK_GITHUB_METADATA_ONLY=true scripts/integration/shell-agent/gerrit-tool/checkout-gerrit-submodules.sh
```

## Licence environment loader

`xWalkEnv.sh` must be sourced so that it can export values into the current
shell:

```sh
source scripts/integration/shell-agent/env-tool/license/xWalkEnv.sh
```

The loader authenticates `xWalk-rpi5-hw/xWalkLibrary/X_WALK_LICENSE.KEY` with
`scripts/integration/py-agent/dev-tool/xWalkLicenseTool`. It privately requests the decryption key,
validates the decrypted model names against
`scripts/integration/shell-agent/env-tool/license/xWalkLicense.cfg`, loads API credentials from the
developer's mode-`0600` `~/.netrc`, and exports the combined values.
Missing hosts and empty passwords are skipped so unused providers do not need
keys. It does not export `X_WALK_LICENSE_SERIAL` or print API-key values.

Decryption uses a temporary mode-`0600` JSON file, which the loader removes
before returning. The encrypted licence and netrc files must also have mode
`0600`. Executing the script instead of sourcing it fails because a child
process cannot update its parent shell environment.

See the [licence-key workflow](../../devloper-note/xwalk-rpi5-note/Doc/note/License%20Key%20Workflow.md)
for encryption, decryption, virtual-environment setup, and key-storage rules.
The dedicated
[environment loader guide](../../devloper-note/xwalk-rpi5-note/Doc/note/xWalk%20Environment%20Loader%20Guide.md)
documents the validation order, failure behavior, and shell-environment lifetime.

## Verification

Check every shell script for Bash syntax errors without executing its work:

```sh
find scripts/integration/shell-agent -type f -name '*.sh' -print0 | xargs -0 bash -n
```

Run the host-only licence environment integration test:

```sh
bash scripts/integration/shell-agent/deploy-tool/test/environment-loader-test.sh
```

Additional script-specific detail is available from the
[xWalk-rpi5-tool overview](../README.md) and the linked guides in its **Detailed
guides** section.
