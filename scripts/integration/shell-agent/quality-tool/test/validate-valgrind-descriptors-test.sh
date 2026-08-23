#!/usr/bin/env bash

set -eu

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repository_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
validator="$repository_root/scripts/integration/shell-agent/quality-tool/validate-valgrind-descriptors.sh"
temporary_directory="$(mktemp -d)"
trap 'rm -rf -- "$temporary_directory"' EXIT

inherited_log="$temporary_directory/inherited.log"
leaked_log="$temporary_directory/leaked.log"

printf '%s\n' \
    '==4== FILE DESCRIPTORS: 7 open (3 std) at exit.' \
    '==4== Open file descriptor 6: /tmp/github-runner-command' \
    '==4==    <inherited from parent>' \
    '==4== Open file descriptor 5: MemoryChecker.20.log' \
    '==4==    <inherited from parent>' > "$inherited_log"

printf '%s\n' \
    '==5== FILE DESCRIPTORS: 6 open (3 std) at exit.' \
    '==5== Open file descriptor 5: MemoryChecker.32.log' \
    '==5==    <inherited from parent>' \
    '==5== Open file descriptor 4: /tmp/xwalk-leaked-descriptor' \
    '==5==    at 0x1234: open (open64.c:41)' > "$leaked_log"

"$validator" "$inherited_log"
if "$validator" "$leaked_log" > "$temporary_directory/output"; then
    echo "Expected a non-inherited descriptor to fail validation" >&2
    exit 1
fi
grep -F '/tmp/xwalk-leaked-descriptor' "$temporary_directory/output" >/dev/null

echo "VALGRIND_DESCRIPTOR_TEST: PASSED"
