#!/usr/bin/env bash

# Loads authenticated xWalk AI environment values into the calling shell.
# Source this file; executing it cannot update its parent process environment.

_xwalk_load_environment() {
    local script_directory repository_root license_file license_mode license_tool
    local template_file decrypted_file name value record_index sentinel
    local -a decoded_records=()
    local -A decoded_values=()

    script_directory="$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
    if repository_root="$(git -C "$script_directory" rev-parse --show-toplevel 2>/dev/null)"
    then
        :
    else
        case "$script_directory" in
            */scripts/integration/*)
                repository_root="$(CDPATH='' cd -- "$script_directory/../../../../.." && pwd)"
                ;;
            *)
                repository_root="$(CDPATH='' cd -- "$script_directory/../../../.." && pwd)"
                ;;
        esac
    fi
    license_file="$repository_root/xWalk-rpi5-hw/xWalkLibrary/X_WALK_LICENSE.KEY"
    license_tool="$repository_root/scripts/integration/py-agent/dev-tool/xWalkLicenseTool"
    template_file="$repository_root/scripts/integration/shell-agent/env-tool/license/xWalkLicense.cfg"

    if [ ! -f "$license_file" ] || [ ! -r "$license_file" ]; then
        echo "xWalk environment: encrypted licence file is unreadable: $license_file" >&2
        return 2
    fi
    license_mode="$(stat -c '%a' "$license_file")" || return 2
    if (( (8#$license_mode & 077) != 0 )); then
        echo "xWalk environment: encrypted licence file must have mode 0600" >&2
        return 2
    fi
    if [ ! -r "$license_tool" ]; then
        echo "xWalk environment: licence tool is unavailable: $license_tool" >&2
        return 2
    fi
    if [ ! -r "$template_file" ]; then
        echo "xWalk environment: licence template is unavailable: $template_file" >&2
        return 2
    fi

    decrypted_file="$(mktemp "${TMPDIR:-/tmp}/xwalk-license.XXXXXX.json")" || return 2
    chmod 0600 "$decrypted_file" || {
        rm -f "$decrypted_file"
        return 2
    }
    if ! python3 "$license_tool" decrypt --output "$decrypted_file" >/dev/null; then
        rm -f "$decrypted_file"
        echo "xWalk environment: licence-key decryption failed" >&2
        return 2
    fi

    mapfile -d '' -t decoded_records < <(
        python3 -c 'import configparser, json, netrc, os, re, sys
from pathlib import Path
with open(sys.argv[1], encoding="utf-8") as input_file:
    values = json.load(input_file)
template_parser = configparser.ConfigParser(interpolation=None, strict=True)
template_parser.optionxform = str
try:
    with open(sys.argv[2], encoding="utf-8") as input_file:
        template_parser.read_file(input_file)
except configparser.Error:
    raise SystemExit("licence template configuration is malformed")
if template_parser.defaults() or template_parser.sections() != ["models"]:
    raise SystemExit("licence template must contain only one [models] section")
template = dict(template_parser.items("models", raw=True))
valid_name = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$").fullmatch
if not template:
    raise SystemExit("licence template [models] section must not be empty")
if any(not isinstance(name, str) or not valid_name(name) for name in template):
    raise SystemExit("licence template contains an invalid variable name")
if any(not isinstance(value, str) or value for value in template.values()):
    raise SystemExit("licence template values must remain empty strings")
serial_name = "X_WALK_LICENSE_SERIAL"
serial_pattern = re.compile(r"^XWALK-[0-9]{4}-[0-9A-F]{8}$").fullmatch
if not isinstance(values.get(serial_name), str) or not serial_pattern(values[serial_name]):
    raise SystemExit("decrypted licence contains an invalid serial number")
if set(values) - {serial_name} != set(template):
    raise SystemExit("decrypted licence does not match the template variable names")
credential_machines = {
    "api.anthropic.com": ("ANTHROPIC_API_KEY",),
    "api.deepseek.com": ("DEEPSEEK_API_KEY",),
    "ark.cn-beijing.volces.com": ("DOUBAO_API_KEY",),
    "generativelanguage.googleapis.com": ("GEMINI_API_KEY",),
    "api.x.ai": ("GROK_API_KEY", "XAI_API_KEY"),
    "api.openai.com": ("OPENAI_API_KEY",),
    "dashscope-intl.aliyuncs.com": ("QWEN_API_KEY",),
}
override_path = os.environ.get("XWALK_NETRC_FILE")
netrc_path = Path(override_path).expanduser() if override_path else Path.home() / ".netrc"
netrc_path = netrc_path.resolve()
try:
    mode = netrc_path.stat().st_mode
except OSError:
    raise SystemExit("xWalk credential file is unavailable")
if os.name != "nt" and mode & 0o077:
    raise SystemExit("xWalk credential file must have mode 0600")
try:
    parsed_netrc = netrc.netrc(str(netrc_path))
except (netrc.NetrcParseError, OSError, UnicodeError):
    raise SystemExit("xWalk credential file is malformed or unreadable")
environment_values = {name: values[name] for name in template}
for machine, names in credential_machines.items():
    authentication = parsed_netrc.hosts.get(machine)
    if authentication is None:
        continue
    _, _, password = authentication
    if not password:
        continue
    for name in names:
        environment_values[name] = password
for name in sorted(environment_values):
    os.write(1, name.encode("utf-8") + b"\0" + environment_values[name].encode("utf-8") + b"\0")
os.write(1, b"XWALK_LICENSE_RECORDS_COMPLETE\0")' \
            "$decrypted_file" "$template_file"
    )
    rm -f "$decrypted_file"
    sentinel="XWALK_LICENSE_RECORDS_COMPLETE"
    if [ "${#decoded_records[@]}" -lt 1 ] ||
        [ "${decoded_records[-1]}" != "$sentinel" ] ||
        (( (${#decoded_records[@]} - 1) % 2 != 0 )); then
        echo "xWalk environment: decrypted licence does not match the template" >&2
        return 2
    fi
    unset 'decoded_records[-1]'

    for ((record_index = 0; record_index < ${#decoded_records[@]}; record_index += 2)); do
        name="${decoded_records[$record_index]}"
        value="${decoded_records[$((record_index + 1))]}"
        decoded_values[$name]="$value"
    done
    for name in "${!decoded_values[@]}"; do
        export "$name=${decoded_values[$name]}"
    done
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "Source xWalkEnv.sh so it can update the calling shell environment." >&2
    exit 2
fi

_xwalk_load_environment
_xwalk_environment_status=$?
unset -f _xwalk_load_environment
if [ "$_xwalk_environment_status" -eq 0 ]; then
    unset _xwalk_environment_status
    return 0
fi
unset _xwalk_environment_status
return 2
