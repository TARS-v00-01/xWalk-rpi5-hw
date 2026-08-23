#!/usr/bin/env bash

set -eu

usage() {
    echo "Usage: $0 [--runtime-user USER] [hardware options] [--dry-run|--check|--apply]"
    echo "  [--local-prefix DIRECTORY]"
    echo "  Builds pinned camera components, installs user Ollama, and generates build-rpi runtime files."
}

script_directory="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=rpi-defaults.conf
. "$script_directory/rpi-defaults.conf"

mode="dry-run"
runtime_user="$XWALK_DEFAULT_RPI_RUNTIME_USER"
local_prefix=""
profile="$XWALK_DEFAULT_RPI_PROFILE"
gpio_device="$XWALK_DEFAULT_RPI_GPIO_DEVICE"
i2c_device="$XWALK_DEFAULT_RPI_I2C_DEVICE"
spi_device="$XWALK_DEFAULT_RPI_SPI_DEVICE"
camera="$XWALK_DEFAULT_RPI_CAMERA"
while [ "$#" -gt 0 ]; do
    case "$1" in
        --runtime-user) runtime_user="${2-}"; shift 2 ;;
        --local-prefix) local_prefix="${2-}"; shift 2 ;;
        --profile) profile="${2-}"; shift 2 ;;
        --gpio-device) gpio_device="${2-}"; shift 2 ;;
        --i2c-device) i2c_device="${2-}"; shift 2 ;;
        --spi-device) spi_device="${2-}"; shift 2 ;;
        --camera) camera="${2-}"; shift 2 ;;
        --dry-run) mode="dry-run"; shift ;;
        --check) mode="check"; shift ;;
        --apply) mode="apply"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

workspace_root="$(git -C "$script_directory" rev-parse --show-toplevel)"
runtime_home="$(getent passwd "$runtime_user" | awk -F: 'NR == 1 { print $6 }')"
if [ -z "$runtime_home" ] || [ ! -d "$runtime_home" ]; then
    echo "Unable to resolve the runtime home for $runtime_user." >&2
    exit 2
fi
if [ "$runtime_user" != "$(id -un)" ]; then
    echo "Run this workflow while logged in as the selected runtime user: $runtime_user" >&2
    exit 2
fi
if [ -n "${HOME-}" ] && [ "$HOME" != "$runtime_home" ]; then
    echo "HOME does not match the account database for $runtime_user." >&2
    exit 2
fi
if [ "$(id -u)" -eq 0 ]; then
    echo "Run this workflow as the non-root xWalk runtime user." >&2
    exit 2
fi

architecture="$(dpkg --print-architecture 2>/dev/null || uname -m)"
model=""
if [ -r /proc/device-tree/model ]; then
    model="$(tr -d '\000' < /proc/device-tree/model)"
fi
if [ "$mode" != "dry-run" ]; then
    case "$architecture" in
        arm64|aarch64) ;;
        *) echo "This workflow requires an ARM64 Raspberry Pi." >&2; exit 2 ;;
    esac
    case "$model" in
        *"Raspberry Pi 5"*) ;;
        *) echo "This workflow requires a Raspberry Pi 5." >&2; exit 2 ;;
    esac
fi

if [ -z "$local_prefix" ]; then
    local_prefix="$runtime_home/.local"
fi
case "$local_prefix" in
    /*) ;;
    *) echo "--local-prefix must be an absolute path." >&2; exit 2 ;;
esac
local_bin="$local_prefix/bin"
local_lib="$local_prefix/lib/aarch64-linux-gnu"
local_share="$local_prefix/share"
local_plugin_directory="$local_lib/gstreamer-1.0"
local_camera_plugin="$local_plugin_directory/libgstlibcamera.so"
libcamera_commit="6c1dd9d55573010f710c9e190a73e7e76f0d9432"
rpicam_version="v1.12.0"
ollama_archive_url="https://ollama.com/download/ollama-linux-arm64.tgz"

echo "xWalk user-local Raspberry Pi setup"
echo "  mode: $mode"
echo "  runtime user: $runtime_user"
echo "  workspace: $workspace_root"
echo "  prefix: $local_prefix"
echo "  libcamera: $libcamera_commit"
echo "  rpicam-apps: $rpicam_version"
echo "  CSI device: /dev/media0"
echo "  no xWalk package or /usr installation will be performed"

required_commands=(awk cmake curl find git gst-inspect-1.0 ldd meson ninja pkg-config readelf tar)
missing_commands=()
for command_name in "${required_commands[@]}"; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        missing_commands+=("$command_name")
    fi
done
if [ "${#missing_commands[@]}" -ne 0 ]; then
    echo "Missing build commands: ${missing_commands[*]}" >&2
    echo "Install the Raspberry Pi OS build prerequisites before applying this workflow." >&2
    exit 2
fi

verify_local_camera_runtime() {
    if [ ! -r "$local_camera_plugin" ]; then
        echo "The user-local libcamera GStreamer plugin is missing: $local_camera_plugin" >&2
        return 1
    fi
    plugin_dependencies="$(ldd "$local_camera_plugin")"
    for camera_library in libcamera.so libcamera-base.so libpisp.so; do
        dependency_line="$(printf '%s\n' "$plugin_dependencies" | grep -F "$camera_library" || true)"
        if [ -z "$dependency_line" ] || ! printf '%s\n' "$dependency_line" | grep -Fq "$local_lib/"; then
            echo "$local_camera_plugin does not resolve $camera_library from $local_lib." >&2
            return 1
        fi
    done
    registry_file="$(mktemp "$runtime_home/.xwalk-gstreamer-registry.XXXXXX.bin")"
    if ! plugin_information="$(GST_PLUGIN_PATH_1_0="$local_plugin_directory" \
        GST_REGISTRY_1_0="$registry_file" gst-inspect-1.0 libcamerasrc 2>&1)"; then
        rm -f -- "$registry_file"
        echo "The user-local libcamera GStreamer source could not be inspected." >&2
        printf '%s\n' "$plugin_information" >&2
        return 1
    fi
    selected_plugin="$(printf '%s\n' "$plugin_information" | awk '$1 == "Filename" { print $2; exit }')"
    if [ "$selected_plugin" != "$local_camera_plugin" ]; then
        rm -f -- "$registry_file"
        echo "GStreamer selected $selected_plugin instead of $local_camera_plugin." >&2
        return 1
    fi
    for required_element in videoconvert appsink; do
        if ! GST_PLUGIN_PATH_1_0="$local_plugin_directory" GST_REGISTRY_1_0="$registry_file" \
            gst-inspect-1.0 "$required_element" >/dev/null 2>&1; then
            rm -f -- "$registry_file"
            echo "The required GStreamer element is unavailable: $required_element" >&2
            return 1
        fi
    done
    rm -f -- "$registry_file"
}

if [ "$mode" = "dry-run" ]; then
    echo "  camera action: build pinned sources into $local_prefix with bundled libpisp"
    echo "  verification: reject build-directory and /usr/local camera dependencies"
    echo "  Ollama action: install ARM64 distribution and a user systemd service"
    echo "  model action: pull llama3.2:3b into $local_share/ollama/models"
    echo "  configuration action: generate $workspace_root/build-rpi/runtime"
    echo "  access action: add $runtime_user to video and render"
    exit 0
fi

if [ "$mode" = "check" ]; then
    failures=0
    for required_path in "$local_bin/rpicam-still" "$local_bin/ollama"; do
        if [ ! -x "$required_path" ]; then
            echo "Missing executable: $required_path" >&2
            failures=$((failures + 1))
        fi
    done
    if [ ! -r "$local_share/ollama/models/manifests/registry.ollama.ai/library/llama3.2/3b" ]; then
        echo "The llama3.2:3b manifest is missing." >&2
        failures=$((failures + 1))
    fi
    if [ "$failures" -ne 0 ]; then
        exit 1
    fi
    camera_dependencies="$(ldd "$local_bin/rpicam-still")"
    if printf '%s\n' "$camera_dependencies" | grep -Eq '/usr/local|/build[^/]*/|/tmp/'; then
        echo "rpicam-still has a forbidden camera dependency path." >&2
        exit 1
    fi
    if ! printf '%s\n' "$camera_dependencies" | grep -F "$local_lib" | grep -Fq 'libcamera'; then
        echo "rpicam-still is not resolving libcamera from $local_lib." >&2
        exit 1
    fi
    verify_local_camera_runtime
    "$script_directory/generate-rpi-runtime.sh" \
        --runtime-user "$runtime_user" \
        --local-prefix "$local_prefix" \
        --profile "$profile" \
        --gpio-device "$gpio_device" \
        --i2c-device "$i2c_device" \
        --spi-device "$spi_device" \
        --camera "$camera" \
        --ollama-manifest "$local_share/ollama/models/manifests/registry.ollama.ai/library/llama3.2/3b"
    echo "User-local Raspberry Pi setup is ready."
    exit 0
fi

mkdir -p "$local_bin" "$local_lib" "$local_share"
build_root="$(mktemp -d "$runtime_home/.xwalk-camera-build.XXXXXX")"
archive_path="$(mktemp "$runtime_home/.ollama-arm64.XXXXXX.tgz")"
cleanup() {
    rm -rf -- "$build_root"
    rm -f -- "$archive_path"
}
trap cleanup EXIT HUP INT TERM

libcamera_source="$build_root/libcamera"
libcamera_build="$build_root/libcamera-build"
git clone https://github.com/raspberrypi/libcamera.git "$libcamera_source"
git -C "$libcamera_source" checkout --detach "$libcamera_commit"
meson setup "$libcamera_build" "$libcamera_source" \
    --prefix="$local_prefix" \
    --libdir=lib/aarch64-linux-gnu \
    --buildtype=release \
    --force-fallback-for=libpisp \
    -Dpipelines=rpi/pisp \
    -Dipas=rpi/pisp \
    -Dv4l2=enabled \
    -Dgstreamer=enabled \
    -Dtest=false \
    -Dlc-compliance=disabled \
    -Dcam=disabled \
    -Dqcam=disabled \
    -Ddocumentation=disabled \
    -Dpycamera=disabled \
    -Dc_link_args="-Wl,-rpath=$local_lib" \
    -Dcpp_link_args="-Wl,-rpath=$local_lib"
ninja -C "$libcamera_build"
meson install -C "$libcamera_build"

rpicam_source="$build_root/rpicam-apps"
rpicam_build="$build_root/rpicam-apps-build"
git clone --branch "$rpicam_version" --depth 1 https://github.com/raspberrypi/rpicam-apps.git "$rpicam_source"
PKG_CONFIG_PATH="$local_lib/pkgconfig:${PKG_CONFIG_PATH-}" \
CMAKE_PREFIX_PATH="$local_prefix:${CMAKE_PREFIX_PATH-}" \
meson setup "$rpicam_build" "$rpicam_source" \
    --prefix="$local_prefix" \
    --libdir=lib/aarch64-linux-gnu \
    --buildtype=release \
    -Denable_libav=disabled \
    -Denable_drm=disabled \
    -Denable_egl=disabled \
    -Denable_qt=disabled \
    -Denable_opencv=disabled \
    -Denable_tflite=disabled \
    -Denable_hailo=disabled \
    -Denable_imx500=false \
    -Dc_link_args="-Wl,-rpath=$local_lib" \
    -Dcpp_link_args="-Wl,-rpath=$local_lib"
ninja -C "$rpicam_build"
meson install -C "$rpicam_build"

camera_dependencies="$(ldd "$local_bin/rpicam-still")"
if printf '%s\n' "$camera_dependencies" | grep -Eq "$build_root|/usr/local"; then
    echo "rpicam-still has a build-directory or /usr/local dependency." >&2
    exit 1
fi
if ! printf '%s\n' "$camera_dependencies" | grep -F "$local_lib" | grep -Fq 'libcamera'; then
    echo "rpicam-still did not resolve libcamera from $local_lib." >&2
    exit 1
fi
if ! readelf -d "$local_bin/rpicam-still" | grep -Fq "$local_lib"; then
    echo "rpicam-still does not contain the required user-local runtime search path." >&2
    exit 1
fi
verify_local_camera_runtime

if [ ! -x "$local_bin/ollama" ]; then
    curl --fail --location --proto '=https' --tlsv1.2 "$ollama_archive_url" --output "$archive_path"
    tar -xzf "$archive_path" -C "$local_prefix"
fi
if [ ! -x "$local_bin/ollama" ]; then
    echo "The official Ollama archive did not install $local_bin/ollama." >&2
    exit 1
fi

service_directory="$runtime_home/.config/systemd/user"
mkdir -p "$service_directory" "$local_share/ollama/models"
service_file="$service_directory/ollama.service"
install -m 0644 "$script_directory/systemd/ollama.service" "$service_file"
install -m 0644 "$script_directory/systemd/xwalk-jarvis.service" "$service_directory/xwalk-jarvis.service"
systemctl --user daemon-reload
systemctl --user enable --now ollama.service

service_ready="false"
service_attempt=0
while [ "$service_attempt" -lt 30 ]; do
    if "$local_bin/ollama" list >/dev/null 2>&1; then
        service_ready="true"
        break
    fi
    service_attempt=$((service_attempt + 1))
    sleep 1
done
if [ "$service_ready" != "true" ]; then
    echo "The Ollama user service did not become ready within 30 seconds." >&2
    exit 1
fi
if [ ! -r "$local_share/ollama/models/manifests/registry.ollama.ai/library/llama3.2/3b" ]; then
    OLLAMA_HOST=127.0.0.1:11434 OLLAMA_MODELS="$local_share/ollama/models" "$local_bin/ollama" pull llama3.2:3b
fi
ollama_manifest="$(find "$local_share/ollama/models/manifests" -type f \
    -path '*/registry.ollama.ai/library/llama3.2/3b' -print -quit)"
if [ -z "$ollama_manifest" ] || [ ! -r "$ollama_manifest" ]; then
    echo "The pulled llama3.2:3b manifest could not be located." >&2
    exit 1
fi

for access_group in video render; do
    if getent group "$access_group" >/dev/null 2>&1 && ! id -nG "$runtime_user" | tr ' ' '\n' | grep -Fxq "$access_group"; then
        sudo usermod -a -G "$access_group" "$runtime_user"
    fi
done

"$script_directory/generate-rpi-runtime.sh" \
    --runtime-user "$runtime_user" \
    --local-prefix "$local_prefix" \
    --profile "$profile" \
    --gpio-device "$gpio_device" \
    --i2c-device "$i2c_device" \
    --spi-device "$spi_device" \
    --camera "$camera" \
    --ollama-manifest "$ollama_manifest"
rm -rf -- "$build_root"
rm -f -- "$archive_path"
trap - EXIT HUP INT TERM

echo "Setup completed without installing xWalk or camera files under /usr or /usr/local."
echo "Log out and back in, or reboot, before using the video and render group memberships."
echo "After reboot, test CSI with: $local_bin/rpicam-still --list-cameras"
echo "Then run: $workspace_root/build-rpi/cmake/xWalkController/xWalkApp/xwalk-picarx-control doctor"
