#!/usr/bin/env bash

set -eu

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repository_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
test_directory="$(mktemp -d)"
cleanup() {
    rm -rf -- "$test_directory"
}
trap cleanup EXIT HUP INT TERM

build_directory="$test_directory/cmake"
env SHELLOPTS=pipefail cmake -S "$repository_root/xWalk-rpi5-hw" -B "$build_directory" -G Ninja \
    -DBUILD_TESTING=OFF \
    -DXWALK_BUILD_RPI=ON \
    -DXWALK_ENABLE_PACKAGING=OFF >/dev/null

cmake -LA -N "$build_directory" > "$test_directory/cache.log"
grep -Fxq 'XWALK_RPI_PROFILE:STRING=robot_hat_v4' "$test_directory/cache.log"
grep -Fxq 'XWALK_RPI_RUNTIME_USER:STRING=xwalk' "$test_directory/cache.log"
grep -Fxq 'XWALK_RPI_LOCAL_PREFIX:PATH=/home/xwalk/.local' "$test_directory/cache.log"
grep -Fxq 'XWALK_RPI_CAMERA_LIBRARY_DIRECTORY:PATH=/home/xwalk/.local/lib/aarch64-linux-gnu' \
    "$test_directory/cache.log"
grep -Fxq \
    'XWALK_RPI_GSTREAMER_PLUGIN_DIRECTORY:PATH=/home/xwalk/.local/lib/aarch64-linux-gnu/gstreamer-1.0' \
    "$test_directory/cache.log"
grep -Fxq 'XWALK_RPI_GPIO_DEVICE:FILEPATH=/dev/gpiochip4' "$test_directory/cache.log"
grep -Fxq 'XWALK_RPI_I2C_DEVICE:FILEPATH=/dev/i2c-1' "$test_directory/cache.log"
grep -Fxq 'XWALK_RPI_SPI_DEVICE:FILEPATH=/dev/spidev0.0' "$test_directory/cache.log"
grep -Fxq 'XWALK_RPI_CAMERA:STRING=csi' "$test_directory/cache.log"
grep -Fxq 'XWALK_RPI_VOICE_CAPTURE_DEVICE:STRING=plughw:CARD=Device,DEV=0' "$test_directory/cache.log"
grep -Fxq 'XWALK_RPI_VOICE_MIXER_DEVICE:STRING=pulse' "$test_directory/cache.log"
grep -Fxq 'XWALK_RPI_VOICE_MIXER_ELEMENT:STRING=Master' "$test_directory/cache.log"
grep -Fxq 'XWALK_RPI_PIPER_EXECUTABLE:FILEPATH=/opt/xwalk/piper-tts/venv/bin/piper' \
    "$test_directory/cache.log"

cmake --build "$build_directory" --target help | grep -q '^rpi-provision:'
ninja -C "$build_directory" -t commands rpi-provision > "$test_directory/provision-commands.log"
grep -Fq 'setup-rpi-local.sh' "$test_directory/provision-commands.log"
grep -Fq 'setup-rpi.sh' "$test_directory/provision-commands.log"
grep -Fq -- '--profile robot_hat_v4' "$test_directory/provision-commands.log"
grep -Fq -- '--runtime-user xwalk' "$test_directory/provision-commands.log"
grep -Fq -- '--local-prefix /home/xwalk/.local' "$test_directory/provision-commands.log"
grep -Fq -- '--gpio-device /dev/gpiochip4' "$test_directory/provision-commands.log"
grep -Fq -- '--i2c-device /dev/i2c-1' "$test_directory/provision-commands.log"
grep -Fq -- '--spi-device /dev/spidev0.0' "$test_directory/provision-commands.log"
grep -Fq -- '--camera csi' "$test_directory/provision-commands.log"
grep -Fq -- '--template-config' "$test_directory/provision-commands.log"
grep -Fq -- '--template-fragments' "$test_directory/provision-commands.log"
grep -Fq -- '--with-vosk' "$test_directory/provision-commands.log"
grep -Fq -- '--validate-ollama' "$test_directory/provision-commands.log"
grep -Fq 'xwalk-picarx-control' "$test_directory/provision-commands.log"
grep -Fq \
    'XWALK_GSTREAMER_PLUGIN_DIRECTORY=\"/home/xwalk/.local/lib/aarch64-linux-gnu/gstreamer-1.0\"' \
    "$build_directory/build.ninja"
if grep -Fq '/home/xwalk' \
    "$repository_root/xWalk-rpi5-hw/xWalkController/xWalkApp/cli/hardware/src/xControllerMain.cpp"; then
    echo "The Raspberry Pi executable contains a hardcoded runtime username." >&2
    exit 1
fi

override_build_directory="$test_directory/override-cmake"
env SHELLOPTS=pipefail cmake -S "$repository_root/xWalk-rpi5-hw" -B "$override_build_directory" -G Ninja \
    -DBUILD_TESTING=OFF \
    -DXWALK_BUILD_RPI=ON \
    -DXWALK_ENABLE_PACKAGING=OFF \
    -DXWALK_RPI_PROFILE=robot_hat_v5 \
    -DXWALK_RPI_RUNTIME_USER=operator \
    -DXWALK_RPI_LOCAL_PREFIX=/srv/operator-camera \
    -DXWALK_RPI_GPIO_DEVICE=/dev/gpiochip7 \
    -DXWALK_RPI_I2C_DEVICE=/dev/i2c-3 \
    -DXWALK_RPI_SPI_DEVICE=/dev/spidev2.1 \
    -DXWALK_RPI_CAMERA=usb >/dev/null
cmake -LA -N "$override_build_directory" > "$test_directory/override-cache.log"
grep -Fxq 'XWALK_RPI_PROFILE:STRING=robot_hat_v5' "$test_directory/override-cache.log"
grep -Fxq 'XWALK_RPI_RUNTIME_USER:STRING=operator' "$test_directory/override-cache.log"
grep -Fxq 'XWALK_RPI_LOCAL_PREFIX:PATH=/srv/operator-camera' "$test_directory/override-cache.log"
grep -Fxq 'XWALK_RPI_CAMERA_LIBRARY_DIRECTORY:PATH=/srv/operator-camera/lib/aarch64-linux-gnu' \
    "$test_directory/override-cache.log"
grep -Fxq \
    'XWALK_RPI_GSTREAMER_PLUGIN_DIRECTORY:PATH=/srv/operator-camera/lib/aarch64-linux-gnu/gstreamer-1.0' \
    "$test_directory/override-cache.log"
grep -Fxq 'XWALK_RPI_GPIO_DEVICE:FILEPATH=/dev/gpiochip7' "$test_directory/override-cache.log"
grep -Fxq 'XWALK_RPI_I2C_DEVICE:FILEPATH=/dev/i2c-3' "$test_directory/override-cache.log"
grep -Fxq 'XWALK_RPI_SPI_DEVICE:FILEPATH=/dev/spidev2.1' "$test_directory/override-cache.log"
grep -Fxq 'XWALK_RPI_CAMERA:STRING=usb' "$test_directory/override-cache.log"
if grep -Fq 'XWALK_GSTREAMER_PLUGIN_DIRECTORY' "$override_build_directory/build.ninja"; then
    echo "The USB build unexpectedly configures the CSI GStreamer plugin path." >&2
    exit 1
fi

ninja -C "$build_directory" -n > "$test_directory/ordinary-build.log"
if grep -Eq 'setup-rpi(-local)?\.sh' "$test_directory/ordinary-build.log"; then
    echo "The ordinary build unexpectedly includes Raspberry Pi provisioning." >&2
    exit 1
fi

python3 -m json.tool "$repository_root/xWalk-rpi5-hw/CMakePresets.json" >/dev/null
grep -Fq '"name": "rpi-provision"' "$repository_root/xWalk-rpi5-hw/CMakePresets.json"

echo "RPi CMake provisioning target test passed"
