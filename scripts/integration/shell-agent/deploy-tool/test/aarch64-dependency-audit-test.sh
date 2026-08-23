#!/usr/bin/env bash

set -eu

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repository_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
audit_script="$repository_root/scripts/integration/shell-agent/deploy-tool/aarch64-dependency-audit.sh"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

sysroot="$fixture_root/sysroot"
mkdir -p "$sysroot/usr/include" "$sysroot/usr/lib/aarch64-linux-gnu/pkgconfig"

fake_pkg_config="$fixture_root/pkg-config"
apply_fake_pkg_config()
{
    mode="$1"
    sed "s|@SYSROOT@|$sysroot|g; s|@MODE@|$mode|g" \
        "$repository_root/scripts/integration/shell-agent/deploy-tool/test/fixtures/aarch64-fake-pkg-config.sh.in" \
        > "$fake_pkg_config"
    chmod 0700 "$fake_pkg_config"
}

apply_fake_pkg_config complete
XWALK_TARGET_PKG_CONFIG="$fake_pkg_config" XWALK_AARCH64_SYSROOT="$sysroot" \
    bash "$audit_script" > "$fixture_root/complete.out" 2> "$fixture_root/complete.err"
grep -q '^AVAILABLE: Protobuf (protobuf)$' "$fixture_root/complete.out"
grep -q '^ARM64 dependency audit summary: missing=0 contamination=0$' "$fixture_root/complete.out"

apply_fake_pkg_config missing
if XWALK_TARGET_PKG_CONFIG="$fake_pkg_config" XWALK_AARCH64_SYSROOT="$sysroot" \
    bash "$audit_script" > "$fixture_root/missing.out" 2> "$fixture_root/missing.err"; then
    echo "ARM64 dependency audit accepted a missing target dependency." >&2
    exit 1
fi
grep -q '^MISSING: Protobuf ' "$fixture_root/missing.err"
grep -q '^ARM64 dependency audit summary: missing=1 contamination=0$' "$fixture_root/missing.out"

apply_fake_pkg_config contaminated
set +e
XWALK_TARGET_PKG_CONFIG="$fake_pkg_config" XWALK_AARCH64_SYSROOT="$sysroot" \
    bash "$audit_script" > "$fixture_root/contaminated.out" 2> "$fixture_root/contaminated.err"
audit_status=$?
set -e
test "$audit_status" -eq 2
grep -q '^CONTAMINATION: protobuf metadata resolved outside the sysroot:' \
    "$fixture_root/contaminated.err"
grep -q '^ARM64 dependency audit summary: missing=0 contamination=1$' \
    "$fixture_root/contaminated.out"

cp /bin/true "$sysroot/usr/lib/libhostfake.so"
apply_fake_pkg_config wrong_arch
set +e
XWALK_TARGET_PKG_CONFIG="$fake_pkg_config" XWALK_AARCH64_SYSROOT="$sysroot" \
    bash "$audit_script" > "$fixture_root/wrong-arch.out" 2> "$fixture_root/wrong-arch.err"
audit_status=$?
set -e
test "$audit_status" -eq 2
grep -q '^CONTAMINATION: non-AArch64 library:' "$fixture_root/wrong-arch.err"
grep -q '^ARM64 dependency audit summary: missing=0 contamination=1$' \
    "$fixture_root/wrong-arch.out"

if XWALK_TARGET_PKG_CONFIG="$fake_pkg_config" bash "$audit_script" \
    > "$fixture_root/no-sysroot.out" 2> "$fixture_root/no-sysroot.err"; then
    echo "ARM64 dependency audit accepted a missing sysroot selection." >&2
    exit 1
fi
grep -q '^Usage:' "$fixture_root/no-sysroot.err"

echo "xWalk ARM64 dependency-audit host tests passed."
