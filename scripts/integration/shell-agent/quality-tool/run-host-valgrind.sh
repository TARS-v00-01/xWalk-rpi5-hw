#!/usr/bin/env bash

set -u

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repository_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
product_root="$repository_root/xWalk-rpi5-hw"

if ! command -v valgrind >/dev/null 2>&1; then
    echo "VALGRIND: SKIPPED_MISSING_TOOL - valgrind was not found"
    exit 2
fi

cd "$repository_root" || exit 1
memorycheck_options="--leak-check=full"
memorycheck_options+=" --show-leak-kinds=definite,indirect,possible"
memorycheck_options+=" --errors-for-leak-kinds=definite,indirect,possible"
memorycheck_options+=" --track-origins=yes --track-fds=yes --error-exitcode=1"
cmake --fresh -S "$product_root" --preset valgrind \
    -DMEMORYCHECK_COMMAND="$(command -v valgrind)" \
    -DMEMORYCHECK_COMMAND_OPTIONS="$memorycheck_options" || exit 1
cmake --build build-host/valgrind --parallel || exit 1
memory_log_directory="$repository_root/build-host/valgrind/Testing/Temporary"
find "$memory_log_directory" -maxdepth 1 -type f -name 'MemoryChecker.*.log' -delete 2>/dev/null || true
ctest --test-dir build-host/valgrind -T memcheck --output-on-failure --timeout 180 \
    -L 'streaming|simulation|recorded-media|fault-injection' \
    -E 'RobotHatSimulation|Soak'
status=$?
if [ "$status" -ne 0 ]; then
    echo "VALGRIND: FAILED"
    exit "$status"
fi
if grep -Eq 'definitely lost: [1-9]|indirectly lost: [1-9]|possibly lost: [1-9]|ERROR SUMMARY: [1-9]' \
    "$memory_log_directory"/MemoryChecker.*.log; then
    echo "VALGRIND: FAILED - disallowed memory finding"
    exit 1
fi
if ! unexpected_descriptors="$("$repository_root/scripts/integration/shell-agent/quality-tool/validate-valgrind-descriptors.sh" \
    "$memory_log_directory"/MemoryChecker.*.log)"; then
    echo "VALGRIND: FAILED - non-inherited descriptors remained"
    printf '%s\n' "$unexpected_descriptors"
    exit 1
fi
echo "VALGRIND: PASSED"
