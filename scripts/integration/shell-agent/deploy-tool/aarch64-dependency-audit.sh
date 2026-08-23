#!/usr/bin/env bash

set -eu

script_name="$(basename -- "$0")"
sysroot="${XWALK_AARCH64_SYSROOT:-}"
pkg_config_command="${XWALK_TARGET_PKG_CONFIG:-pkg-config}"
readelf_command="${XWALK_READELF:-readelf}"

usage()
{
    echo "Usage: XWALK_AARCH64_SYSROOT=/absolute/sysroot $script_name" >&2
}

is_path_in_sysroot()
{
    candidate_path="$1"

    case "$candidate_path" in
        "$sysroot"|"$sysroot"/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

report_remediation()
{
    echo "Install matching ARM64 development packages into the reviewed sysroot:" >&2
    echo "  libprotobuf-dev libgrpc++-dev libopencv-dev libasound2-dev" >&2
    echo "  libcurl4-openssl-dev libssl-dev libtinyxml2-dev libjson-c-dev" >&2
    echo "  libsndfile1-dev libyaml-cpp-dev and their target dependencies" >&2
}

inspect_library_file()
{
    library_file="$1"
    header_output=""

    if [ ! -f "$library_file" ]; then
        return 0
    fi
    if ! header_output="$($readelf_command -h "$library_file" 2>/dev/null)"; then
        return 0
    fi
    machine_lines="$(printf '%s\n' "$header_output" | sed -n '/Machine:/p')"
    if [ -z "$machine_lines" ]; then
        return 0
    fi
    if ! printf '%s\n' "$machine_lines" | grep -Evq 'Machine:[[:space:]]+(AArch64|ARM aarch64)'; then
        return 0
    fi

    echo "CONTAMINATION: non-AArch64 library: $library_file" >&2
    return 1
}

inspect_module_paths()
{
    module_name="$1"
    pc_directory="$($pkg_config_command --variable=pcfiledir "$module_name")"
    library_flags="$($pkg_config_command --libs-only-L "$module_name")"

    if [ -z "$pc_directory" ] || [ ! -d "$pc_directory" ]; then
        echo "MISSING: $module_name metadata directory is unavailable: ${pc_directory:-<empty>}" >&2
        return 1
    fi
    pc_directory="$(CDPATH='' cd -- "$pc_directory" && pwd -P)"
    if ! is_path_in_sysroot "$pc_directory"; then
        echo "CONTAMINATION: $module_name metadata resolved outside the sysroot: ${pc_directory:-<empty>}" >&2
        return 2
    fi

    for library_flag in $library_flags; do
        case "$library_flag" in
            -L*)
                library_directory="${library_flag#-L}"
                if [ -d "$library_directory" ]; then
                    library_directory="$(CDPATH='' cd -- "$library_directory" && pwd -P)"
                fi
                if ! is_path_in_sysroot "$library_directory"; then
                    echo "CONTAMINATION: $module_name library path is outside the sysroot: $library_directory" >&2
                    return 2
                fi
                ;;
        esac
    done

    library_names="$($pkg_config_command --libs-only-l "$module_name")"
    library_directories="$sysroot/usr/lib/aarch64-linux-gnu $sysroot/usr/lib $sysroot/lib/aarch64-linux-gnu $sysroot/lib"
    for library_directory_flag in $library_flags; do
        case "$library_directory_flag" in
            -L*) library_directories="$library_directories ${library_directory_flag#-L}" ;;
        esac
    done
    for library_flag in $library_names; do
        case "$library_flag" in
            -l*)
                library_name="${library_flag#-l}"
                library_found=0
                for library_directory in $library_directories; do
                    for suffix in .so .a; do
                        library_file="$library_directory/lib$library_name$suffix"
                        if [ -e "$library_file" ]; then
                            resolved_library="$(readlink -f -- "$library_file")"
                            if ! is_path_in_sysroot "$resolved_library"; then
                                echo "CONTAMINATION: $module_name library resolves outside the sysroot: $resolved_library" >&2
                                return 2
                            fi
                            inspect_library_file "$resolved_library" || return 2
                            library_found=1
                            break
                        fi
                    done
                    if [ "$library_found" -eq 1 ]; then
                        break
                    fi
                done
                if [ "$library_found" -eq 0 ]; then
                    echo "MISSING: $module_name linker input lib$library_name was not found in the sysroot." >&2
                    return 1
                fi
                ;;
        esac
    done
    return 0
}

audit_dependency()
{
    display_name="$1"
    shift

    for module_name in "$@"; do
        if "$pkg_config_command" --exists "$module_name"; then
            inspect_status=0
            inspect_module_paths "$module_name" || inspect_status=$?
            if [ "${inspect_status:-0}" -eq 0 ]; then
                echo "AVAILABLE: $display_name ($module_name)"
                return 0
            fi
            return "$inspect_status"
        fi
    done

    echo "MISSING: $display_name (pkg-config modules: $*)" >&2
    return 1
}

record_dependency()
{
    audit_dependency "$@" || audit_status=$?
    if [ "${audit_status:-0}" -eq 2 ]; then
        contamination_count=$((contamination_count + 1))
    elif [ "${audit_status:-0}" -ne 0 ]; then
        missing_count=$((missing_count + 1))
    fi
    unset audit_status
}

if [ "$#" -gt 1 ]; then
    usage
    exit 64
fi
if [ "$#" -eq 1 ]; then
    sysroot="$1"
fi
if [ -z "$sysroot" ]; then
    usage
    exit 64
fi
case "$sysroot" in
    /*) ;;
    *)
        echo "The ARM64 sysroot path must be absolute: $sysroot" >&2
        exit 64
        ;;
esac
if [ ! -d "$sysroot/usr/include" ] || [ ! -d "$sysroot/usr/lib" ]; then
    echo "The ARM64 sysroot must contain usr/include and usr/lib: $sysroot" >&2
    exit 64
fi
sysroot="$(CDPATH='' cd -- "$sysroot" && pwd -P)"

if ! command -v "$pkg_config_command" >/dev/null 2>&1; then
    echo "Target dependency audit requires pkg-config on the x86 build host." >&2
    exit 69
fi
if ! command -v "$readelf_command" >/dev/null 2>&1; then
    echo "Target dependency audit requires readelf on the x86 build host." >&2
    exit 69
fi

pkg_config_directories="$sysroot/usr/lib/aarch64-linux-gnu/pkgconfig:$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR="$sysroot"
export PKG_CONFIG_LIBDIR="$pkg_config_directories"
unset PKG_CONFIG_PATH

missing_count=0
contamination_count=0

record_dependency Protobuf protobuf
record_dependency gRPC grpc++ grpc
record_dependency OpenCV opencv4
record_dependency ALSA alsa
record_dependency CURL libcurl
record_dependency OpenSSL openssl
record_dependency TinyXML2 tinyxml2
record_dependency JSON-C json-c
record_dependency libsndfile sndfile
record_dependency yaml-cpp yaml-cpp

echo "ARM64 dependency audit summary: missing=$missing_count contamination=$contamination_count"
if [ "$contamination_count" -ne 0 ]; then
    echo "Rejecting configuration because host or non-AArch64 dependencies were detected." >&2
    exit 2
fi
if [ "$missing_count" -ne 0 ]; then
    report_remediation
    exit 1
fi

echo "ARM64 dependency audit passed for sysroot: $sysroot"
