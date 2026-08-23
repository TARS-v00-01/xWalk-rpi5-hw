#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIRECTORY=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPOSITORY_ROOT=$(git -C "${SCRIPT_DIRECTORY}" rev-parse --show-toplevel)
DOCUMENTATION_DIRECTORY="${REPOSITORY_ROOT}/devloper-note"
BUILD_DIRECTORY="${REPOSITORY_ROOT}/build-devloper-note-wiki"
VIRTUAL_ENVIRONMENT="${BUILD_DIRECTORY}/venv"
STAGED_DOCUMENTATION="${BUILD_DIRECTORY}/docs"
REQUIREMENTS_FILE="${SCRIPT_DIRECTORY}/requirements-wiki.txt"
REQUIREMENTS_MARKER="${VIRTUAL_ENVIRONMENT}/.xwalk-wiki-requirements"
MKDOCS_CONFIGURATION="${DOCUMENTATION_DIRECTORY}/mkdocs.yml"
GENERATED_CONFIGURATION="${BUILD_DIRECTORY}/mkdocs.yml"
LOCAL_SITE_DIRECTORY="${BUILD_DIRECTORY}/local-site"
SERVER_SITE_DIRECTORY="${BUILD_DIRECTORY}/server-site"
GITHUB_SITE_DIRECTORY="${BUILD_DIRECTORY}/github-site"
DEFAULT_LOCAL_HOST=127.0.0.1
DEFAULT_LOCAL_PORT=8000
DEFAULT_SERVER_HOST=0.0.0.0
DEFAULT_SERVER_PORT=8080
DEFAULT_GITHUB_URL=https://jochuuu.github.io/xWalkPiCarAI/
DEFAULT_GITHUB_SOURCE_REPOSITORY=https://github.com/jochuuu/xWalkPiCarAI
DEFAULT_GITHUB_SOURCE_REVISION=master
GITHUB_SOURCE_REPOSITORY=${XWALK_WIKI_GITHUB_SOURCE_REPOSITORY:-${DEFAULT_GITHUB_SOURCE_REPOSITORY}}
GITHUB_SOURCE_REVISION=${XWALK_WIKI_GITHUB_SOURCE_REVISION:-${DEFAULT_GITHUB_SOURCE_REVISION}}

print_usage()
{
    cat <<'EOF'
Usage: scripts/integration/doc-tool/wiki.sh PROFILE [OPTIONS]

Build and access the xWalk developer-note wiki through one of three profiles.

Profiles:
  local               Build, serve on loopback, and open the local wiki.
  server              Build and serve a static site from the college server.
  github              Build a GitHub Pages artifact and print its public URL.

Maintenance:
  verify              Strictly build and validate the documentation artifact.
  setup               Install the pinned wiki dependency in an isolated environment.
  clean               Remove every generated wiki environment and site.
  help                Show this help text.

Options:
  --host ADDRESS      Server bind address. Valid only for local and server.
  --port PORT         Server TCP port. Valid only for local and server.
  --site-url URL      Public canonical URL. Valid only for server and github.
  --open              Open the resulting URL in the default browser.
  --no-open           Do not open a browser. Valid only for local.

Defaults:
  local               127.0.0.1:8000, with browser opening.
  server              0.0.0.0:8080, without browser opening.
  github              https://jochuuu.github.io/xWalkPiCarAI/

Examples:
  scripts/integration/doc-tool/wiki.sh local
  scripts/integration/doc-tool/wiki.sh local --no-open --port 8001
  scripts/integration/doc-tool/wiki.sh server --site-url https://docs.example.edu/xwalk/
  scripts/integration/doc-tool/wiki.sh github
  scripts/integration/doc-tool/wiki.sh github --open
EOF
}

fail()
{
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

require_file()
{
    local required_file=$1

    [ -f "${required_file}" ] || fail "Required file is missing: ${required_file}"
}

validate_build_directory()
{
    [ "${BUILD_DIRECTORY}" = "${REPOSITORY_ROOT}/build-devloper-note-wiki" ] || \
        fail "Refusing unexpected build directory: ${BUILD_DIRECTORY}"
    [ "${BUILD_DIRECTORY}" != "/" ] || fail "Refusing to use the filesystem root as a build directory"
}

validate_port()
{
    local port=$1

    case "${port}" in
        ''|*[!0-9]*) fail "Port must be an integer from 1 through 65535: ${port}" ;;
    esac

    if [ "${port}" -lt 1 ] || [ "${port}" -gt 65535 ]
    then
        fail "Port must be an integer from 1 through 65535: ${port}"
    fi
}

validate_site_url()
{
    local site_url=$1

    case "${site_url}" in
        http://*|https://*) ;;
        *) fail "Site URL must start with http:// or https://: ${site_url}" ;;
    esac
    case "${site_url}" in
        *"'"*) fail "Site URL must not contain a single quote: ${site_url}" ;;
    esac
}

ensure_environment()
{
    local python_command

    require_file "${REQUIREMENTS_FILE}"
    require_file "${MKDOCS_CONFIGURATION}"
    command -v python3 >/dev/null 2>&1 || fail "python3 is required"
    python_command=$(command -v python3)

    mkdir -p -- "${BUILD_DIRECTORY}"
    if [ ! -x "${VIRTUAL_ENVIRONMENT}/bin/python" ]
    then
        printf 'Creating wiki environment: %s\n' "${VIRTUAL_ENVIRONMENT}"
        "${python_command}" -m venv "${VIRTUAL_ENVIRONMENT}"
    fi

    if [ ! -f "${REQUIREMENTS_MARKER}" ] || \
        ! cmp -s "${REQUIREMENTS_FILE}" "${REQUIREMENTS_MARKER}"
    then
        printf 'Installing pinned wiki dependencies...\n'
        "${VIRTUAL_ENVIRONMENT}/bin/python" -m pip install \
            --disable-pip-version-check \
            --requirement "${REQUIREMENTS_FILE}"
        cp -a -- "${REQUIREMENTS_FILE}" "${REQUIREMENTS_MARKER}"
    fi
}

prepare_wiki_sources()
{
    local site_subdirectory=$1
    local site_url=$2
    local collection

    validate_build_directory
    require_file "${DOCUMENTATION_DIRECTORY}/index.md"
    require_file "${DOCUMENTATION_DIRECTORY}/README.md"
    require_file "${MKDOCS_CONFIGURATION}"
    for collection in gerrit-note xwalk-rpi5-note
    do
        [ -d "${DOCUMENTATION_DIRECTORY}/${collection}" ] || \
            fail "Documentation collection is missing: ${DOCUMENTATION_DIRECTORY}/${collection}"
    done

    if [ -d "${STAGED_DOCUMENTATION}" ]
    then
        rm -r -- "${STAGED_DOCUMENTATION}"
    fi
    mkdir -p -- "${STAGED_DOCUMENTATION}/wiki-tool"
    sed 's#](README.md)#](wiki-tool/index.md)#' \
        "${DOCUMENTATION_DIRECTORY}/index.md" >"${STAGED_DOCUMENTATION}/index.md"
    cp -a -- "${DOCUMENTATION_DIRECTORY}/README.md" "${STAGED_DOCUMENTATION}/wiki-tool/index.md"
    for collection in gerrit-note xwalk-rpi5-note
    do
        cp -a -- "${DOCUMENTATION_DIRECTORY}/${collection}" "${STAGED_DOCUMENTATION}/${collection}"
    done
    "${VIRTUAL_ENVIRONMENT}/bin/python" "${SCRIPT_DIRECTORY}/rewrite_wiki_links.py" \
        "${REPOSITORY_ROOT}" \
        "${DOCUMENTATION_DIRECTORY}" \
        "${STAGED_DOCUMENTATION}" \
        "${GITHUB_SOURCE_REPOSITORY}" \
        "${GITHUB_SOURCE_REVISION}"

    sed "s#^site_dir: site\$#site_dir: ${site_subdirectory}#" \
        "${MKDOCS_CONFIGURATION}" >"${GENERATED_CONFIGURATION}"
    if [ -n "${site_url}" ]
    then
        validate_site_url "${site_url}"
        printf "site_url: '%s'\n" "${site_url}" >>"${GENERATED_CONFIGURATION}"
    fi
}

build_profile()
{
    local profile_name=$1
    local site_directory=$2
    local site_url=$3
    local strict_build=${4:-false}
    local site_subdirectory=${site_directory##*/}
    local build_arguments=(build --clean --config-file "${GENERATED_CONFIGURATION}")

    ensure_environment
    prepare_wiki_sources "${site_subdirectory}" "${site_url}"
    printf 'Building %s wiki: %s\n' "${profile_name}" "${site_directory}"
    if [ "${strict_build}" = true ]
    then
        build_arguments+=(--strict)
    fi
    NO_MKDOCS_2_WARNING=true "${VIRTUAL_ENVIRONMENT}/bin/mkdocs" "${build_arguments[@]}"
    printf '%s wiki build complete: %s/index.html\n' "${profile_name}" "${site_directory}"
}

open_browser()
{
    local url=$1

    if command -v xdg-open >/dev/null 2>&1
    then
        xdg-open "${url}" >/dev/null 2>&1 &
        return 0
    fi

    if command -v open >/dev/null 2>&1
    then
        open "${url}" >/dev/null 2>&1 &
        return 0
    fi

    return 1
}

wait_for_server()
{
    local host=$1
    local port=$2
    local server_pid=$3
    local attempt=0

    while [ "${attempt}" -lt 100 ]
    do
        attempt=$((attempt + 1))
        kill -0 "${server_pid}" 2>/dev/null || return 1
        if "${VIRTUAL_ENVIRONMENT}/bin/python" -c \
            'import socket, sys; connection = socket.create_connection((sys.argv[1], int(sys.argv[2])), 0.2); connection.close()' \
            "${host}" "${port}" >/dev/null 2>&1
        then
            return 0
        fi
        sleep 0.1
    done

    return 1
}

run_local_profile()
{
    local host=$1
    local port=$2
    local browser_requested=$3
    local server_pid=''
    local url="http://${host}:${port}/"

    [ "${host}" = "127.0.0.1" ] || [ "${host}" = "localhost" ] || [ "${host}" = "::1" ] || \
        fail "The local profile accepts only a loopback host"
    ensure_environment
    prepare_wiki_sources "${LOCAL_SITE_DIRECTORY##*/}" ''

    if [ "${browser_requested}" = false ]
    then
        printf 'Serving local wiki at %s\n' "${url}"
        NO_MKDOCS_2_WARNING=true exec "${VIRTUAL_ENVIRONMENT}/bin/mkdocs" serve \
            --config-file "${GENERATED_CONFIGURATION}" \
            --dev-addr "${host}:${port}"
    fi

    stop_server()
    {
        if [ -n "${server_pid}" ] && kill -0 "${server_pid}" 2>/dev/null
        then
            kill "${server_pid}" 2>/dev/null || true
            wait "${server_pid}" 2>/dev/null || true
        fi
    }
    trap stop_server EXIT INT TERM

    NO_MKDOCS_2_WARNING=true "${VIRTUAL_ENVIRONMENT}/bin/mkdocs" serve \
        --config-file "${GENERATED_CONFIGURATION}" \
        --dev-addr "${host}:${port}" &
    server_pid=$!
    wait_for_server "${host}" "${port}" "${server_pid}" || fail "Local wiki did not start at ${url}"

    if open_browser "${url}"
    then
        printf 'Opened local wiki: %s\n' "${url}"
    else
        printf 'Open this URL manually: %s\n' "${url}"
    fi
    printf 'Press Ctrl-C to stop the local wiki server.\n'
    wait "${server_pid}"
}

run_server_profile()
{
    local host=$1
    local port=$2
    local site_url=$3

    build_profile server "${SERVER_SITE_DIRECTORY}" "${site_url}"
    printf 'Serving the static college-server wiki on %s:%s\n' "${host}" "${port}"
    if [ -n "${site_url}" ]
    then
        printf 'Configured public URL: %s\n' "${site_url}"
    else
        printf 'Configure college DNS, firewall/NAT, and TLS before public Internet access.\n'
    fi
    printf 'Press Ctrl-C to stop the server.\n'
    exec "${VIRTUAL_ENVIRONMENT}/bin/python" -m http.server "${port}" \
        --bind "${host}" \
        --directory "${SERVER_SITE_DIRECTORY}"
}

run_github_profile()
{
    local site_url=$1
    local browser_requested=$2

    build_profile github "${GITHUB_SITE_DIRECTORY}" "${site_url}"
    printf 'GitHub Pages artifact: %s\n' "${GITHUB_SITE_DIRECTORY}"
    printf 'GitHub Pages URL: %s\n' "${site_url}"
    printf 'Publication occurs through the approved GitHub Pages workflow after Gerrit integration sync.\n'
    if [ "${browser_requested}" = true ]
    then
        if open_browser "${site_url}"
        then
            printf 'Opened GitHub Pages URL: %s\n' "${site_url}"
        else
            printf 'Open this URL manually: %s\n' "${site_url}"
        fi
    fi
}

verify_wiki()
{
    local site_url=$1
    local search_index="${GITHUB_SITE_DIRECTORY}/search/search_index.json"

    ensure_environment
    PYTHONPATH="${SCRIPT_DIRECTORY}" "${VIRTUAL_ENVIRONMENT}/bin/python" -m unittest discover \
        --start-directory "${SCRIPT_DIRECTORY}/test" \
        --pattern 'test_*.py'
    "${VIRTUAL_ENVIRONMENT}/bin/python" "${SCRIPT_DIRECTORY}/verify_wiki.py" \
        "${DOCUMENTATION_DIRECTORY}"
    build_profile verify "${GITHUB_SITE_DIRECTORY}" "${site_url}" true
    require_file "${GITHUB_SITE_DIRECTORY}/index.html"
    require_file "${GITHUB_SITE_DIRECTORY}/sitemap.xml"
    require_file "${search_index}"
    "${VIRTUAL_ENVIRONMENT}/bin/python" -m json.tool "${search_index}" >/dev/null
    grep -Fq 'xWalk Developer Notes' "${GITHUB_SITE_DIRECTORY}/index.html" || \
        fail "Generated wiki homepage does not contain the expected title"
    grep -Fq "${site_url}" "${GITHUB_SITE_DIRECTORY}/sitemap.xml" || \
        fail "Generated wiki sitemap does not contain the configured public URL"
    "${VIRTUAL_ENVIRONMENT}/bin/python" "${SCRIPT_DIRECTORY}/verify_wiki.py" \
        "${DOCUMENTATION_DIRECTORY}" \
        --site-root "${GITHUB_SITE_DIRECTORY}" \
        --site-url "${site_url}"
    printf 'Wiki verification passed: %s\n' "${GITHUB_SITE_DIRECTORY}"
}

clean_wiki()
{
    validate_build_directory
    if [ -d "${BUILD_DIRECTORY}" ]
    then
        rm -r -- "${BUILD_DIRECTORY}"
        printf 'Removed wiki build directory: %s\n' "${BUILD_DIRECTORY}"
    else
        printf 'Wiki build directory is already absent: %s\n' "${BUILD_DIRECTORY}"
    fi
}

profile=${1:-help}
if [ "$#" -gt 0 ]
then
    shift
fi

host=''
port=''
site_url=''
browser_option=default
while [ "$#" -gt 0 ]
do
    case "$1" in
        --host)
            [ "$#" -ge 2 ] || fail "--host requires an address"
            host=$2
            shift 2
            ;;
        --port)
            [ "$#" -ge 2 ] || fail "--port requires a value"
            port=$2
            shift 2
            ;;
        --site-url)
            [ "$#" -ge 2 ] || fail "--site-url requires an HTTP or HTTPS URL"
            site_url=$2
            shift 2
            ;;
        --open)
            browser_option=true
            shift
            ;;
        --no-open)
            browser_option=false
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *) fail "Unknown option: $1" ;;
    esac
done

case "${profile}" in
    local)
        [ -z "${site_url}" ] || fail "--site-url is not valid for the local profile"
        host=${host:-${DEFAULT_LOCAL_HOST}}
        port=${port:-${DEFAULT_LOCAL_PORT}}
        [ "${browser_option}" != default ] || browser_option=true
        validate_port "${port}"
        run_local_profile "${host}" "${port}" "${browser_option}"
        ;;
    server)
        [ "${browser_option}" = default ] || fail "Browser options are not valid for the server profile"
        host=${host:-${DEFAULT_SERVER_HOST}}
        port=${port:-${DEFAULT_SERVER_PORT}}
        validate_port "${port}"
        [ -z "${site_url}" ] || validate_site_url "${site_url}"
        run_server_profile "${host}" "${port}" "${site_url}"
        ;;
    github)
        [ -z "${host}" ] || fail "--host is not valid for the github profile"
        [ -z "${port}" ] || fail "--port is not valid for the github profile"
        [ "${browser_option}" != false ] || fail "--no-open is not valid for the github profile"
        site_url=${site_url:-${DEFAULT_GITHUB_URL}}
        [ "${browser_option}" != default ] || browser_option=false
        validate_site_url "${site_url}"
        run_github_profile "${site_url}" "${browser_option}"
        ;;
    verify)
        [ -z "${host}${port}" ] || fail "verify does not accept host or port options"
        [ "${browser_option}" = default ] || fail "verify does not accept browser options"
        site_url=${site_url:-${DEFAULT_GITHUB_URL}}
        validate_site_url "${site_url}"
        verify_wiki "${site_url}"
        ;;
    setup)
        [ -z "${host}${port}${site_url}" ] || fail "setup does not accept network options"
        [ "${browser_option}" = default ] || fail "setup does not accept browser options"
        ensure_environment
        printf 'Wiki environment is ready: %s\n' "${VIRTUAL_ENVIRONMENT}"
        ;;
    clean)
        [ -z "${host}${port}${site_url}" ] || fail "clean does not accept network options"
        [ "${browser_option}" = default ] || fail "clean does not accept browser options"
        clean_wiki
        ;;
    help|-h|--help)
        print_usage
        ;;
    *)
        print_usage >&2
        fail "Unknown profile: ${profile}"
        ;;
esac
