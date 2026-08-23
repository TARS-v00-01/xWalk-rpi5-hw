#!/usr/bin/env bash

set -Eeuo pipefail

if [[ "${GITHUB_ACTIONS:-}" != "true" ]]; then
    echo "This package installer is restricted to GitHub Actions runners" >&2
    exit 2
fi

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 PACKAGE [PACKAGE ...]" >&2
    exit 2
fi

readonly ubuntu_archive="https://archive.ubuntu.com/ubuntu"
readonly apt_mirror_list="/etc/apt/apt-mirrors.txt"
readonly ubuntu_sources="/etc/apt/sources.list.d/ubuntu.sources"
readonly legacy_sources="/etc/apt/sources.list"

if sudo test -f "$apt_mirror_list"; then
    printf '%s\n' "$ubuntu_archive" | sudo tee "$apt_mirror_list" >/dev/null
fi

for source_file in "$ubuntu_sources" "$legacy_sources"; do
    if sudo test -f "$source_file"; then
        sudo sed -i \
            -e "s|http://azure.archive.ubuntu.com/ubuntu|$ubuntu_archive|g" \
            -e "s|https://azure.archive.ubuntu.com/ubuntu|$ubuntu_archive|g" \
            "$source_file"
    fi
done

sudo apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install --yes "$@"
