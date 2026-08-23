#!/usr/bin/env bash

set -u

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repository_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
product_root="$repository_root/xWalk-rpi5-hw"
mode="${1-}"

result() {
    printf '%s: %s%s\n' "$1" "$2" "${3:+ - $3}"
}

require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        result "$2" "SKIPPED_MISSING_TOOL" "$1 was not found"
        exit 2
    fi
}

tracer_pid() {
    awk '/^TracerPid:/ { print $2 }' /proc/self/status
}

run_asan() {
    cd "$repository_root" || exit 1
    cmake --fresh -S "$product_root" --preset sanitizers || return 1
    cmake --build build-host/sanitizers --parallel || return 1
    # xCliGoogleTestHostTest embeds the same legacy Controller scenario. Keep
    # that isolated wrapper and omit the duplicate fork-heavy executable.
    # LeakSanitizer has a separate runtime probe and build because traced hosts
    # cannot initialize its process inspection reliably.
    ASAN_OPTIONS="abort_on_error=1:detect_leaks=0:strict_string_checks=1:check_initialization_order=1" \
        UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1" \
        ctest --test-dir build-host/sanitizers --output-on-failure --no-tests=error \
            --timeout 120 -E '^xWalkControllerHostTest$' || return 1
    result "ASAN_UBSAN" "PASSED"
}

run_lsan() {
    require_tool g++ LEAK_SANITIZER
    local tracer
    tracer="$(tracer_pid)"
    if [ "${tracer:-0}" != "0" ]; then
        result "LEAK_SANITIZER" "BLOCKED_BY_ENVIRONMENT" "TracerPid=$tracer"
        return 3
    fi

    local probe_directory="$repository_root/build-host/leak-sanitizer-probe"
    local probe_log="$probe_directory/probe.log"
    mkdir -p "$probe_directory"
    g++ -std=c++17 -g -fno-omit-frame-pointer -fsanitize=address,undefined \
        "$repository_root/scripts/integration/cpp-tool/quality/probes/xWalkLeakSanitizerProbe.cpp" \
        -o "$probe_directory/xWalkLeakSanitizerProbe" || return 1
    ASAN_OPTIONS="detect_leaks=1:halt_on_error=1" timeout 30s \
        "$probe_directory/xWalkLeakSanitizerProbe" >"$probe_log" 2>&1
    local probe_status=$?
    if [ "$probe_status" -eq 124 ]; then
        result "LEAK_SANITIZER" "BLOCKED_BY_ENVIRONMENT" "negative probe timed out"
        return 3
    fi
    if grep -Eq 'LeakSanitizer.*(ptrace|does not work)|failed to.*sanitizer|CHECK failed' "$probe_log"; then
        result "LEAK_SANITIZER" "BLOCKED_BY_ENVIRONMENT" "$(tail -n 1 "$probe_log")"
        return 3
    fi
    if [ "$probe_status" -eq 0 ] || ! grep -q 'LeakSanitizer: detected memory leaks' "$probe_log"; then
        result "LEAK_SANITIZER" "FAILED" "intentional leak was not rejected"
        return 1
    fi

    cd "$repository_root" || return 1
    cmake --fresh -S "$product_root" --preset leak-sanitizer || return 1
    cmake --build build-host/leak-sanitizer --parallel || return 1
    # xCliGoogleTestHostTest forks after the sanitizer runtime is initialized.
    # Its embedded Controller scenario is covered directly by
    # xWalkControllerHostTest, without the fork-time sanitizer deadlock risk.
    ASAN_OPTIONS="detect_leaks=1:halt_on_error=1" \
        UBSAN_OPTIONS="halt_on_error=1:print_stacktrace=1" \
        ctest --test-dir build-host/leak-sanitizer --output-on-failure --no-tests=error \
            --timeout 120 -E '^xCliGoogleTestHostTest$' \
            >"$repository_root/build-host/leak-sanitizer/ctest.log" 2>&1
    local test_status=$?
    if grep -Eq 'LeakSanitizer.*(ptrace|does not work)|failed to.*sanitizer|CHECK failed' \
        "$repository_root/build-host/leak-sanitizer/ctest.log"; then
        result "LEAK_SANITIZER" "BLOCKED_BY_ENVIRONMENT" "runtime initialization failed"
        return 3
    fi
    if [ "$test_status" -ne 0 ]; then
        cat "$repository_root/build-host/leak-sanitizer/ctest.log"
        ctest --test-dir build-host/leak-sanitizer --rerun-failed --output-on-failure \
            --no-tests=error --timeout 120 \
            || true
        result "LEAK_SANITIZER" "FAILED" "project test failure"
        return 1
    fi
    result "LEAK_SANITIZER" "PASSED"
}

run_tsan() {
    require_tool g++ THREAD_SANITIZER
    require_tool setarch THREAD_SANITIZER
    local aslr
    aslr="$(cat /proc/sys/kernel/randomize_va_space)"
    printf 'ThreadSanitizer ASLR setting: randomize_va_space=%s\n' "$aslr"

    local probe_directory="$repository_root/build-host/thread-sanitizer-probe"
    local probe_log="$probe_directory/probe.log"
    mkdir -p "$probe_directory"
    g++ -std=c++17 -g -O1 -fPIE -pie -fno-omit-frame-pointer -fsanitize=thread \
        "$repository_root/scripts/integration/cpp-tool/quality/probes/xWalkThreadSanitizerProbe.cpp" \
        -o "$probe_directory/xWalkThreadSanitizerProbe" || return 1
    local architecture
    architecture="$(uname -m)"
    TSAN_OPTIONS="halt_on_error=1:history_size=7" timeout 120s \
        setarch "$architecture" -R \
        "$probe_directory/xWalkThreadSanitizerProbe" >"$probe_log" 2>&1
    local probe_status=$?
    if [ "$probe_status" -eq 124 ]; then
        result "THREAD_SANITIZER" "BLOCKED_BY_ENVIRONMENT" "negative probe timed out"
        return 3
    fi
    if grep -Eqi 'unexpected memory mapping|failed to mmap|cannot mmap|shadow memory' "$probe_log"; then
        result "THREAD_SANITIZER" "BLOCKED_BY_ENVIRONMENT" "$(head -n 1 "$probe_log")"
        return 3
    fi
    if [ "$probe_status" -eq 0 ] || ! grep -q 'WARNING: ThreadSanitizer: data race' "$probe_log"; then
        result "THREAD_SANITIZER" "FAILED" "intentional data race was not rejected"
        return 1
    fi

    cd "$repository_root" || return 1
    cmake --fresh -S "$product_root" --preset thread-sanitizer || return 1
    cmake --build build-host/thread-sanitizer --parallel || return 1
    local test_log="$repository_root/build-host/thread-sanitizer/ctest.log"
    TSAN_OPTIONS="halt_on_error=1:history_size=7" \
        setarch "$architecture" -R ctest --test-dir build-host/thread-sanitizer \
        --output-on-failure --no-tests=error --timeout 120 \
        -j 1 -L 'streaming|simulation|lifecycle' \
        -E 'xWalkComputerVisionOpenCvHostTest|xCliSequenceTest' >"$test_log" 2>&1
    local test_status=$?
    if grep -Eqi 'unexpected memory mapping|failed to mmap|cannot mmap|shadow memory' "$test_log"; then
        result "THREAD_SANITIZER" "BLOCKED_BY_ENVIRONMENT" \
            "instrumented project executables cannot reserve shadow memory"
        return 3
    fi
    if [ "$test_status" -ne 0 ]; then
        tail -n 80 "$test_log"
        result "THREAD_SANITIZER" "FAILED" "focused project test failure"
        return 1
    fi
    result "THREAD_SANITIZER" "PASSED"
}

case "$mode" in
    asan) run_asan || { result "ASAN_UBSAN" "FAILED"; exit 1; } ;;
    lsan) run_lsan; exit $? ;;
    tsan) run_tsan; exit $? ;;
    *) echo "Usage: $0 {asan|lsan|tsan}" >&2; exit 2 ;;
esac
