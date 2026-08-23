#!/usr/bin/env bash

set -eu

usage() {
    echo "Usage: $0 [--build-directory DIRECTORY] [--runtime-user USER]"
    echo "  [--local-prefix DIRECTORY] [--ollama-manifest FILE] [--generate-only]"
}

script_directory="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
# shellcheck source=rpi-defaults.conf
. "$script_directory/rpi-defaults.conf"
workspace_root="$(git -C "$script_directory" rev-parse --show-toplevel)"
build_directory="$workspace_root/build-rpi"
runtime_user="$XWALK_DEFAULT_RPI_RUNTIME_USER"
local_prefix=""
ollama_manifest=""
generate_only="false"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --build-directory) build_directory="${2-}"; shift 2 ;;
        --runtime-user) runtime_user="${2-}"; shift 2 ;;
        --local-prefix) local_prefix="${2-}"; shift 2 ;;
        --ollama-manifest) ollama_manifest="${2-}"; shift 2 ;;
        --generate-only) generate_only="true"; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
done

runtime_home="$(getent passwd "$runtime_user" | awk -F: 'NR == 1 { print $6 }')"
if [ -z "$runtime_home" ] || [ ! -d "$runtime_home" ]; then
    echo "Unable to resolve the runtime home for $runtime_user." >&2
    exit 2
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

models_directory="$local_prefix/share/ollama/models"
if [ -z "$ollama_manifest" ] && [ -d "$models_directory/manifests" ]; then
    ollama_manifest="$(find "$models_directory/manifests" -type f \
        -path '*/registry.ollama.ai/library/llama3.2/3b' -print -quit)"
fi
if [ -z "$ollama_manifest" ]; then
    ollama_manifest="$models_directory/manifests/registry.ollama.ai/library/llama3.2/3b"
fi
case "$ollama_manifest" in
    /*) ;;
    *) echo "--ollama-manifest must be an absolute path." >&2; exit 2 ;;
esac

if [ "$generate_only" != "true" ] && [ ! -r "$ollama_manifest" ]; then
    echo "The llama3.2:3b manifest is not readable: $ollama_manifest" >&2
    echo "Run setup-rpi-local.sh --apply before configuring the runtime." >&2
    exit 1
fi

"$script_directory/generate-rpi-runtime.sh" \
    --build-directory "$build_directory" \
    --runtime-user "$runtime_user" \
    --local-prefix "$local_prefix" \
    --ollama-manifest "$ollama_manifest"

if [ "$generate_only" = "true" ]; then
    exit 0
fi

configuration_value() {
    local key="$1"
    awk -F= -v requested_key="$key" '
        {
            name = $1
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
            if (name == requested_key) {
                value = substr($0, index($0, "=") + 1)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
                print value
                exit
            }
        }
    ' "$build_directory/runtime/picar-x.d/voice.conf"
}

vosk_library="$(configuration_value voice_vosk_library)"
vosk_model="$(configuration_value voice_vosk_model)"
capture_device="$(configuration_value voice_capture_device)"
mixer_device="$(configuration_value voice_mixer_device)"
mixer_element="$(configuration_value voice_mixer_element)"
piper_executable="$(configuration_value voice_piper_executable)"
piper_playback_executable="$(configuration_value voice_piper_playback_executable)"
piper_model="$build_directory/runtime/picar-x.d/ai/features.conf"
piper_model="$(awk -F= '$1 ~ /^[[:space:]]*voice_active_car_gpt_piper_model[[:space:]]*$/ {
    value = substr($0, index($0, "=") + 1)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
    print value
    exit
}' "$piper_model")"

test -r "$vosk_library"
test -d "$vosk_model" && test -r "$vosk_model"
test -x "$piper_executable"
test -r "$piper_model" && test -r "$piper_model.json"
command -v "$piper_playback_executable" >/dev/null
command -v arecord >/dev/null
command -v amixer >/dev/null
arecord -D "$capture_device" --dump-hw-params -d 1 -f S16_LE -r 16000 -c 1 /dev/null >/dev/null 2>&1
amixer -D "$mixer_device" scontrols | grep -Fq "'$mixer_element'"

ollama_executable="$local_prefix/bin/ollama"
if [ ! -x "$ollama_executable" ]; then
    echo "The user-local Ollama executable is missing: $ollama_executable" >&2
    exit 1
fi

systemctl --user daemon-reload
systemctl --user enable --now ollama.service
systemctl --user --no-pager status ollama.service
curl --fail --silent --show-error http://127.0.0.1:11434/api/tags >/dev/null
OLLAMA_HOST=127.0.0.1:11434 "$ollama_executable" list | grep -Fq 'llama3.2:3b'

echo "Runtime configuration and the Ollama user service are ready."
echo "Validate with: $build_directory/xwalk --validate-config"
echo "Run Doctor with: $build_directory/xwalk doctor"
