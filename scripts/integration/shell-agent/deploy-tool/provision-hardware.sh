#!/usr/bin/env bash

set -eu

usage() {
    echo "Usage: $0 --profile robot_hat_v4|robot_hat_v5 --config FILE [device options]"
    echo "  [--gpio-device /dev/gpiochipN] [--i2c-device /dev/i2c-N]"
    echo "  [--spi-device /dev/spidevN.N]"
}

profile=""
config_file=""
gpio_device=""
i2c_device=""
spi_device=""
while [ "$#" -gt 0 ]; do
    case "$1" in
        --profile) profile="${2-}"; shift 2 ;;
        --config) config_file="${2-}"; shift 2 ;;
        --gpio-device) gpio_device="${2-}"; shift 2 ;;
        --i2c-device) i2c_device="${2-}"; shift 2 ;;
        --spi-device) spi_device="${2-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) usage; exit 2 ;;
    esac
done

if [ "$profile" != "robot_hat_v4" ] && [ "$profile" != "robot_hat_v5" ]; then
    echo "An explicit robot_hat_v4 or robot_hat_v5 profile is required." >&2
    exit 2
fi
if [ -z "$config_file" ] || [ ! -f "$config_file" ]; then
    echo "An existing writable configuration file is required." >&2
    exit 2
fi
if [ ! -w "$config_file" ]; then
    echo "Configuration file is not writable: $config_file" >&2
    exit 2
fi
if [ -n "$i2c_device" ] && ! printf '%s\n' "$i2c_device" | grep -Eq '^/dev/i2c-[0-9]+$'; then
    echo "Invalid I2C device path: $i2c_device" >&2
    exit 2
fi
if [ -n "$spi_device" ] && \
    ! printf '%s\n' "$spi_device" | grep -Eq '^/dev/spidev[0-9]+\.[0-9]+$'; then
    echo "Invalid SPI device path: $spi_device" >&2
    exit 2
fi
if ! command -v gpiodetect >/dev/null 2>&1; then
    echo "gpiodetect is required to provision an exact GPIO identity." >&2
    exit 2
fi

config_owner="$(stat -c '%u' "$config_file")"
current_user="$(id -u)"
if [ "$current_user" -ne 0 ] && [ "$current_user" -ne "$config_owner" ]; then
    echo "Configuration replacement must run as root or the file owner: $config_file" >&2
    exit 2
fi

test_root="${XWALK_PROVISION_TEST_ROOT-}"
root_path() {
    printf '%s%s\n' "$test_root" "$1"
}

v5_uuid="9daeea78-0000-076e-0032-582369ac3e02"
v5_detected="false"
for uuid_file in "$(root_path /proc/device-tree)"/*hat*/uuid; do
    if [ -r "$uuid_file" ] && [ "$(tr -d '\000' < "$uuid_file")" = "$v5_uuid" ]; then
        v5_detected="true"
    fi
done
if [ "$profile" = "robot_hat_v4" ] && [ "$v5_detected" = "true" ]; then
    echo "Robot HAT v4 conflicts with the detected Robot HAT v5 overlay." >&2
    exit 2
fi
if [ "$profile" = "robot_hat_v5" ] && [ "$v5_detected" != "true" ]; then
    echo "Robot HAT v5 profile requires the supported Device Tree UUID." >&2
    exit 2
fi

if [ -z "$gpio_device" ]; then
    candidate_count=0
    for candidate in "$(root_path /dev)"/gpiochip*; do
        if [ -e "$candidate" ]; then
            gpio_device="/${candidate#"$test_root/"}"
            candidate_count=$((candidate_count + 1))
        fi
    done
    if [ "$candidate_count" -ne 1 ]; then
        echo "Select one GPIO controller explicitly with --gpio-device." >&2
        exit 2
    fi
fi
if ! printf '%s\n' "$gpio_device" | grep -Eq '^/dev/gpiochip[0-9]+$'; then
    echo "Invalid GPIO device path: $gpio_device" >&2
    exit 2
fi
gpio_basename="$(basename "$gpio_device")"
gpio_line="$(gpiodetect | awk -v chip="$gpio_basename" '$1 == chip { print; exit }')"
if [ -z "$gpio_line" ]; then
    echo "GPIO device was not reported by gpiodetect: $gpio_device" >&2
    exit 2
fi
gpio_name="$(printf '%s\n' "$gpio_line" | awk '{ print $1 }')"
gpio_label="$(printf '%s\n' "$gpio_line" | sed -n 's/^[^[]*\[\([^]]*\)\].*$/\1/p')"
gpio_lines="$(printf '%s\n' "$gpio_line" | sed -n 's/.*(\([0-9][0-9]*\) lines).*/\1/p')"
if [ -z "$gpio_label" ] || [ -z "$gpio_lines" ] || [ "$gpio_lines" -lt 28 ]; then
    echo "Selected GPIO chip lacks a usable label or the required 28 lines." >&2
    exit 2
fi

temporary_file="$(mktemp "${config_file}.tmp.XXXXXX")"
trap 'rm -f "$temporary_file"' EXIT
awk -v board="$profile" -v device="$gpio_device" -v name="$gpio_name" -v label="$gpio_label" \
    -v i2c="$i2c_device" -v spi="$spi_device" '
BEGIN {
    board_seen=0; device_seen=0; name_seen=0; label_seen=0
    i2c_seen=0; spi_seen=0
}
/^[[:space:]]*hardware_board[[:space:]]*=/ {
    print "hardware_board = " board; board_seen=1; next
}
/^[[:space:]]*hardware_gpio_device[[:space:]]*=/ {
    print "hardware_gpio_device = " device; device_seen=1; next
}
/^[[:space:]]*hardware_gpio_chip_name[[:space:]]*=/ {
    print "hardware_gpio_chip_name = " name; name_seen=1; next
}
/^[[:space:]]*hardware_gpio_chip_label[[:space:]]*=/ {
    print "hardware_gpio_chip_label = " label; label_seen=1; next
}
/^[[:space:]]*hardware_i2c_device[[:space:]]*=/ {
    if (i2c != "") print "hardware_i2c_device = " i2c
    else print
    i2c_seen=1; next
}
/^[[:space:]]*hardware_spi_device[[:space:]]*=/ {
    if (spi != "") print "hardware_spi_device = " spi
    else print
    spi_seen=1; next
}
{ print }
END {
    if (!board_seen) print "hardware_board = " board
    if (!device_seen) print "hardware_gpio_device = " device
    if (!name_seen) print "hardware_gpio_chip_name = " name
    if (!label_seen) print "hardware_gpio_chip_label = " label
    if (!i2c_seen && i2c != "") print "hardware_i2c_device = " i2c
    if (!spi_seen && spi != "") print "hardware_spi_device = " spi
}' "$config_file" > "$temporary_file"
if [ "$current_user" -eq 0 ]; then
    chown --reference="$config_file" "$temporary_file"
else
    chgrp --reference="$config_file" "$temporary_file"
fi
chmod --reference="$config_file" "$temporary_file"
mv "$temporary_file" "$config_file"
trap - EXIT

echo "Provisioned $profile with $gpio_device, name=$gpio_name, label=$gpio_label, lines=$gpio_lines."
echo "Run build-rpi/cmake/xWalkController/xWalkApp/xwalk-picarx-control doctor before actuator calibration."
