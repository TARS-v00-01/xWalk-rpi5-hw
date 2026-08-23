#!/usr/bin/env bash
set -Eeuo pipefail

[[ "$#" -eq 2 ]] || {
    echo "Usage: overlay-gerrit-component.sh SOURCE_CHECKOUT TARGET_DIRECTORY" >&2
    exit 2
}
source_checkout="$1"
target_directory="$2"
root="$(git rev-parse --show-toplevel)"
source_checkout="$(realpath -- "$source_checkout")"
target_directory="$(realpath -m -- "$target_directory")"
[[ -d "$source_checkout/.git" || -f "$source_checkout/.git" ]] || {
    echo "Component checkout is not a Git work tree" >&2
    exit 2
}
case "$target_directory/" in
    "$root/xWalk-rpi5-hw/"*) ;;
    "$root/scripts/integration/"|"$root/xWalk-rpi5-iw/"|"$root/devloper-note/") ;;
    *) echo "Component target is not an approved integration path" >&2; exit 2 ;;
esac
[[ ! -L "$target_directory" ]] || {
    echo "Component target must not be symbolic" >&2
    exit 2
}
relative_target="${target_directory#"$root/"}"
[[ -n "$(git -C "$root" ls-files -- "$relative_target")" ]] || {
    echo "Component target is not tracked by the integration checkout" >&2
    exit 2
}
mode="$(git -C "$root" ls-files --stage -- "$relative_target" | awk -v target="$relative_target" \
    '$4 == target {print $1}')"
if [[ "$mode" == 160000 ]]; then
    rm -r -- "$target_directory"
else
    git -C "$root" rm --quiet -r -- "$relative_target"
fi
mkdir -p "$target_directory"
git -C "$source_checkout" archive HEAD | tar -x -C "$target_directory"
if [[ "$mode" != 160000 ]]; then
    git -C "$root" add -- "$relative_target"
fi
echo "Overlaid exact Gerrit component patch set at $relative_target"
