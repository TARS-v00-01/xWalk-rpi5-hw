#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

root="$(git rev-parse --show-toplevel)"
"$root/scripts/integration/shell-agent/gerrit-tool/validate-integration-metadata.sh"

if [[ "${XWALK_GITHUB_METADATA_ONLY:-false}" == true ]]; then
    echo "Metadata-only validation selected; private submodules were not initialized"
    exit 0
fi

: "${GERRIT_SUBMODULE_SSH_KEY_FILE:?Set the temporary Gerrit SSH key path}"
: "${GERRIT_SSH_KNOWN_HOSTS_FILE:?Set the pinned Gerrit known-hosts path}"
: "${GERRIT_SUBMODULE_USERNAME:?Set the read-only Gerrit account}"
: "${GERRIT_SERVER_HOST:?Set the Gerrit server host}"
: "${GERRIT_SSH_PORT:=29418}"
[[ -f "$GERRIT_SUBMODULE_SSH_KEY_FILE" ]] || { echo "Missing Gerrit SSH key" >&2; exit 2; }
[[ -s "$GERRIT_SSH_KNOWN_HOSTS_FILE" ]] || { echo "Missing pinned Gerrit host key" >&2; exit 2; }
key_mode="$(stat -c %a "$GERRIT_SUBMODULE_SSH_KEY_FILE")"
(( (8#$key_mode & 8#077) == 0 )) || { echo "Gerrit SSH key must have mode 0600" >&2; exit 2; }
[[ "$GERRIT_SUBMODULE_USERNAME" =~ ^[A-Za-z0-9._-]+$ ]]
[[ "$GERRIT_SERVER_HOST" =~ ^[A-Za-z0-9.-]+$ ]]
[[ "$GERRIT_SSH_PORT" =~ ^[0-9]+$ ]]

temporary="$(mktemp -d -t xwalk-github-submodules-XXXXXXXX)"
cleanup()
{
    git -C "$root" config --local --unset core.sshCommand >/dev/null 2>&1 || true
    rm -rf -- "$temporary"
}
trap cleanup EXIT

printf -v ssh_command '%q ' ssh -i "$GERRIT_SUBMODULE_SSH_KEY_FILE" -o BatchMode=yes \
    -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes \
    -o "UserKnownHostsFile=$GERRIT_SSH_KNOWN_HOSTS_FILE" \
    -p "$GERRIT_SSH_PORT"
export GIT_SSH_COMMAND="$ssh_command"
git -C "$root" config --local core.sshCommand "$ssh_command"
git -C "$root" submodule sync --recursive
while read -r key _path; do
    name="${key#submodule.}"
    name="${name%.path}"
    git -C "$root" config --local "submodule.$name.url" \
        "ssh://$GERRIT_SUBMODULE_USERNAME@$GERRIT_SERVER_HOST:$GERRIT_SSH_PORT/$name"
done < <(git -C "$root" config -f .gitmodules --get-regexp '^submodule\..*\.path$')
git -C "$root" submodule update --init --recursive
git -C "$root" submodule foreach --recursive 'git rev-parse --verify HEAD >/dev/null'
echo "Checked out exact private Gerrit submodule commits"
