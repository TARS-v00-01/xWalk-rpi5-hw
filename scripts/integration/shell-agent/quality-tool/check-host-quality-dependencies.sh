#!/usr/bin/env bash

set -u

status=0

tool_version() {
    local executable="$1"
    local version
    case "$(basename "$executable")" in
        ansible-playbook)
            version="$(ANSIBLE_HOME="${TMPDIR:-/tmp}/xwalk-ansible-home" \
                ANSIBLE_LOCAL_TEMP="${TMPDIR:-/tmp}/xwalk-ansible-local" \
                "$executable" --version 2>&1 | head -n 1)"
            ;;
        scan-build)
            version="clang-tools $(dpkg-query -W -f='${Version}' clang-tools 2>/dev/null || printf 'version unavailable')"
            ;;
        shellcheck)
            version="ShellCheck $("$executable" --version | awk '/^version:/ { print $2 }')"
            ;;
        *) version="$("$executable" --version 2>&1 | head -n 1)" ;;
    esac
    if [ -z "$version" ]; then
        version="version unavailable"
    fi
    printf '%s' "$version"
}

check_tool() {
    local name="$1"
    local executable
    executable="$(command -v "$name" 2>/dev/null || true)"
    if [ -z "$executable" ]; then
        printf '%-16s %-24s %-30s %s\n' "$name" "-" "-" "SKIPPED_MISSING_TOOL"
        status=2
        return
    fi
    printf '%-16s %-24s %-30s %s\n' "$name" "$executable" \
        "$(tool_version "$executable")" "AVAILABLE"
}

printf '%-16s %-24s %-30s %s\n' "TOOL" "PATH" "VERSION" "STATUS"
check_tool clang
check_tool clang++
check_tool clang-format
check_tool scan-build
check_tool llvm-cov
check_tool llvm-profdata
check_tool gcov
check_tool gcovr
check_tool valgrind
check_tool shellcheck
check_tool ansible-playbook

cat <<'EOF'

Ubuntu 24.04 installation command for missing host-quality tools:
sudo apt update
sudo apt install -y ansible-core clang clang-format clang-tools llvm gcovr lcov python3-yaml valgrind shellcheck
EOF

exit "$status"
