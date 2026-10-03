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
same hardware-only quality graph used by Gerrit:

```bash
python3 -B ci/run-host-ci.py
```

By default, it reads the private GitHub mirrors using configured Git credentials. A managed runner uses the
existing `GERRIT_SERVER_HOST`, `GERRIT_SSH_PORT`, `GERRIT_SUBMODULE_USERNAME`, `GERRIT_SUBMODULE_SSH_KEY_FILE`, and
`GERRIT_SSH_KNOWN_HOSTS_FILE` settings for authenticated, host-key-verified Gerrit checkout. Results remain under
`ci-artifacts/`. No hardware test or robot operation is run automatically.
