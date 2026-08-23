# xWalk Styler

`xWalkStyler` formats and validates project-owned C++ sources and headers with
the xWalk mandatory style. It is safe for local use, GitHub Actions, and Gerrit
CI, supports paths containing spaces, and never edits files during `check`.

## Installation and dependencies

The tool is repository-owned and needs no installation. Install
`clang-format` and run it from the repository root. Bash, Git, GNU `find`,
`realpath`, `sort`, `cmp`, `grep`, `awk`, and `mktemp` are also required.

```sh
sudo apt-get install clang-format
chmod +x scripts/integration/py-agent/dev-tool/styler-tool/xWalkStyler
```

Set `XWALK_CLANG_FORMAT` only when a specific compatible executable must be
used. Otherwise the tool resolves `clang-format` from `PATH`.

## Commands

```sh
scripts/integration/py-agent/dev-tool/styler-tool/xWalkStyler format
scripts/integration/py-agent/dev-tool/styler-tool/xWalkStyler format xWalk-rpi5-hw/xWalkHal
scripts/integration/py-agent/dev-tool/styler-tool/xWalkStyler check
scripts/integration/py-agent/dev-tool/styler-tool/xWalkStyler check xWalk-rpi5-hw/xWalkAgent
scripts/integration/py-agent/dev-tool/styler-tool/xWalkStyler format-file "source directory/example.cpp"
scripts/integration/py-agent/dev-tool/styler-tool/xWalkStyler check-file "source directory/example.cpp"
scripts/integration/py-agent/dev-tool/styler-tool/xWalkStyler --help
```

Without a directory, `format` and `check` use the enclosing Git repository
root. Directory commands discover `.cpp`, `.cc`, `.cxx`, `.h`, `.hpp`, and
`.hxx` files recursively. They exclude Git metadata, build trees, downloaded
dependencies, third-party trees, generated sources, and architecture dependency
prefixes.

For each file, the tool searches its directory and parents for the nearest
`.clang-format` or `_clang-format`. If none exists, it uses the configuration
shipped in this directory. Therefore a repository-root configuration takes
effect automatically while standalone source trees remain deterministic.

## Formatting rules

The configuration enforces four-space indentation, no tabs, Allman braces,
braces for inserted control-flow blocks, indented namespaces and types,
indented access specifiers and members, no single-line functions or control
blocks, and a 120-character column limit. The validator also checks source text
directly for tabs and lines exceeding 120 characters.

```cpp
namespace xWalk
{
    class MotorController
    {
        public:
            void updateMotorSpeed(int speed)
            {
                if (speed > 0)
                {
                    while (isMotorEnabled())
                    {
                        applyMotorSpeed(speed);
                    }
                }
                else
                {
                    stopMotor();
                }
            }
    };
}
```

## CI usage

Use `check` in automation because it prints each violating file without
modifying the checkout:

```sh
scripts/integration/py-agent/dev-tool/styler-tool/xWalkStyler check
```

Every completed command prints discovered, processed, passed, and failed file
counts. GitHub Actions and Gerrit CI run the same repository-root check during
Preparation.

## Exit codes

| Code | Meaning |
| ---: | --- |
| `0` | Every discovered file passed, or formatting completed successfully. |
| `1` | One or more files violated formatting or could not be formatted. |
| `2` | Usage, path validation, configuration, or dependency error. |

## Tests

```sh
python3 scripts/integration/py-agent/dev-tool/styler-tool/tests/test_xWalkStyler.py
shellcheck scripts/integration/py-agent/dev-tool/styler-tool/xWalkStyler
```
