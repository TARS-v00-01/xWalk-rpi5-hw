#!/usr/bin/env bash

set -eu

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repository_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
fixture_root="$(mktemp -d)"
trap 'rm -rf "$fixture_root"' EXIT

mkdir -p "$fixture_root/xWalk-rpi5-hw/xWalkLibrary" "$fixture_root/scripts/integration/py-agent/dev-tool" \
    "$fixture_root/scripts/integration/shell-agent/env-tool/license"
cp "$repository_root/scripts/integration/py-agent/dev-tool/xWalkLicenseTool" \
    "$fixture_root/scripts/integration/py-agent/dev-tool/xWalkLicenseTool"
cp "$repository_root/scripts/integration/shell-agent/env-tool/license/xWalkEnv.sh" \
    "$fixture_root/scripts/integration/shell-agent/env-tool/license/xWalkEnv.sh"
cp "$repository_root/scripts/integration/shell-agent/env-tool/license/xWalkLicense.cfg" \
    "$fixture_root/scripts/integration/shell-agent/env-tool/license/xWalkLicense.cfg"

fixture_config="$fixture_root/private-license.cfg"
cat > "$fixture_config" <<'EOF'
[models]
ANTHROPIC_MODEL = claude-fake-model
GEMINI_MODEL = gemini-fake-model
OLLAMA_MODEL = ollama-fake-model
OPENAI_MODEL = openai-fake-model
XWALK_AI_MODEL = $(touch should-not-run)
EOF
chmod 0600 "$fixture_config"

fixture_netrc="$fixture_root/fake.netrc"
cat > "$fixture_netrc" <<'EOF'
machine api.anthropic.com login "" password anthropic-fake-value
machine api.deepseek.com login "" password deepseek-fake-value
machine ark.cn-beijing.volces.com login "" password doubao-fake-value
machine generativelanguage.googleapis.com login "" password gemini-fake-value
machine api.x.ai login "" password xai-fake-value
machine api.openai.com login "" password openai-fake-value
machine dashscope-intl.aliyuncs.com login "" password qwen-fake-value
EOF
chmod 0600 "$fixture_netrc"

encryption_output="$(
    python3 "$fixture_root/scripts/integration/py-agent/dev-tool/xWalkLicenseTool" encrypt \
        --config "$fixture_config"
)"
decryption_key="$(
    printf '%s\n' "$encryption_output" | sed -n '/^Decryption key:$/ {n;p;}'
)"
test -n "$decryption_key"
license_file="$fixture_root/xWalk-rpi5-hw/xWalkLibrary/X_WALK_LICENSE.KEY"
test "$(stat -c '%a' "$license_file")" = 600

decrypted_fixture="$fixture_root/decrypted-models.json"
printf '%s\n' "$decryption_key" | python3 \
    "$fixture_root/scripts/integration/py-agent/dev-tool/xWalkLicenseTool" decrypt \
    --output "$decrypted_fixture" > /dev/null 2>&1
python3 -c 'import json, sys
with open(sys.argv[1], encoding="utf-8") as input_file:
    values = json.load(input_file)
if any(name.endswith("_API_KEY") for name in values):
    raise SystemExit("encrypted licence retained an API credential")' \
    "$decrypted_fixture"
rm -f "$decrypted_fixture"

printf '%s\n' "$decryption_key" | XWALK_NETRC_FILE="$fixture_netrc" \
    PYTHONWARNINGS=ignore bash -c '
    source "$1"
    test "$OPENAI_API_KEY" = openai-fake-value
    test "$OPENAI_MODEL" = openai-fake-model
    test "$GEMINI_API_KEY" = gemini-fake-value
    test "$GEMINI_MODEL" = gemini-fake-model
    test "$ANTHROPIC_API_KEY" = anthropic-fake-value
    test "$ANTHROPIC_MODEL" = claude-fake-model
    test "$DEEPSEEK_API_KEY" = deepseek-fake-value
    test "$DOUBAO_API_KEY" = doubao-fake-value
    test "$GROK_API_KEY" = xai-fake-value
    test "$QWEN_API_KEY" = qwen-fake-value
    test "$XAI_API_KEY" = xai-fake-value
    test -z "${LLM_API_KEY+x}"
    test -z "${OTHERS_API_KEY+x}"
    test -z "${XWALK_AI_API_KEY+x}"
    test "$XWALK_AI_MODEL" = "\$(touch should-not-run)"
    test "$OLLAMA_MODEL" = ollama-fake-model
    test -z "${X_WALK_LICENSE_SERIAL+x}"
' _ "$fixture_root/scripts/integration/shell-agent/env-tool/license/xWalkEnv.sh" 2> "$fixture_root/loader.err"
if grep -q 'fake-value' "$fixture_root/loader.err"; then
    echo "xWalkEnv.sh exposed a fake credential in diagnostics." >&2
    exit 1
fi
test ! -e "$fixture_root/should-not-run"

chmod 0644 "$fixture_netrc"
if printf '%s\n' "$decryption_key" | XWALK_NETRC_FILE="$fixture_netrc" \
    PYTHONWARNINGS=ignore bash -c 'source "$1"' _ \
    "$fixture_root/scripts/integration/shell-agent/env-tool/license/xWalkEnv.sh" > /dev/null 2>&1; then
    echo "xWalkEnv.sh accepted a group/world-readable netrc file." >&2
    exit 1
fi
chmod 0600 "$fixture_netrc"

incomplete_netrc="$fixture_root/incomplete.netrc"
grep -v '^machine api.openai.com ' "$fixture_netrc" > "$incomplete_netrc"
chmod 0600 "$incomplete_netrc"
printf '%s\n' "$decryption_key" | XWALK_NETRC_FILE="$incomplete_netrc" \
    PYTHONWARNINGS=ignore bash -c '
    unset OPENAI_API_KEY
    source "$1"
    test -z "${OPENAI_API_KEY-}"
    test "$GEMINI_API_KEY" = gemini-fake-value
' _ "$fixture_root/scripts/integration/shell-agent/env-tool/license/xWalkEnv.sh" > /dev/null 2>&1

empty_netrc="$fixture_root/empty-password.netrc"
sed 's/password openai-fake-value/password ""/' "$fixture_netrc" > "$empty_netrc"
chmod 0600 "$empty_netrc"
printf '%s\n' "$decryption_key" | XWALK_NETRC_FILE="$empty_netrc" \
    PYTHONWARNINGS=ignore bash -c '
    unset OPENAI_API_KEY
    source "$1"
    test -z "${OPENAI_API_KEY-}"
    test "$ANTHROPIC_API_KEY" = anthropic-fake-value
' _ "$fixture_root/scripts/integration/shell-agent/env-tool/license/xWalkEnv.sh" > /dev/null 2>&1

chmod 0644 "$license_file"
if printf '%s\n' "$decryption_key" | XWALK_NETRC_FILE="$fixture_netrc" \
    PYTHONWARNINGS=ignore \
    bash -c 'source "$1"' _ "$fixture_root/scripts/integration/shell-agent/env-tool/license/xWalkEnv.sh" \
    > /dev/null 2>&1; then
    echo "xWalkEnv.sh accepted a group/world-readable encrypted licence." >&2
    exit 1
fi
chmod 0600 "$license_file"

incomplete_output="$(
    python3 "$fixture_root/scripts/integration/py-agent/dev-tool/xWalkLicenseTool" encrypt \
        --env OPENAI_MODEL=incomplete-fake-value
)"
incomplete_key="$(
    printf '%s\n' "$incomplete_output" | sed -n '/^Decryption key:$/ {n;p;}'
)"
printf '%s\n' "$incomplete_key" | XWALK_NETRC_FILE="$fixture_netrc" \
    PYTHONWARNINGS=ignore bash -c '
    export OPENAI_API_KEY=original-value
    if source "$1" > /dev/null 2>&1; then
        exit 1
    fi
    test "$OPENAI_API_KEY" = original-value
' _ "$fixture_root/scripts/integration/shell-agent/env-tool/license/xWalkEnv.sh"

if "$fixture_root/scripts/integration/shell-agent/env-tool/license/xWalkEnv.sh" > /dev/null 2>&1; then
    echo "Executing xWalkEnv.sh did not require sourcing." >&2
    exit 1
fi

echo "xWalk environment-loader host tests passed."
