# xWalk Python Agent Tools

This directory groups Python-based development, board-integration, and Gerrit
administration tools. Run commands from the MyPiCarX repository root so the
documented relative paths remain valid.

## Create a Python environment

On Debian-family systems, install Python's virtual-environment support when it
is not already available:

```sh
sudo apt-get install python3-venv
```

Create the xWalk tools environment outside the repository:

```sh
python3 -m venv "$HOME/.local/share/xwalk/tools-venv"
```

Activate it and install the licence-tool dependency:

```sh
source "$HOME/.local/share/xwalk/tools-venv/bin/activate"
python -m pip install --upgrade pip
python -m pip install PyNaCl
```

Do not create an environment under `xWalk-rpi5-tool`. Do not place filled model configurations, netrc files, decrypted
data, decryption keys, or other secrets inside the environment.

Leave the environment when finished:

```sh
deactivate
```

## Licence tool

`xWalkLicenseTool` encrypts non-secret model selections into the fixed
`xWalk-rpi5-hw/xWalkLibrary/X_WALK_LICENSE.KEY` path. Copy the empty model template outside
the repository, restrict the copy, and fill only model values in that external file:

```sh
install -m 0600 scripts/integration/shell-agent/env-tool/license/xWalkLicense.cfg /secure/location/xWalkLicense.cfg
```

Encrypt the protected configuration:

```sh
scripts/integration/py-agent/dev-tool/xWalkLicenseTool encrypt --config /secure/location/xWalkLicense.cfg
```

Alternatively, provide repeated values manually. These values may be visible
in shell history or process listings, so a protected configuration is preferred:

```sh
scripts/integration/py-agent/dev-tool/xWalkLicenseTool encrypt --env OPENAI_MODEL='gpt-model' --env GEMINI_MODEL='gemini-model'
```

Replace the quoted example text with the real values. Do not type angle-bracket
placeholders because the shell interprets `<` and `>` as redirection operators.

Decrypt to an explicit temporary path:

```sh
scripts/integration/py-agent/dev-tool/xWalkLicenseTool decrypt --output /tmp/xWalkLicense.decrypted.json
```

API credentials are not accepted through JSON or `--env`. Each developer stores fixed-provider credentials under
their actual API hostnames in a mode-`0600` `~/.netrc`; `xWalkEnv.sh` loads that file automatically and combines
supported API keys with the authenticated model settings. See the detailed guide for the complete host mapping.

The tool requests the decryption key interactively. It never accepts the key as
a command-line option. Delete temporary plaintext after use. See the full
[licence-key workflow](../../devloper-note/xwalk-rpi5-note/Doc/note/License%20Key%20Workflow.md)
for commit policy, deployment, and security limitations. The dedicated
[licence tool guide](../../devloper-note/xwalk-rpi5-note/Doc/note/xWalk%20Licence%20Tool%20Guide.md)
documents serial-number output, invocation forms, and exit behavior.

Run the host-only licence tests:

```sh
python scripts/integration/py-agent/dev-tool/test/test_xWalkLicenseTool.py
```

## Developer tools

Install the Jira importer package into the active environment:

```sh
python -m pip install ./scripts/integration/py-agent/board-tool
```

Store local GitHub and Jira API credentials in a mode-`0600` `~/.netrc`; the importer loads this per-user path
automatically through `Path.home()`. Never place that file in the repository. The GitHub token is optional for the
public repository, while apply mode requires the Jira entry.

Preview historical GitHub commits as completed Jira work items with the dry-run-first
[Jira history importer](board-tool/README.md):

```sh
xWalkJiraImport --dry-run --max-commits 20 --output-report build/jira-import-preview
```

Check project dependencies without changing the system:

```sh
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarDependencyInstaller --check
```

Inspect generator options before regenerating checked-in xWalk-rpi5-iw files:

```sh
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarIwGenerator --help
```
