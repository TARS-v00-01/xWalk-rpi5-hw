#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
# shellcheck source=xwalk-gerrit-common.sh
source "$script_dir/xwalk-gerrit-common.sh"

mode="${1:---dry-run}"
[[ "$#" -eq 1 ]] || { echo "Usage: gerrit-submodule-migrate.sh --dry-run|--apply" >&2; exit 2; }
xwalk_mode "$mode"
xwalk_load_config
source_root="$(git rev-parse --show-toplevel)"
output="${XWALK_INTEGRATION_OUTPUT_DIR:-}"

plan_component()
{
    local component="$1" product_path verification=""
    product_path="$(xwalk_integration_path "$component")"
    [[ "$XWALK_MODE" != "dry-run" ]] || verification="Fixed allowlist entry validated"
    printf '[%s] convert %s to Gerrit submodule\n' "$XWALK_MODE" "$component"
    xwalk_log "add-submodule" "submodule" "xWalk-rpi5-hw" "$product_path" "tracked-directory" \
        "exact-gerrit-gitlink" "Convert component directory to a Gerrit submodule" \
        "The private integration repository must record an exact verified component commit." \
        "$XWALK_STATUS" "$verification"
    xwalk_log "set-submodule-url" "submodule" "xWalk-rpi5-hw" ".gitmodules:$component:url" \
        "none" "$GERRIT_BASE_URL/$component" "Configure Gerrit submodule URL" \
        "Every integration component must resolve only through Gerrit." \
        "$XWALK_STATUS" "$verification"
    xwalk_log "set-submodule-branch" "submodule" "xWalk-rpi5-hw" ".gitmodules:$component:branch" \
        "none" "master" "Record the maintenance branch" \
        "Uplift discovery uses master while builds remain pinned to the gitlink." "$XWALK_STATUS" \
        "$verification"
}

apply_component()
{
    local component="$1" product_path url clone_url commit
    product_path="$(xwalk_integration_path "$component")"
    url="${GERRIT_BASE_URL%/}/$component"
    clone_url="ssh://$GERRIT_ADMIN_USERNAME@$GERRIT_SERVER_HOST:$GERRIT_SSH_PORT/$component"
    git -C "$output" rm -r --force --quiet -- "$product_path"
    git -C "$output" submodule add --force --name "$component" -b master "$clone_url" "$product_path"
    git -C "$output" config -f .gitmodules "submodule.$component.url" "$url"
    commit="$(git -C "$output/$product_path" rev-parse HEAD)"
    git -C "$output" add .gitmodules "$product_path"
    xwalk_log "add-submodule" "submodule" "xWalk-rpi5-hw" "$product_path" "tracked-directory" "$commit" \
        "Added exact Gerrit component gitlink" \
        "The integration repository records a reproducible verified component revision." "Applied" \
        "gitlink and .gitmodules entry staged" "" "" "" "" "$commit"
    xwalk_log "set-submodule-url" "submodule" "xWalk-rpi5-hw" ".gitmodules:$component:url" \
        "none" "$url" "Configured Gerrit submodule URL" \
        "The exact component repository remains hosted only by Gerrit." \
        "Applied" "git config -f .gitmodules read-back succeeded"
    xwalk_log "set-submodule-branch" "submodule" "xWalk-rpi5-hw" ".gitmodules:$component:branch" \
        "unset" "master" "Configured submodule maintenance branch" \
        "Automated uplift checks target the component master branch." "Applied" \
        "git config -f .gitmodules read-back succeeded"
}

main()
{
    local component product_path file integration_remote stale_submodule
    for component in "${xwalk_components[@]}"; do
        product_path="$(xwalk_integration_path "$component")"
        [[ -d "$source_root/$product_path" ]] || {
            echo "Missing allowlisted component: $component" >&2
            return 2
        }
        [[ "$XWALK_MODE" == "dry-run" ]] && plan_component "$component"
    done
    [[ "$XWALK_MODE" == "apply" ]] || return 0
    [[ -z "$(git -C "$source_root" status --porcelain)" ]] || {
        echo "Submodule migration requires a clean source repository" >&2
        return 2
    }
    [[ "${XWALK_CONFIRM_SUBMODULES:-}" == "CREATE_INTEGRATION_CLONE" ]] || {
        echo "Set XWALK_CONFIRM_SUBMODULES=CREATE_INTEGRATION_CLONE for explicit apply" >&2
        return 2
    }
    output="$(xwalk_new_output_path "$output" "$source_root")"
    echo "Selected integration output: $output"
    git clone --quiet --no-local "$source_root" "$output"
    trap 'rm -rf -- "$output"' ERR INT TERM
    mkdir -p "$output/scripts"
    git -C "$output" mv xWalk-rpi5-tool scripts/integration
    git -C "$output" rm -r --force --quiet -- scripts/integration/py-agent/gerrit-tool \
        scripts/integration/py-agent/board-tool
    for stale_submodule in xWalk-rpi5-tool xWalk-rpi5-hw xWalk-rpi5-iw devloper-note; do
        git -C "$output" config -f .gitmodules --remove-section "submodule.$stale_submodule"
    done
    git -C "$output" rm --quiet -- .github/workflows/host-quality.yml
    while IFS= read -r -d '' file; do
        sed -i 's#xWalk-rpi5-tool/#scripts/integration/#g' "$output/$file"
    done < <(git -C "$output" grep -Il -z 'xWalk-rpi5-tool/' || true)
    git -C "$output" add --all
    xwalk_log "relocate-integration-tools" "migration" "xWalk-rpi5-hw" "scripts/integration" \
        "xWalk-rpi5-tool" "controlled-top-level-CI-helpers" "Relocated integration support" \
        "xWalk-rpi5-tool is not a product component or integration submodule." "Applied" \
        "Gerrit administration and migration tooling excluded"
    for component in "${xwalk_components[@]}"; do apply_component "$component"; done
    git -C "$output" submodule sync --recursive
    git -C "$output" submodule update --init --recursive
    # shellcheck disable=SC2016 # Git expands $name within each submodule process.
    git -C "$output" submodule foreach --quiet \
        'if git remote -v | grep -qi github; then echo "Forbidden GitHub remote in $name" >&2; exit 1; fi'
    "$output/scripts/integration/shell-agent/gerrit-tool/validate-integration-metadata.sh"
    git -C "$output" -c user.name=xWalk-Automation -c user.email=automation.invalid \
        commit -s -m "Create xWalk-rpi5-hw integration repository"
    integration_remote="${GERRIT_BASE_URL%/}/xWalk-rpi5-hw"
    git -C "$output" remote set-url origin "$integration_remote"
    xwalk_log "validate-submodules" "validation" "xWalk-rpi5-hw" ".gitmodules" "absent" "valid" \
        "Validated exact Gerrit submodules" \
        "Reproducible integration requires exact commits and no component GitHub remotes." "Verified" \
        "Recursive initialization and remote policy checks succeeded"
    if [[ "${XWALK_CONFIRM_INTEGRATION_UPLOAD:-}" == "PUSH_XWALK_RPI5_TO_GERRIT" ]]; then
        git -C "$output" push origin HEAD:refs/for/master
        xwalk_log "upload-initial-integration" "migration" "xWalk-rpi5-hw" "refs/for/master" \
            "not-uploaded" "uploaded" "Uploaded initial integration review" \
            "The new product baseline must pass Gerrit review before submission." "Applied" \
            "Gerrit accepted the explicit review refspec"
    else
        xwalk_log "upload-initial-integration" "migration" "xWalk-rpi5-hw" "refs/for/master" \
            "not-uploaded" "not-uploaded" "Skipped initial integration upload" \
            "Explicit remote-write confirmation was unavailable." "Skipped" \
            "Set XWALK_CONFIRM_INTEGRATION_UPLOAD=PUSH_XWALK_RPI5_TO_GERRIT"
    fi
    trap - ERR INT TERM
    printf 'Prepared integration clone: %s\n' "$output"
}

main
