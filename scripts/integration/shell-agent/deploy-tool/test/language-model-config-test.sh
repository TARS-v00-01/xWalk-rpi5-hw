#!/usr/bin/env bash

set -eu

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repository_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
configuration_file="$repository_root/xWalk-rpi5-hw/xWalkController/xWalkConfig/picar-x.conf"
configuration_directory="$repository_root/xWalk-rpi5-hw/xWalkController/xWalkConfig/picar-x.d"
ollama_file="$configuration_directory/ai/providers/ollama.conf"

test -r "$configuration_file"
test -r "$configuration_directory/voice.conf"
test -r "$configuration_directory/ai/providers/openai.conf"
test -r "$configuration_directory/ai/providers/gemini.conf"
test -r "$configuration_directory/ai/providers/grok.conf"
test -r "$configuration_directory/ai/providers/anthropic.conf"
test -r "$configuration_directory/ai/providers/openai-compatible.conf"
test -r "$repository_root/xWalk-rpi5-hw/xWalkLibrary/x86_64/lib/libvosk.so"
test -r "$repository_root/xWalk-rpi5-hw/xWalkLibrary/aarch64/lib/libvosk.so"
test -d \
    "$repository_root/xWalk-rpi5-hw/xWalkLibrary/common/models/vosk/vosk-model-small-en-us-0.15"
grep -q '^voice_vosk_library = /usr/lib/xwalk/libvosk.so$' \
    "$configuration_directory/voice.conf"
grep -q '^voice_vosk_model = /usr/share/xwalk/models/vosk/vosk-model-small-en-us-0.15$' \
    "$configuration_directory/voice.conf"
grep -q '^include = picar-x.d/ai/providers/ollama.conf$' "$configuration_file"
grep -q '^voice_language_model_provider = ollama$' "$ollama_file"
grep -q '^voice_language_model_endpoint = http://127.0.0.1:11434/api/chat$' \
    "$ollama_file"
grep -q '^voice_language_model_model_environment = OLLAMA_MODEL$' "$ollama_file"
grep -q '^voice_language_model_api_key_environment =$' "$ollama_file"
grep -q '^voice_language_model_maximum_output_tokens = 1024$' \
    "$ollama_file"

grep -q '^voice_language_model_api_key_environment = OPENAI_API_KEY$' \
    "$configuration_directory/ai/providers/openai.conf"
grep -q '^voice_language_model_model_environment = OPENAI_MODEL$' \
    "$configuration_directory/ai/providers/openai.conf"
grep -q '^voice_language_model_api_key_environment = GEMINI_API_KEY$' \
    "$configuration_directory/ai/providers/gemini.conf"
grep -q '^voice_language_model_model_environment = GEMINI_MODEL$' \
    "$configuration_directory/ai/providers/gemini.conf"
grep -q '^voice_language_model_provider = grok$' \
    "$configuration_directory/ai/providers/grok.conf"
grep -q '^voice_language_model_endpoint = https://api.x.ai/v1/chat/completions$' \
    "$configuration_directory/ai/providers/grok.conf"
grep -q '^voice_language_model_api_key_environment = XAI_API_KEY$' \
    "$configuration_directory/ai/providers/grok.conf"
grep -q '^voice_language_model_model_environment = XAI_MODEL$' \
    "$configuration_directory/ai/providers/grok.conf"
grep -q '^voice_language_model_api_key_environment = ANTHROPIC_API_KEY$' \
    "$configuration_directory/ai/providers/anthropic.conf"
grep -q '^voice_language_model_model_environment = ANTHROPIC_MODEL$' \
    "$configuration_directory/ai/providers/anthropic.conf"
grep -q '^voice_language_model_api_key_environment = XWALK_AI_API_KEY$' \
    "$configuration_directory/ai/providers/openai-compatible.conf"
grep -q '^voice_language_model_model_environment = XWALK_AI_MODEL$' \
    "$configuration_directory/ai/providers/openai-compatible.conf"

if grep -ERq '^voice_language_model_api_key[[:space:]]*=' "$configuration_directory/ai/providers"; then
    echo "Tracked language-model configuration contains a direct credential field." >&2
    exit 1
fi
if grep -ERq '^voice_language_model_model[[:space:]]*=' "$configuration_directory/ai/providers"; then
    echo "Tracked language-model configuration contains a direct model field." >&2
    exit 1
fi

service_environment="$repository_root/scripts/integration/shell-agent/deploy-tool/systemd/xwalk-service.conf"
ollama_service="$repository_root/scripts/integration/shell-agent/deploy-tool/systemd/ollama.service"
jarvis_service="$repository_root/scripts/integration/shell-agent/deploy-tool/systemd/xwalk-jarvis.service"
grep -Fq 'ExecStart=%h/.local/bin/ollama serve' "$ollama_service"
grep -Fq 'Environment="OLLAMA_HOST=127.0.0.1:11434"' "$ollama_service"
grep -Fq 'Restart=on-failure' "$ollama_service"
grep -Fq 'Requires=ollama.service' "$jarvis_service"
grep -Fq 'After=ollama.service sound.target' "$jarvis_service"
grep -Fq 'voice-active-car-gpt start' "$jarvis_service"
if grep -Eq '^(OPENAI|GEMINI|XAI|ANTHROPIC|XWALK_AI|OLLAMA)_(API_KEY|MODEL)=' \
    "$service_environment"; then
    echo "Tracked service configuration bypasses the encrypted licence loader." >&2
    exit 1
fi

echo "Language-model configuration template tests passed."
