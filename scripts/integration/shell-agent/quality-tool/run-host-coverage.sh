#!/usr/bin/env bash

set -u

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repository_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
product_root="$repository_root/xWalk-rpi5-hw"
mode="${2-gcc}"

missing() {
    echo "COVERAGE_${mode^^}: SKIPPED_MISSING_TOOL - $1 was not found"
    exit 2
}

run_gcc_coverage() {
    command -v gcovr >/dev/null 2>&1 || missing gcovr
    command -v gcov >/dev/null 2>&1 || missing gcov
    cd "$repository_root" || return 1
    cmake -E remove_directory "$repository_root/build-host/coverage" || return 1
    cmake --fresh -S "$product_root" --preset coverage -DXWALK_COVERAGE_BACKEND=gcc || return 1
    cmake --build build-host/coverage --parallel || return 1
    ctest --test-dir build-host/coverage --output-on-failure --no-tests=error --timeout 120 || return 1
    gcovr --config scripts/integration/shell-agent/env-tool/quality/gcovr.cfg || return 1
    echo "COVERAGE_GCC: PASSED - build-host/coverage/coverage.html"
}

run_clang_coverage() {
    command -v llvm-profdata >/dev/null 2>&1 || missing llvm-profdata
    command -v llvm-cov >/dev/null 2>&1 || missing llvm-cov
    cd "$repository_root" || return 1
    cmake -E remove_directory "$repository_root/build-host/coverage-clang" || return 1
    cmake --fresh -S "$product_root" --preset coverage-clang || return 1
    cmake --build build-host/coverage-clang --parallel || return 1
    mkdir -p build-host/coverage-clang/profiles build-host/coverage-clang/html
    LLVM_PROFILE_FILE="$repository_root/build-host/coverage-clang/profiles/%p-%m.profraw" \
        ctest --test-dir build-host/coverage-clang --output-on-failure --no-tests=error \
            --timeout 120 || return 1
    llvm-profdata merge -sparse build-host/coverage-clang/profiles/*.profraw \
        -o build-host/coverage-clang/coverage.profdata || return 1

    local first_object=""
    local object_arguments=()
    while IFS= read -r executable; do
        if [ -z "$first_object" ]; then
            first_object="$executable"
        else
            object_arguments+=( -object "$executable" )
        fi
    done < <(find build-host/coverage-clang -type f -perm -111 \
        ! -path '*/CMakeFiles/*' ! -name '*.sh' -print | sort)
    if [ -z "$first_object" ]; then
        echo "COVERAGE_CLANG: FAILED - no instrumented executable found"
        return 1
    fi

    local ignore_regex='(^|/)(test|tests|xWalkTest|auto-gen|third_party)/|/usr/'
    llvm-cov report "$first_object" "${object_arguments[@]}" \
        -instr-profile=build-host/coverage-clang/coverage.profdata \
        -ignore-filename-regex="$ignore_regex" |
        tee build-host/coverage-clang/coverage-summary.txt || return 1
    llvm-cov show "$first_object" "${object_arguments[@]}" \
        -instr-profile=build-host/coverage-clang/coverage.profdata \
        -ignore-filename-regex="$ignore_regex" -format=html \
        -output-dir=build-host/coverage-clang/html || return 1
    llvm-cov export "$first_object" "${object_arguments[@]}" \
        -instr-profile=build-host/coverage-clang/coverage.profdata \
        -ignore-filename-regex="$ignore_regex" \
        >build-host/coverage-clang/coverage.json || return 1
    echo "COVERAGE_CLANG: PASSED - build-host/coverage-clang/html/index.html"
}

if [ "${1-}" != "run" ]; then
    echo "Usage: $0 run [gcc|clang]" >&2
    exit 2
fi

case "$mode" in
    gcc) run_gcc_coverage || { echo "COVERAGE_GCC: FAILED"; exit 1; } ;;
    clang) run_clang_coverage || { echo "COVERAGE_CLANG: FAILED"; exit 1; } ;;
    *) echo "Usage: $0 run [gcc|clang]" >&2; exit 2 ;;
esac
