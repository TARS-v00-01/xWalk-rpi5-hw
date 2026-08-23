# xWalk Developer Tools

This directory contains executable Python utilities used for xWalk development,
dependency preparation, interface generation, and licence configuration.

Run all commands from the MyPiCarX repository root:

```sh
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarDependencyInstaller --check
scripts/integration/py-agent/dev-tool/xHal_Rpi5CarIwGenerator --help
scripts/integration/py-agent/dev-tool/xWalkLicenseTool --help
scripts/integration/py-agent/dev-tool/xWalkCodeHealth validate-config
scripts/integration/py-agent/dev-tool/xWalkCodeHealth analyze
scripts/integration/py-agent/dev-tool/styler-tool/xWalkStyler check
python3 scripts/integration/py-agent/dev-tool/xWalkZuulValidator .zuul.yaml
python3 scripts/integration/py-agent/dev-tool/test/test_xWalkLicenseTool.py
```

The dependency installer's Raspberry Pi apply modes can modify the host and
must be used only on an explicitly approved device. The interface generator,
licence tool, CodeScene configuration validator, and all repository tests remain
host-safe. Code-health analysis requires an administrator-installed and licensed
CodeScene CLI; it never downloads one. The `test` directory contains host-only
developer-tool tests. The `styler-tool` directory contains the repository-wide
C++ formatter, its fallback configuration, documentation, and isolated tests.
