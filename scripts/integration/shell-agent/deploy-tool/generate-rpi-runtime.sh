#!/usr/bin/env bash

set -eu

usage() {
    echo "Usage: $0 [--build-directory DIRECTORY] [--runtime-user USER] [hardware options]"
    echo "  [--local-prefix DIRECTORY]"
    echo "  [--profile robot_hat_v4|robot_hat_v5] [--gpio-device /dev/gpiochipN]"
    echo "  [--i2c-device /dev/i2c-N] [--spi-device /dev/spidevN.N] [--camera csi|usb]"
    echo "  [--voice-capture-device DEVICE] [--voice-mixer-device DEVICE]"
    echo "  [--voice-mixer-element ELEMENT] [--piper-executable PATH]"
    echo "  [--ollama-manifest FILE] [--initialize-only]"
}

script_directory="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=rpi-defaults.conf
. "$script_directory/rpi-defaults.conf"
workspace_root="$(git -C "$script_directory" rev-parse --show-toplevel)"
build_directory="$workspace_root/build-rpi"
runtime_user="$XWALK_DEFAULT_RPI_RUNTIME_USER"
local_prefix=""
profile="$XWALK_DEFAULT_RPI_PROFILE"
gpio_device="$XWALK_DEFAULT_RPI_GPIO_DEVICE"
i2c_device="$XWALK_DEFAULT_RPI_I2C_DEVICE"
spi_device="$XWALK_DEFAULT_RPI_SPI_DEVICE"
camera="$XWALK_DEFAULT_RPI_CAMERA"
voice_capture_device="$XWALK_DEFAULT_RPI_VOICE_CAPTURE_DEVICE"
voice_mixer_device="$XWALK_DEFAULT_RPI_VOICE_MIXER_DEVICE"
voice_mixer_element="$XWALK_DEFAULT_RPI_VOICE_MIXER_ELEMENT"
piper_executable="$XWALK_DEFAULT_RPI_PIPER_EXECUTABLE"
ollama_manifest=""
initialize_only="false"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --build-directory) build_directory="${2-}"; shift 2 ;;
        --runtime-user) runtime_user="${2-}"; shift 2 ;;
        --local-prefix) local_prefix="${2-}"; shift 2 ;;
        --profile) profile="${2-}"; shift 2 ;;
        --gpio-device) gpio_device="${2-}"; shift 2 ;;
        --i2c-device) i2c_device="${2-}"; shift 2 ;;
        --spi-device) spi_device="${2-}"; shift 2 ;;
        --camera) camera="${2-}"; shift 2 ;;
        --voice-capture-device) voice_capture_device="${2-}"; shift 2 ;;
        --voice-mixer-device) voice_mixer_device="${2-}"; shift 2 ;;
        --voice-mixer-element) voice_mixer_element="${2-}"; shift 2 ;;
        --piper-executable) piper_executable="${2-}"; shift 2 ;;
        --ollama-manifest) ollama_manifest="${2-}"; shift 2 ;;
        --initialize-only) initialize_only="true"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

if [ "$profile" != "robot_hat_v4" ] && [ "$profile" != "robot_hat_v5" ]; then
    echo "--profile must be robot_hat_v4 or robot_hat_v5." >&2
    exit 2
fi
printf '%s\n' "$gpio_device" | grep -Eq '^/dev/gpiochip[0-9]+$' || {
    echo "Invalid GPIO device path: $gpio_device" >&2
    exit 2
}
printf '%s\n' "$i2c_device" | grep -Eq '^/dev/i2c-[0-9]+$' || {
    echo "Invalid I2C device path: $i2c_device" >&2
    exit 2
}
printf '%s\n' "$spi_device" | grep -Eq '^/dev/spidev[0-9]+\.[0-9]+$' || {
    echo "Invalid SPI device path: $spi_device" >&2
    exit 2
}
if [ "$camera" != "csi" ] && [ "$camera" != "usb" ]; then
    echo "--camera must be csi or usb." >&2
    exit 2
fi
if [ -z "$voice_capture_device" ] || [ -z "$voice_mixer_device" ] || \
    [ -z "$voice_mixer_element" ] || [ -z "$piper_executable" ]; then
    echo "Raspberry Pi voice deployment overrides must not be empty." >&2
    exit 2
fi

case "$build_directory" in
    /*) ;;
    *) build_directory="$(CDPATH='' cd -- "$(dirname -- "$build_directory")" && pwd)/$(basename -- "$build_directory")" ;;
esac

runtime_account=""
runtime_home=""
if runtime_account="$(getent passwd "$runtime_user")"; then
    runtime_home="$(printf '%s\n' "$runtime_account" | awk -F: 'NR == 1 { print $6 }')"
fi
if [ -z "$runtime_home" ] || [ ! -d "$runtime_home" ]; then
    if [ "$initialize_only" = "true" ]; then
        runtime_home="/home/$runtime_user"
    else
        echo "Unable to resolve the runtime home for $runtime_user." >&2
        exit 2
    fi
fi
if [ "$runtime_user" = "$(id -un)" ] && [ -n "${HOME-}" ] && [ "$HOME" != "$runtime_home" ]; then
    echo "HOME does not match the account database for $runtime_user." >&2
    exit 2
fi
if [ -z "$local_prefix" ]; then
    local_prefix="$runtime_home/.local"
fi
case "$local_prefix" in
    /*) ;;
    *) echo "--local-prefix must be an absolute path." >&2; exit 2 ;;
esac

if [ -z "$ollama_manifest" ]; then
    ollama_manifest="$local_prefix/share/ollama/models/manifests/registry.ollama.ai/library/llama3.2/3b"
fi
case "$ollama_manifest" in
    /*) ;;
    *) echo "--ollama-manifest must be an absolute path." >&2; exit 2 ;;
esac

source_configuration="$workspace_root/xWalk-rpi5-hw/xWalkController/xWalkConfig"
runtime_directory="$build_directory/runtime"
mkdir -p "$build_directory"
rm -f -- "$build_directory/xwalk"

if [ "$initialize_only" = "true" ] && [ -f "$runtime_directory/picar-x.conf" ] && \
    [ -d "$runtime_directory/picar-x.d" ]; then
    echo "Preserved existing generated runtime configuration at $runtime_directory"
    exit 0
fi
temporary_runtime="$(mktemp -d "$build_directory/.runtime.XXXXXX")"
cleanup() {
    rm -rf -- "$temporary_runtime"
}
trap cleanup EXIT HUP INT TERM
cp -a "$source_configuration/." "$temporary_runtime/"

set_configuration_value() {
    local file_path="$1"
    local key="$2"
    local value="$3"
    local temporary_file
    temporary_file="$(mktemp "${file_path}.XXXXXX")"
    awk -v requested_key="$key" -v replacement="$value" '
        BEGIN { replaced = 0 }
        {
            separator = index($0, "=")
            name = separator == 0 ? "" : substr($0, 1, separator - 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
            if (name == requested_key) {
                print requested_key " = " replacement
                replaced = 1
            } else {
                print
            }
        }
        END {
            if (replaced == 0) {
                print requested_key " = " replacement
            }
        }
    ' "$file_path" > "$temporary_file"
    mv -- "$temporary_file" "$file_path"
}

set_configuration_value "$temporary_runtime/picar-x.d/vision.conf" camera_connection "$camera"
if [ "$camera" = "csi" ]; then
    set_configuration_value "$temporary_runtime/picar-x.d/vision.conf" camera_csi_executable \
        "$runtime_home/.local/bin/rpicam-still"
    set_configuration_value "$temporary_runtime/picar-x.d/vision.conf" camera_csi_device /dev/media0
    set_configuration_value "$temporary_runtime/picar-x.d/vision.conf" video_stream_camera_backend libcamera
    set_configuration_value "$temporary_runtime/picar-x.d/vision.conf" video_stream_camera_device csi
else
    set_configuration_value "$temporary_runtime/picar-x.d/vision.conf" video_stream_camera_backend v4l2
    set_configuration_value "$temporary_runtime/picar-x.d/vision.conf" video_stream_camera_device /dev/video0
fi

set_configuration_value "$temporary_runtime/picar-x.d/hardware.conf" hardware_board "$profile"
set_configuration_value "$temporary_runtime/picar-x.d/hardware.conf" hardware_i2c_device "$i2c_device"
set_configuration_value "$temporary_runtime/picar-x.d/hardware.conf" hardware_gpio_device "$gpio_device"
set_configuration_value "$temporary_runtime/picar-x.d/hardware.conf" hardware_gpio_chip_name ""
set_configuration_value "$temporary_runtime/picar-x.d/hardware.conf" hardware_gpio_chip_label ""
set_configuration_value "$temporary_runtime/picar-x.d/hardware.conf" hardware_spi_device "$spi_device"

set_configuration_value "$temporary_runtime/picar-x.d/voice.conf" voice_vosk_library \
    "$workspace_root/xWalk-rpi5-hw/xWalkLibrary/aarch64/lib/libvosk.so"
set_configuration_value "$temporary_runtime/picar-x.d/voice.conf" voice_vosk_model \
    "$workspace_root/xWalk-rpi5-hw/xWalkLibrary/common/models/vosk/vosk-model-small-en-us-0.15"
set_configuration_value "$temporary_runtime/picar-x.d/voice.conf" voice_capture_device "$voice_capture_device"
set_configuration_value "$temporary_runtime/picar-x.d/voice.conf" voice_mixer_device "$voice_mixer_device"
set_configuration_value "$temporary_runtime/picar-x.d/voice.conf" voice_mixer_element "$voice_mixer_element"
set_configuration_value "$temporary_runtime/picar-x.d/voice.conf" voice_piper_executable "$piper_executable"

ollama_configuration="$temporary_runtime/picar-x.d/ai/providers/ollama.conf"
set_configuration_value "$ollama_configuration" voice_language_model_provider ollama
set_configuration_value "$ollama_configuration" voice_language_model_endpoint \
    http://127.0.0.1:11434/api/chat
set_configuration_value "$ollama_configuration" voice_language_model_model_environment ""
set_configuration_value "$ollama_configuration" voice_language_model_model llama3.2:3b
set_configuration_value "$ollama_configuration" voice_ollama_model llama3.2:3b
set_configuration_value "$ollama_configuration" voice_ollama_model_manifest "$ollama_manifest"

rm -rf -- "$runtime_directory"
mv -- "$temporary_runtime" "$runtime_directory"
trap - EXIT HUP INT TERM

echo "Generated $runtime_directory/picar-x.conf and $runtime_directory/picar-x.d"
