# Jira tool launcher

This directory provides the shell entry point for the host-only xWalk Jira
history importer. The launcher executes the checked-out Python package from
`scripts/integration/py-agent/board-tool/py-src`; it does not install a package or create
a Python environment inside the repository.

## Prerequisites

Run commands from the `MyPiCarX` repository root. Python 3 is required. Install
runtime dependencies in an environment outside the repository when they are
not already available:

```bash
python3 -m venv "$HOME/.local/share/xwalk/board-venv"
source "$HOME/.local/share/xwalk/board-venv/bin/activate"
python -m pip install --requirement scripts/integration/py-agent/board-tool/requirements.txt
```

Keep GitHub and Jira credentials in a protected `$HOME/.netrc` file with mode
`0600`. Never put tokens in this launcher, command arguments, tracked files, or
generated reports.

## Inspect the command

The launcher adds the checked-out `py-src` directory to `PYTHONPATH` and
forwards every argument to `python3 -m xWalkJiraImport`:

```bash
scripts/integration/shell-agent/jira-tool/xWalkJiraImport.sh --help
```

Non-secret service selection can be supplied through the documented
environment variables:

```bash
export JIRA_URL="https://student-team-xwalk-rpi5.atlassian.net"
export JIRA_PROJECT_KEY="TARS"
export GITHUB_REPOSITORY="jochuuu/xWalkPiCarAI"
export GITHUB_BRANCH="master"
```

## Preview an import

Dry-run is the default and does not create or update Jira work items. Keep the
explicit option in review and automation logs:

```bash
scripts/integration/shell-agent/jira-tool/xWalkJiraImport.sh --dry-run --max-commits 20 --output-report build/jira-import-preview
```

Review both generated JSON and CSV reports before considering apply mode. The
reports must not contain credentials or authorization headers.

## Apply an import

`--apply` is an external Jira mutation. Use it only after the dry-run report,
duplicate detection, account permissions, project key, board filter, date
range, and credential source have been verified:

```bash
scripts/integration/shell-agent/jira-tool/xWalkJiraImport.sh --apply --since 2026-01-01 --until 2026-12-31 --output-report build/jira-import-applied
```

The importer never changes Git history, branches, tags, files, or remotes. See
the [Python board-tool guide](../../py-agent/board-tool/README.md) for complete
options, credential handling, estimation rules, tests, limitations, and Jira
permission requirements.

## Verification

Run the importer package tests without contacting Jira:

```bash
python3 -m unittest discover -s scripts/integration/py-agent/board-tool/test -p 'test_*.py'
```

Check the launcher before review:

```bash
bash -n scripts/integration/shell-agent/jira-tool/xWalkJiraImport.sh
shellcheck scripts/integration/shell-agent/jira-tool/xWalkJiraImport.sh
```
