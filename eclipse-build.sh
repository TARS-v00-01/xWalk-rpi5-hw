#!/usr/bin/env bash

set -eu

SCRIPT_DIRECTORY=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
XWALK_RPI5_ROOT="${SCRIPT_DIRECTORY}"
BUILD_DIRECTORY="${XWALK_RPI5_ROOT}/xWalkController/build-eclipse-host"

if [ "${1:-}" = "clean" ]
then
    cmake -E remove_directory "${BUILD_DIRECTORY}"
else
    cmake --fresh -S "${XWALK_RPI5_ROOT}" -B "${BUILD_DIRECTORY}" \
        -DCMAKE_BUILD_TYPE=Debug \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    cmake --build "${BUILD_DIRECTORY}" --parallel
    ctest --test-dir "${BUILD_DIRECTORY}" --output-on-failure --no-tests=error
fi
