#!/usr/bin/env bash

set -eu

usage() {
    echo "Usage: $0 [--profile robot_hat_v4|robot_hat_v5] [--runtime-user USER]"
    echo "  [--gpio-device /dev/gpiochipN] [--i2c-device /dev/i2c-N]"
    echo "  [--spi-device /dev/spidevN.N] [--config FILE] [--camera csi|usb]"
    echo "  [--template-config FILE] [--template-fragments DIRECTORY]"
    echo "  [--with-vosk --vosk-library-source FILE --vosk-model-source DIRECTORY]"
    echo "  [--validate-ollama] [--check|--validate|--dry-run|--apply]"
    echo "Defaults: profile=$XWALK_DEFAULT_RPI_PROFILE, runtime-user=$XWALK_DEFAULT_RPI_RUNTIME_USER"
    echo "  gpio=$XWALK_DEFAULT_RPI_GPIO_DEVICE, i2c=$XWALK_DEFAULT_RPI_I2C_DEVICE"
    echo "  spi=$XWALK_DEFAULT_RPI_SPI_DEVICE, camera=$XWALK_DEFAULT_RPI_CAMERA, mode=dry-run"
}

script_directory="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
defaults_file="$script_directory/rpi-defaults.conf"
if [ ! -r "$defaults_file" ]; then
    echo "The Raspberry Pi defaults file was not found: $defaults_file" >&2
    exit 2
fi
# shellcheck source=rpi-defaults.conf
. "$defaults_file"

profile="$XWALK_DEFAULT_RPI_PROFILE"
runtime_user="$XWALK_DEFAULT_RPI_RUNTIME_USER"
gpio_device="$XWALK_DEFAULT_RPI_GPIO_DEVICE"
i2c_device="$XWALK_DEFAULT_RPI_I2C_DEVICE"
spi_device="$XWALK_DEFAULT_RPI_SPI_DEVICE"
config_file="/var/lib/xwalk/picar-x.conf"
template_config="/etc/xwalk/picar-x.conf"
template_fragments="/etc/xwalk/picar-x.d"
camera="$XWALK_DEFAULT_RPI_CAMERA"
with_vosk="false"
validate_ollama="false"
vosk_library_source=""
vosk_model_source=""
mode="dry-run"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --profile) profile="${2-}"; shift 2 ;;
        --runtime-user) runtime_user="${2-}"; shift 2 ;;
        --gpio-device) gpio_device="${2-}"; shift 2 ;;
        --i2c-device) i2c_device="${2-}"; shift 2 ;;
        --spi-device) spi_device="${2-}"; shift 2 ;;
        --config) config_file="${2-}"; shift 2 ;;
        --template-config) template_config="${2-}"; shift 2 ;;
        --template-fragments) template_fragments="${2-}"; shift 2 ;;
        --camera) camera="${2-}"; shift 2 ;;
        --with-vosk) with_vosk="true"; shift ;;
        --vosk-library-source) vosk_library_source="${2-}"; shift 2 ;;
        --vosk-model-source) vosk_model_source="${2-}"; shift 2 ;;
        --validate-ollama) validate_ollama="true"; shift ;;
        --check|--validate) mode="check"; shift ;;
        --dry-run) mode="dry-run"; shift ;;
        --apply) mode="apply"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

if [ "$profile" != "robot_hat_v4" ] && [ "$profile" != "robot_hat_v5" ]; then
    echo "--profile must be robot_hat_v4 or robot_hat_v5." >&2
    exit 2
fi
if [ -z "$runtime_user" ] || ! id "$runtime_user" >/dev/null 2>&1; then
    echo "--runtime-user must name an existing operating-system user." >&2
    exit 2
fi
if [ "$camera" != "csi" ] && [ "$camera" != "usb" ]; then
    echo "--camera must be csi or usb." >&2
    exit 2
fi
if [ -z "$template_config" ] || [ -z "$template_fragments" ]; then
    echo "Configuration template paths must not be empty." >&2
    exit 2
fi
if [ "$with_vosk" = "true" ] && \
    { [ -z "$vosk_library_source" ] || [ -z "$vosk_model_source" ]; }; then
    echo "--with-vosk requires repository-controlled library and model sources." >&2
    exit 2
fi

test_root="${XWALK_SETUP_TEST_ROOT-}"
if [ -n "$test_root" ] && [ "$mode" = "apply" ]; then
    echo "Apply mode is disabled when XWALK_SETUP_TEST_ROOT is set." >&2
    exit 2
fi
root_path() {
    printf '%s%s\n' "$test_root" "$1"
}

os_release="$(root_path /etc/os-release)"
if [ ! -r "$os_release" ]; then
    echo "Unable to identify the target operating system." >&2
    exit 2
fi
os_id="$(sed -n 's/^ID=//p' "$os_release" | tr -d '"' | head -n 1)"
case "$os_id" in
    debian|raspbian|ubuntu) ;;
    *) echo "Unsupported operating system: $os_id" >&2; exit 2 ;;
esac

model=""
model_path="$(root_path /proc/device-tree/model)"
if [ -r "$model_path" ]; then
    model="$(tr -d '\000' < "$model_path")"
fi
case "$model" in
    *"Raspberry Pi"*) ;;
    *) echo "This setup script must run on a Raspberry Pi." >&2; exit 2 ;;
esac

v5_uuid="9daeea78-0000-076e-0032-582369ac3e02"
v5_detected="false"
for uuid_file in "$(root_path /proc/device-tree)"/*hat*/uuid; do
    if [ -r "$uuid_file" ] && [ "$(tr -d '\000' < "$uuid_file")" = "$v5_uuid" ]; then
        v5_detected="true"
    fi
done
if [ "$profile" = "robot_hat_v4" ] && [ "$v5_detected" = "true" ]; then
    echo "The v4 profile conflicts with the detected Robot HAT v5 UUID." >&2
    exit 2
fi
if [ "$profile" = "robot_hat_v5" ] && [ "$v5_detected" != "true" ]; then
    echo "The v5 profile requires the supported Robot HAT v5 Device Tree UUID." >&2
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

boot_config=""
if [ -f "$(root_path /boot/firmware/config.txt)" ]; then
    boot_config="$(root_path /boot/firmware/config.txt)"
elif [ -f "$(root_path /boot/config.txt)" ]; then
    boot_config="$(root_path /boot/config.txt)"
else
    echo "No Raspberry Pi config.txt was found." >&2
    exit 2
fi

for setting in i2c_arm spi; do
    if grep -Eq "^[[:space:]]*dtparam=${setting}=off([[:space:]]|$)" "$boot_config"; then
        echo "Resolve the conflicting dtparam=${setting}=off in $boot_config first." >&2
        exit 2
    fi
done

required_packages=(
    build-essential cmake ninja-build pkg-config python3 python3-nacl linux-libc-dev
    libasound2-dev alsa-utils libatomic1 libcurl4-openssl-dev libjson-c-dev
    libsndfile1-dev libprotobuf-dev libgrpc++-dev libgtest-dev libtinyxml2-dev
    libyaml-cpp-dev libopencv-dev libboost-dev i2c-tools libi2c-dev gpiod
    espeak-ng libttspico-utils curl ca-certificates
)
if [ "$camera" = "csi" ]; then
    required_packages+=(
        gstreamer1.0-tools gstreamer1.0-plugins-base
        libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
    )
    runtime_home="$(getent passwd "$runtime_user" | awk -F: 'NR == 1 { print $6 }')"
    if [ ! -x "$runtime_home/.local/bin/rpicam-still" ]; then
        required_packages+=(rpicam-apps)
    fi
else
    required_packages+=(ffmpeg)
fi
missing_packages=()
for package in "${required_packages[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'ok installed'; then
        missing_packages+=("$package")
    fi
done

effective_config="$(root_path "$config_file")"
config_ready="true"
if [ ! -f "$effective_config" ]; then
    config_ready="false"
fi
effective_fragment_directory="$(dirname -- "$effective_config")/picar-x.d"
fragments_ready="true"
if [ ! -d "$effective_fragment_directory" ]; then
    fragments_ready="false"
fi
effective_template_config="$template_config"
effective_template_fragments="$template_fragments"
template_ready="true"
if [ ! -r "$effective_template_config" ] || [ ! -d "$effective_template_fragments" ]; then
    template_ready="false"
fi

canonical_config="$(realpath -m -- "$config_file")"
canonical_template_config="$(realpath -m -- "$template_config")"
canonical_fragment_destination="$(realpath -m -- "$(dirname -- "$config_file")/picar-x.d")"
canonical_template_fragments="$(realpath -m -- "$template_fragments")"
if [ "$canonical_config" = "$canonical_template_config" ] || \
    [ "$canonical_fragment_destination" = "$canonical_template_fragments" ]; then
    echo "Writable deployment paths must differ from repository or installed templates." >&2
    exit 2
fi

configuration_value() {
    configuration_values_from_file "$1" "$effective_config" 0 | tail -n 1
}

configuration_values_from_file() {
    local requested_key="$1"
    local source_file="$2"
    local include_depth="$3"
    if [ "$include_depth" -gt 8 ] || [ ! -r "$source_file" ]; then
        return
    fi
    while IFS="$(printf '\t')" read -r entry_type entry_value; do
        if [ "$entry_type" = "include" ]; then
            case "$entry_value" in
                /*|..|../*|*/../*) continue ;;
            esac
            configuration_values_from_file "$requested_key" \
                "$(dirname -- "$source_file")/$entry_value" "$((include_depth + 1))"
        elif [ "$entry_type" = "value" ]; then
            printf '%s\n' "$entry_value"
        fi
    done < <(awk -v key="$requested_key" '
        /^[[:space:]]*#/ { next }
        {
            separator=index($0, "=")
            if (separator == 0) { next }
            name=substr($0, 1, separator - 1)
            value=substr($0, separator + 1)
            sub(/^[[:space:]]*/, "", name)
            sub(/[[:space:]]*$/, "", name)
            sub(/^[[:space:]]*/, "", value)
            sub(/[[:space:]]*$/, "", value)
            if (name == "include") { print "include\t" value }
            else if (name == key) { print "value\t" value }
        }
    ' "$source_file")
}

rule_template="$script_directory/udev/99-xwalk-picarx.rules.in"
if [ ! -f "$rule_template" ]; then
    rule_template="$script_directory/../../share/xwalk/deployment/udev/99-xwalk-picarx.rules.in"
fi
if [ ! -f "$rule_template" ]; then
    echo "The xWalk udev rule template was not found." >&2
    exit 2
fi

echo "xWalk Raspberry Pi provisioning plan"
echo "  mode: $mode"
echo "  operating system: $os_id"
echo "  board: $model"
echo "  Robot HAT profile: $profile"
echo "  runtime user: $runtime_user"
echo "  writable configuration: $config_file"
if [ "$config_ready" != "true" ] || [ "$fragments_ready" != "true" ]; then
    if [ "$template_ready" = "true" ]; then
        echo "  configuration action: initialize the writable copy from $template_config"
        echo "  fragment action: initialize the writable copy from $template_fragments"
    else
        echo "  configuration action: templates are unavailable"
    fi
fi
echo "  SELECTED GPIO DEVICE: $gpio_device"
echo "  exact devices: I2C=$i2c_device, GPIO=$gpio_device, SPI=$spi_device"
if [ "${#missing_packages[@]}" -ne 0 ]; then
    echo "  install packages: ${missing_packages[*]}"
else
    echo "  packages: already installed"
fi
for setting in i2c_arm spi; do
    if grep -Eq "^[[:space:]]*dtparam=${setting}=on([[:space:]]|$)" "$boot_config"; then
        echo "  dtparam=$setting: already enabled"
    else
        echo "  append dtparam=$setting=on to $boot_config"
    fi
done
echo "  create xwalk, i2c, gpio, and spi groups when absent"
echo "  add $runtime_user to xwalk, i2c, gpio, spi, audio, video, and render when available"
echo "  install one udev rule for only the three selected device nodes"
echo "  Robot HAT overlays: no overlay will be installed or changed"
if [ "$with_vosk" = "true" ]; then
    if [ ! -r "$vosk_library_source" ] || [ ! -d "$vosk_model_source" ]; then
        echo "Vosk repository-controlled source assets are unavailable." >&2
        exit 2
    fi
    echo "  Vosk action: install repository assets under /usr/lib/xwalk and /usr/share/xwalk/models/vosk"
fi
if [ "$validate_ollama" = "true" ]; then
    runtime_home="$(getent passwd "$runtime_user" | awk -F: 'NR == 1 { print $6 }')"
    if [ "$config_ready" = "true" ]; then
        ollama_manifest="$(configuration_value voice_ollama_model_manifest)"
        if [ -x "$runtime_home/.local/bin/ollama" ] && [ -n "$ollama_manifest" ] && \
            [ -r "$ollama_manifest" ]; then
            echo "  Ollama validation: user-local executable and model manifest are available"
        else
            echo "  Ollama validation: setup-rpi-local.sh must install the executable and model"
        fi
    else
        echo "  Ollama validation: deferred until the writable configuration is initialized"
    fi
fi

if [ "$mode" = "check" ]; then
    required_failures=0
    if [ "${#missing_packages[@]}" -ne 0 ]; then
        echo "[FAIL] required packages: ${missing_packages[*]}"
        required_failures=$((required_failures + 1))
    fi
    for setting in i2c_arm spi; do
        if ! grep -Eq "^[[:space:]]*dtparam=${setting}=on([[:space:]]|$)" "$boot_config"; then
            echo "[FAIL] required interface: dtparam=$setting is not enabled"
            required_failures=$((required_failures + 1))
        fi
    done
    for device in "$gpio_device" "$i2c_device" "$spi_device"; do
        if [ ! -e "$(root_path "$device")" ]; then
            echo "[FAIL] required device: $device is unavailable"
            required_failures=$((required_failures + 1))
        fi
    done
    if { [ "$config_ready" != "true" ] || [ "$fragments_ready" != "true" ]; } && \
        [ "$template_ready" != "true" ]; then
        echo "[FAIL] required configuration: $config_file and its templates are unavailable"
        required_failures=$((required_failures + 1))
    fi
    if [ "$required_failures" -ne 0 ]; then
        echo "Validation failed with $required_failures required issue(s)."
        exit 1
    fi
    echo "Validation passed. Optional components are reported separately above."
    exit 0
fi

if [ "$mode" = "dry-run" ]; then
    echo "Dry run complete. Re-run with --apply to perform the listed privileged changes."
    exit 0
fi

if { [ "$config_ready" != "true" ] || [ "$fragments_ready" != "true" ]; } && \
    [ "$template_ready" != "true" ]; then
    echo "Apply mode requires readable configuration templates." >&2
    exit 2
fi

if [ "$(id -u)" -eq 0 ]; then
    root_command=""
elif command -v sudo >/dev/null 2>&1; then
    root_command="sudo"
else
    echo "Apply mode requires root privileges or sudo." >&2
    exit 2
fi

run_root() {
    if [ -n "$root_command" ]; then
        "$root_command" "$@"
    else
        "$@"
    fi
}

if [ "${#missing_packages[@]}" -ne 0 ]; then
    run_root apt-get update
    run_root apt-get install -y "${missing_packages[@]}"
fi

for setting in i2c_arm spi; do
    if ! grep -Eq "^[[:space:]]*dtparam=${setting}=on([[:space:]]|$)" "$boot_config"; then
        printf '\ndtparam=%s=on\n' "$setting" | run_root tee -a "$boot_config" >/dev/null
    fi
done

for group in xwalk i2c gpio spi; do
    if ! getent group "$group" >/dev/null 2>&1; then
        run_root groupadd --system "$group"
    fi
done
runtime_groups="xwalk,i2c,gpio,spi"
for group in audio video render; do
    if getent group "$group" >/dev/null 2>&1; then
        runtime_groups="$runtime_groups,$group"
    fi
done
run_root usermod -a -G "$runtime_groups" "$runtime_user"

config_directory="$(dirname -- "$config_file")"
run_root install -d -m 0770 -o root -g xwalk "$config_directory"
if [ ! -f "$config_file" ]; then
    run_root install -m 0660 -o root -g xwalk "$template_config" "$config_file"
fi
config_fragment_directory="$config_directory/picar-x.d"
if [ ! -d "$config_fragment_directory" ]; then
    run_root cp -a "$template_fragments" "$config_fragment_directory"
fi
run_root chown -R root:xwalk "$config_fragment_directory"
run_root find "$config_fragment_directory" -type d -exec chmod 0750 {} +
run_root find "$config_fragment_directory" -type f -name '*.conf' -exec chmod 0640 {} +
if [ -f "$config_file" ]; then
    run_root chown root:xwalk "$config_file"
    run_root chmod 0660 "$config_file"
else
    echo "Install the default configuration at $config_file before running the application." >&2
    exit 2
fi

set_runtime_configuration_value() {
    local target_file="$1"
    local requested_key="$2"
    local replacement_value="$3"
    local temporary_configuration
    temporary_configuration="$(mktemp)"
    # shellcheck disable=SC2016  # The AWK program intentionally owns dollar expressions.
    run_root awk -v key="$requested_key" -v value="$replacement_value" '
        BEGIN { replaced = 0 }
        {
            separator = index($0, "=")
            name = separator == 0 ? "" : substr($0, 1, separator - 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
            if (name == key) {
                print key " = " value
                replaced = 1
            } else {
                print
            }
        }
        END { if (replaced == 0) print key " = " value }
    ' "$target_file" > "$temporary_configuration"
    run_root install -m 0640 -o root -g xwalk "$temporary_configuration" "$target_file"
    rm -f "$temporary_configuration"
}

if [ "$with_vosk" = "true" ]; then
    vosk_library_destination="/usr/lib/xwalk/libvosk.so"
    vosk_model_destination="/usr/share/xwalk/models/vosk/vosk-model-small-en-us-0.15"
    run_root install -d -m 0755 -o root -g root "$(dirname -- "$vosk_library_destination")"
    run_root install -m 0644 -o root -g root "$vosk_library_source" "$vosk_library_destination"
    run_root install -d -m 0755 -o root -g root "$vosk_model_destination"
    run_root cp -a "$vosk_model_source/." "$vosk_model_destination/"
    run_root chown -R root:root "$vosk_model_destination"
    run_root find "$vosk_model_destination" -type d -exec chmod 0755 {} +
    run_root find "$vosk_model_destination" -type f -exec chmod 0644 {} +
    set_runtime_configuration_value "$config_fragment_directory/voice.conf" \
        voice_vosk_library "$vosk_library_destination"
    set_runtime_configuration_value "$config_fragment_directory/voice.conf" \
        voice_vosk_model "$vosk_model_destination"
fi

temporary_rule="$(mktemp)"
trap 'rm -f "$temporary_rule"' EXIT
sed -e "s/@I2C_KERNEL@/$(basename "$i2c_device")/g" \
    -e "s/@GPIO_KERNEL@/$(basename "$gpio_device")/g" \
    -e "s/@SPI_KERNEL@/$(basename "$spi_device")/g" \
    "$rule_template" > "$temporary_rule"
run_root install -m 0644 -o root -g root "$temporary_rule" /etc/udev/rules.d/99-xwalk-picarx.rules
run_root udevadm control --reload-rules
run_root udevadm trigger --subsystem-match=i2c-dev
run_root udevadm trigger --subsystem-match=gpio
run_root udevadm trigger --subsystem-match=spidev

provision_script="$script_directory/provision-hardware.sh"
if [ -x "$provision_script" ] && [ -e "$gpio_device" ]; then
    run_root "$provision_script" --profile "$profile" --config "$config_file" \
        --gpio-device "$gpio_device" --i2c-device "$i2c_device" --spi-device "$spi_device"
else
    echo "GPIO identity provisioning is deferred until $gpio_device is available."
fi

echo "Provisioning complete. Reboot if an interface was enabled, then log out and back in."
echo "Run build-rpi/cmake/xWalkController/xWalkApp/xwalk-picarx-control doctor before actuator calibration."
