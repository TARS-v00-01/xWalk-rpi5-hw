#!/usr/bin/env bash

set -Eeuo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repository_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
service_path="scripts/integration/py-agent/gerrit-tool/py-src/xWalkGerritCi.py"
helper_path="scripts/integration/py-agent/gerrit-tool/shell-script/gerrit-github-sync.sh"
validator_path="scripts/integration/shell-agent/gerrit-tool/validate-publication-policy.sh"

direct_shell_pushes="$(
    git -C "$repository_root" grep -n -E \
        'git[[:space:]]+(-C[[:space:]]+[^[:space:]]+[[:space:]]+)?push[[:space:]]+([^[:space:]]*github\.com|github)([[:space:]]|$)' \
        -- '*.sh' '*.yml' '*.yaml' \
        ":!$helper_path" ":!$validator_path" || true
)"
direct_python_pushes="$(
    git -C "$repository_root" grep -n -E \
        '["'\''"]git["'\''"][[:space:]]*,[[:space:]]*["'\''"]push["'\''"][[:space:]]*,[[:space:]]*["'\''"]github["'\''"]' \
        -- '*.py' ":!$service_path" ":!$validator_path" || true
)"
workflow_pushes="$(
    git -C "$repository_root" grep -n -E 'git[[:space:]]+push' \
        -- '.github/workflows/*.yml' '.github/workflows/*.yaml' || true
)"

if [[ -n "$direct_shell_pushes" || -n "$direct_python_pushes" || -n "$workflow_pushes" ]]
then
    printf 'Direct GitHub publication is prohibited; upload source changes only through Gerrit.\n' >&2
    printf '%s\n%s\n%s\n' "$direct_shell_pushes" "$direct_python_pushes" "$workflow_pushes" >&2
    exit 1
fi

if [[ -e "$repository_root/$service_path" || -e "$repository_root/$helper_path" ]]
then
    [[ -e "$repository_root/$service_path" && -e "$repository_root/$helper_path" ]] || {
        echo "Guarded GitHub synchronization service and helper must be present together" >&2
        exit 1
    }
    git -C "$repository_root" grep -q -E \
        '["'\''"]git["'\''"][[:space:]]*,[[:space:]]*["'\''"]push["'\''"][[:space:]]*,[[:space:]]*["'\''"]github["'\''"]' \
        -- "$service_path"
    # shellcheck disable=SC2016  # Match the helper's literal $work variable.
    git -C "$repository_root" grep -q -E \
        'git[[:space:]]+-C[[:space:]]+"\$work"[[:space:]]+push[[:space:]]+github' \
        -- "$helper_path"
fi

printf 'Validated Gerrit-only source publication and guarded GitHub uplift paths\n'
