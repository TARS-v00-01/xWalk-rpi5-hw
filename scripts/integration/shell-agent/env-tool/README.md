# Environment assets

This directory groups version-controlled environment inputs consumed by xWalk
build, CI, licensing, and Raspberry Pi deployment tools. Most files are
configuration or installation assets rather than executable entry points.

## Directory contents

| Path | Purpose | Primary consumer |
|---|---|---|
| `quality/.clang-tidy` | Project Clang-Tidy policy. | CMake static-analysis presets. |
| `quality/.cppcheck-suppressions` | Reviewed Cppcheck suppressions. | The `cppcheck` build target. |
| `quality/gcovr.cfg` | Coverage scope, reports, and enforced floors. | `run-host-coverage.sh`. |
| `license/xWalkLicense.cfg` | Non-secret encrypted-model template. | `xWalkEnv.sh` and packaging. |
| `license/xWalkEnv.sh` | Licence and provider environment loader. | Shell and deployment tests. |
| `dtoverlays/` | Reviewed Robot HAT Device Tree overlay blobs. | Raspberry Pi installation. |
| `playbooks/zuul/` | Repository-controlled Host Quality playbooks. | External Zuul executor. |

Do not place private keys, API tokens, passwords, decrypted model keys, cookies,
authorization headers, or machine-specific `.env` files in this directory.

## Load the licence environment

The loader must be sourced so it can update the current shell:

```bash
source scripts/integration/shell-agent/env-tool/license/xWalkEnv.sh
```

It authenticates the encrypted xWalk licence, validates model names, and reads
provider credentials from the current user's protected `$HOME/.netrc`. The
encrypted key and netrc file must have mode `0600`. The loader removes its
temporary decrypted data and never prints credential values.

See the [licence-key workflow](../../../devloper-note/xwalk-rpi5-note/Doc/note/License%20Key%20Workflow.md) and the
environment-loader guide linked from the
[documentation index](../../../devloper-note/xwalk-rpi5-note/index.md) before changing the template or loader.

## Quality configuration

Run the repository wrappers rather than invoking configuration files directly:

```bash
scripts/integration/shell-agent/quality-tool/run-host-coverage.sh run gcc
scripts/integration/shell-agent/quality-tool/run-host-quality.sh
```

Changes to `.clang-tidy`, Cppcheck suppressions, or coverage exclusions and
floors require a clear explanation. Do not weaken a quality policy merely to
make a failing change pass.

## Zuul playbooks

The root `.zuul.yaml` references the playbooks in `playbooks/zuul`. Keep
`.zuul.yaml` at the repository root so Zuul can discover it. The external Zuul
administrator supplies the executor, node image, Gerrit connection, secrets,
and log storage; repository playbooks do not install Zuul.

Validate the repository-controlled configuration:

```bash
python3 scripts/integration/py-agent/dev-tool/xWalkZuulValidator .zuul.yaml
```

```bash
ANSIBLE_HOME="$PWD/build-host/ansible" ANSIBLE_LOCAL_TEMP="$PWD/build-host/ansible/local" ansible-playbook --syntax-check scripts/integration/shell-agent/env-tool/playbooks/zuul/run-host-quality-job.yaml
```

```bash
ANSIBLE_HOME="$PWD/build-host/ansible" ANSIBLE_LOCAL_TEMP="$PWD/build-host/ansible/local" ansible-playbook --syntax-check scripts/integration/shell-agent/env-tool/playbooks/zuul/collect-host-quality-artifacts.yaml
```

## Device Tree overlays

The `.dtbo` files are reviewed binary boot assets. Do not regenerate, replace,
or install them as part of ordinary host CI. Validate their origin and target
HAT revision before a separately authorized Raspberry Pi deployment.

## Host-safe verification

Validate the licence loader through its isolated integration test:

```bash
bash scripts/integration/shell-agent/deploy-tool/test/environment-loader-test.sh
```

Validate all shell sources without executing their behavior:

```bash
bash -n scripts/integration/shell-agent/env-tool/license/xWalkEnv.sh
scripts/integration/shell-agent/quality-tool/run-host-shellcheck.sh
```
