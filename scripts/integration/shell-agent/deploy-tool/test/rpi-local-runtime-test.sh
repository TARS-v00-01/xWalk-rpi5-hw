#!/usr/bin/env bash

set -eu

script_directory="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
repository_root="$(git -C "$script_directory" rev-parse --show-toplevel)"
configuration_script="$script_directory/../configure-rpi-runtime.sh"
test_directory="$(mktemp -d)"
cleanup() {
    rm -rf -- "$test_directory"
}
trap cleanup EXIT HUP INT TERM

build_directory="$test_directory/build-rpi"
runtime_home="$(getent passwd "$(id -un)" | awk -F: 'NR == 1 { print $6 }')"
manifest="$runtime_home/.local/share/ollama/models/manifests/registry.ollama.ai/library/llama3.2/3b"
mkdir -p "$build_directory"
touch "$build_directory/xwalk"
"$configuration_script" \
    --build-directory "$build_directory" \
    --runtime-user "$(id -un)" \
    --ollama-manifest "$manifest" \
    --generate-only >/dev/null

configuration="$build_directory/runtime/picar-x.conf"
vision="$build_directory/runtime/picar-x.d/vision.conf"
hardware="$build_directory/runtime/picar-x.d/hardware.conf"
voice="$build_directory/runtime/picar-x.d/voice.conf"
features="$build_directory/runtime/picar-x.d/ai/features.conf"
ollama="$build_directory/runtime/picar-x.d/ai/providers/ollama.conf"

test -f "$configuration"
grep -Fxq "camera_connection = csi" "$vision"
grep -Fxq "camera_csi_executable = $runtime_home/.local/bin/rpicam-still" "$vision"
grep -Fxq "camera_csi_device = /dev/media0" "$vision"
grep -Fxq "video_stream_camera_backend = libcamera" "$vision"
grep -Fxq "video_stream_camera_device = csi" "$vision"
grep -Fxq "hardware_board = robot_hat_v4" "$hardware"
grep -Fxq "hardware_gpio_device = /dev/gpiochip4" "$hardware"
grep -Eq '^hardware_gpio_chip_name =[[:space:]]*$' "$hardware"
grep -Eq '^hardware_gpio_chip_label =[[:space:]]*$' "$hardware"
grep -Fq "/xWalk-rpi5-hw/xWalkLibrary/aarch64/lib/libvosk.so" "$voice"
grep -Fxq "voice_capture_device = plughw:CARD=Device,DEV=0" "$voice"
grep -Fxq "voice_mixer_device = pulse" "$voice"
grep -Fxq "voice_mixer_element = Master" "$voice"
grep -Fxq "voice_piper_executable = /opt/xwalk/piper-tts/venv/bin/piper" "$voice"
grep -Fxq "voice_active_car_model = gpt-4o-mini" "$features"
grep -Fxq "gpt_car_model = gpt-4o" "$features"
grep -Fxq "voice_active_car_gpt_provider = ollama" "$features"
grep -Fxq "voice_active_car_gpt_api_key_environment =" "$features"
grep -Fxq "voice_active_car_gpt_endpoint = http://127.0.0.1:11434/api/chat" "$features"
grep -Fxq "voice_active_car_gpt_model = llama3.2:3b" "$features"
grep -Fxq "voice_active_car_gpt_timeout_ms = 120000" "$features"
grep -Fxq "voice_active_car_gpt_maximum_output_tokens = 256" "$features"
grep -Fxq "voice_active_car_gpt_maximum_messages = 20" "$features"
grep -Fxq "voice_active_car_gpt_web_search_enabled = true" "$features"
grep -Fxq "voice_active_car_gpt_web_search_endpoint = http://127.0.0.1:8080/search" "$features"
grep -Fxq "voice_active_car_gpt_with_image = false" "$features"
grep -Fxq "voice_active_car_gpt_continuous_conversation = true" "$features"
grep -Fxq "voice_active_car_gpt_conversation_idle_timeout_ms = 30000" "$features"
grep -Fxq "voice_active_car_gpt_conversation_maximum_rounds = 10" "$features"
grep -Fxq 'voice_active_car_gpt_sleep_phrases = "goodbye jarvis,go to sleep,stop listening"' "$features"
grep -Fxq "voice_language_model_provider = ollama" "$ollama"
grep -Fxq "voice_language_model_endpoint = http://127.0.0.1:11434/api/chat" "$ollama"
grep -Fxq "voice_language_model_model = llama3.2:3b" "$ollama"
grep -Fxq "voice_ollama_model = llama3.2:3b" "$ollama"
grep -Fxq "voice_ollama_model_manifest = $manifest" "$ollama"
test ! -e "$build_directory/xwalk"

runtime_checksum="$(find "$build_directory/runtime" -type f -exec sha256sum {} + | sort | sha256sum)"
"$script_directory/../generate-rpi-runtime.sh" \
    --build-directory "$build_directory" \
    --runtime-user "$(id -un)" \
    --ollama-manifest "$manifest" \
    --initialize-only >/dev/null
test "$runtime_checksum" = "$(find "$build_directory/runtime" -type f -exec sha256sum {} + | sort | sha256sum)"

source_checksum="$(find "$repository_root/xWalk-rpi5-hw/xWalkController/xWalkConfig" -type f \
    -exec sha256sum {} + | sort | sha256sum)"
"$script_directory/../generate-rpi-runtime.sh" \
    --build-directory "$build_directory" \
    --runtime-user "$(id -un)" \
    --local-prefix "$test_directory/operator-prefix" \
    --profile robot_hat_v5 \
    --gpio-device /dev/gpiochip7 \
    --i2c-device /dev/i2c-3 \
    --spi-device /dev/spidev2.1 \
    --camera usb \
    --ollama-manifest "$manifest" >/dev/null
grep -Fxq "hardware_board = robot_hat_v5" "$hardware"
grep -Fxq "hardware_gpio_device = /dev/gpiochip7" "$hardware"
grep -Fxq "hardware_i2c_device = /dev/i2c-3" "$hardware"
grep -Fxq "hardware_spi_device = /dev/spidev2.1" "$hardware"
grep -Fxq "camera_connection = usb" "$vision"
grep -Fxq "video_stream_camera_backend = v4l2" "$vision"
grep -Fxq "video_stream_camera_device = /dev/video0" "$vision"
test ! -e "$build_directory/xwalk"
test "$source_checksum" = "$(find "$repository_root/xWalk-rpi5-hw/xWalkController/xWalkConfig" \
    -type f -exec sha256sum {} + | sort | sha256sum)"

echo "RPi user-local runtime generation test passed"
