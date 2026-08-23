#!/usr/bin/env bash

set -u

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 MEMORY_CHECKER_LOG [...]" >&2
    exit 2
fi

awk '
function finish_descriptor()
{
    if (descriptor_open && !descriptor_inherited)
    {
        print descriptor_filename ": " descriptor_header
        descriptors_failed = 1
    }
    descriptor_open = 0
    descriptor_inherited = 0
}

/^==[0-9]+== Open (file descriptor|[^ ]+ socket) [0-9]+:/ {
    finish_descriptor()
    descriptor_open = 1
    descriptor_header = $0
    descriptor_filename = FILENAME
    next
}

descriptor_open && /<inherited from parent>/ {
    descriptor_inherited = 1
}

END {
    finish_descriptor()
    exit descriptors_failed
}
' "$@"
