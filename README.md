# xWalk Raspberry Pi 5 hardware integration

This repository owns the hardware CMake aggregate and pins five independently reviewed components:
`xWalkDriver`, `xWalkAudioResources`, `xWalkController`, `xWalkHal`, and `xWalkLibrary`.

`xWalkPiCarAI` consumes this repository as its `xWalk-rpi5-hw` submodule. Existing source and build paths remain
unchanged. Shared interfaces, tracing, tooling, Node, and desktop sources remain owned by the product integration.

## Review and uplift

1. Submit a component change through Gerrit after its module CI passes.
2. Automation creates a hardware integration review containing only that component's exact submitted gitlink.
3. Hardware integration CI checks Driver, Controller, HAL, Library, and packaged audio resources.
4. After hardware review and submission, automation mirrors the submitted revision to GitHub and creates an
   `xWalkPiCarAI` review updating only the `xWalk-rpi5-hw` gitlink.
5. The product review runs complete product CI before submission and GitHub replication.

CI never imports an arbitrary GitHub tip or publishes unreviewed component changes. Duplicate merge events are
idempotent and use separate per-integration state. Use Gerrit for all uploads; GitHub is the submitted mirror.

```bash
git push origin HEAD:refs/for/master
```

## Build and verification

For development, initialize the full product recursively, then follow [BUILDING.md](BUILDING.md). The aggregate
expects its shared dependencies beside `xWalk-rpi5-hw` in the product workspace. It does not vendor those modules.

The repository-owned CI entry point creates a temporary product workspace from the submitted revisions recorded
in `ci/context.json`, overlays this exact hardware commit, initializes its exact component gitlinks, and runs the
same hardware-only quality graph used by Gerrit. Module stages run sequentially by default, matching the managed
Gerrit runner and avoiding CPU contention during timing-sensitive sensor simulations:

```bash
python3 -B ci/run-host-ci.py
```

By default, it reads the private GitHub mirrors using configured Git credentials. A managed runner uses the
existing `GERRIT_SERVER_HOST`, `GERRIT_SSH_PORT`, `GERRIT_SUBMODULE_USERNAME`, `GERRIT_SUBMODULE_SSH_KEY_FILE`, and
`GERRIT_SSH_KNOWN_HOSTS_FILE` settings for authenticated, host-key-verified Gerrit checkout. Results remain under
`ci-artifacts/`. No hardware test or robot operation is run automatically.

## Dedicated GitHub runner

Register an official Linux x64 GitHub Actions runner for this repository with the `xwalk-ci` label, installed at
`$HOME/apps/github-actions-runner-xwalk-hw`. Use the same host dependencies as the product CI runner. Registration
tokens and the resulting `.credentials*` files stay private on the runner and must never be committed.

Copy [runner.env.example](ci/runner/runner.env.example) to the runner's `.env`, replacing the endpoint and paths
with its existing Gerrit read credentials and pinned host keys. Keep the private key mode `0600`. The runner only
reads submitted dependencies; Gerrit handles all publication. Back up existing runner configuration privately
before changing it.

Install [the user service](ci/runner/xwalk-hardware-github-actions-runner.service) under
`$HOME/.config/systemd/user/`, then start it:

```bash
systemctl --user daemon-reload
systemctl --user enable --now xwalk-hardware-github-actions-runner.service
```

Retain the runner's `.env`, `.runner`, `.credentials*`, `.path` and any existing local overrides when updating the
runner distribution. The service template and environment example reproduce the deployment without storing secrets.

## Root hardware sequence tests

The root `xWalkTest/` suite shares one production Boot fixture across Robot HAT v4 and v5 profiles. See
[full hardware module regression](BUILDING.md#full-hardware-module-regression-from-the-root) for the sequence
coverage and the single command that builds and tests HAL, Driver, Controller, Library, and audio resources.
