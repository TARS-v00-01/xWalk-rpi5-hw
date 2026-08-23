#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
root="$(git -C "$script_dir" rev-parse --show-toplevel)"
"$root/scripts/integration/shell-agent/gerrit-tool/validate-publication-policy.sh"
components=(
    xWalkAgent xWalkAudioResources xWalkController xWalkHal xWalk-rpi5-iw xWalkLibrary
    DevloperNote xWalkTrace
)

[[ -f "$root/.gitmodules" ]] || {
    echo "Missing .gitmodules in the integrated repository" >&2
    exit 1
}

integrated_path()
{
    case "$1" in
        DevloperNote) printf '%s\n' "devloper-note" ;;
        xWalk-rpi5-iw) printf '%s\n' "xWalk-rpi5-iw" ;;
        *) printf 'xWalk-rpi5-hw/%s\n' "$1" ;;
    esac
}

validate_integrated_sources()
{
    local component path
    for component in "${components[@]}"; do
        path="$(integrated_path "$component")"
        [[ -d "$root/$path" && ! -L "$root/$path" ]] || {
            echo "Missing integrated source directory for $component" >&2
            exit 1
        }
        git -C "$root" ls-files --error-unmatch "$path" >/dev/null || {
            echo "Integrated source is not tracked for $component" >&2
            exit 1
        }
    done
    [[ "$({ git -C "$root" config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null || true; } | wc -l)" -eq 0 ]]
    echo "Validated eight integrated module source trees"
}

validate_hierarchical_migration()
{
    local component config_name expected_path expected_url expected_branch path url branch
    local nested="$root/xWalk-rpi5-hw/.gitmodules"
    local -A expected_top=(
        [xWalk-rpi5-tool]=1
        [xWalk-rpi5-hw]=1
        [xWalk-rpi5-iw]=1
        [devloper-note]=DevloperNote
    )
    [[ -f "$nested" ]] || {
        echo "Missing nested xWalk-rpi5-hw/.gitmodules" >&2
        exit 1
    }
    for component in "${!expected_top[@]}"; do
        path="$(git -C "$root" config -f .gitmodules --get "submodule.$component.path")"
        url="$(git -C "$root" config -f .gitmodules --get "submodule.$component.url")"
        branch="$(git -C "$root" config -f .gitmodules --get "submodule.$component.branch")"
        [[ "$path" == "$component" ]] || { echo "Invalid path for $component" >&2; exit 1; }
        expected_url="${expected_top[$component]}"
        [[ "$expected_url" != 1 ]] || expected_url="$component"
        [[ "$url" == ../"$expected_url" ]] || { echo "Invalid relative URL for $component" >&2; exit 1; }
        expected_branch=master
        [[ "$branch" == "$expected_branch" ]] || { echo "Invalid branch for $component" >&2; exit 1; }
    done
    while IFS= read -r path; do
        [[ -n "${expected_top[$path]:-}" ]] || {
            echo "Unexpected top-level submodule: $path" >&2
            exit 1
        }
    done < <(git -C "$root" config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')

    for component in "${components[@]}"; do
        [[ "$component" != DevloperNote && "$component" != xWalk-rpi5-iw ]] || continue
        config_name="$component"
        expected_path="$component"
        path="$(git config -f "$nested" --get "submodule.$config_name.path")"
        url="$(git config -f "$nested" --get "submodule.$config_name.url")"
        branch="$(git config -f "$nested" --get "submodule.$config_name.branch")"
        [[ "$path" == "$expected_path" ]] || {
            echo "Invalid nested path for $component" >&2
            exit 1
        }
        [[ "$url" == ../"$component" ]] || {
            echo "Invalid nested relative URL for $component" >&2
            exit 1
        }
        [[ "$branch" == master ]] || {
            echo "Invalid nested branch for $component" >&2
            exit 1
        }
        [[ -d "$root/xWalk-rpi5-hw/$expected_path" && ! -L "$root/xWalk-rpi5-hw/$expected_path" ]] || {
            echo "Missing integrated source directory for $component" >&2
            exit 1
        }
        git -C "$root" ls-files --error-unmatch "xWalk-rpi5-hw/$expected_path" >/dev/null || {
            echo "Integrated source is not tracked for $component" >&2
            exit 1
        }
    done
    [[ "$(git config -f "$nested" --get-regexp '^submodule\..*\.path$' | wc -l)" -eq 6 ]] || {
        echo "Expected six nested xWalk-rpi5-hw component mappings" >&2
        exit 1
    }
    echo "Validated root developer notes and hierarchical migration metadata"
}

validate_gitlink_superproject()
{
    local component expected_path expected_url path url branch mode
    local -A expected=()
    for component in "${components[@]}"; do
        expected_path="$(integrated_path "$component")"
        expected_url="$component"
        expected["$expected_path"]=1
        path="$(git -C "$root" config -f .gitmodules --get "submodule.$component.path")"
        url="$(git -C "$root" config -f .gitmodules --get "submodule.$component.url")"
        branch="$(git -C "$root" config -f .gitmodules --get "submodule.$component.branch")"
        [[ "$path" == "$expected_path" ]] || { echo "Invalid path for $component" >&2; exit 1; }
        [[ "$branch" == master ]] || { echo "Invalid branch for $component" >&2; exit 1; }
        [[ "$url" != *github.com* && "$url" == */"$expected_url" ]] || {
            echo "Submodule $component must point only to its Gerrit repository" >&2
            exit 1
        }
        mode="$(git -C "$root" ls-files --stage -- "$path" | awk '{print $1}')"
        [[ "$mode" == 160000 ]] || { echo "Missing gitlink for $component" >&2; exit 1; }
    done
    while IFS= read -r path; do
        [[ -n "${expected[$path]:-}" ]] || { echo "Unexpected submodule: $path" >&2; exit 1; }
    done < <(git -C "$root" config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
    echo "Validated eight exact Gerrit component gitlinks"
}

submodule_count="$({ git -C "$root" config -f .gitmodules --get-regexp '^submodule\..*\.path$' 2>/dev/null || true; } | wc -l)"
case "$submodule_count" in
    0) validate_integrated_sources ;;
    4) validate_hierarchical_migration ;;
    8) validate_gitlink_superproject ;;
    *) echo "Expected zero integrated, four hierarchical, or eight direct submodule mappings" >&2; exit 1 ;;
esac
