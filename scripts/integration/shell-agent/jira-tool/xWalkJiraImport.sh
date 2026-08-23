#!/usr/bin/env bash

set -Eeuo pipefail

script_dir="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)"
repository_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
package_source="$repository_root/scripts/integration/py-agent/board-tool/py-src"

if ! command -v python3 >/dev/null 2>&1; then
    printf 'ERROR: python3 is required to run xWalkJiraImport.\n' >&2
    exit 2
fi

export PYTHONPATH="${package_source}${PYTHONPATH:+:${PYTHONPATH}}"
exec python3 -m xWalkJiraImport "$@"
