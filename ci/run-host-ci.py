#!/usr/bin/env python3
"""Verify the committed hardware tree in an isolated, exactly pinned product context."""
from pathlib import Path
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile


def run(root: Path, *command: str) -> str:
    """Run a bounded child command and preserve its diagnostic output on failure."""
    result = subprocess.run(command, cwd=root, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=1800, check=False)
    if result.returncode:
        print(result.stdout, file=sys.stderr)
        raise SystemExit(result.returncode)
    return result.stdout.strip()


def main() -> None:
    """Prepare exact submitted dependencies, then execute the shared hardware graph."""
    source = Path(__file__).resolve().parents[1]
    context = json.loads((source / 'ci/context.json').read_text())
    for revision in context.values():
        if not isinstance(revision, str) or not re.fullmatch(r'[0-9a-f]{40}', revision):
            raise SystemExit('Hardware CI context must pin full submitted commit identifiers')
    remote = 'https://github.com/TARS-v00-01'
    if os.environ.get('GERRIT_SERVER_HOST'):
        host = os.environ['GERRIT_SERVER_HOST']
        user = os.environ['GERRIT_SUBMODULE_USERNAME']
        port = os.environ.get('GERRIT_SSH_PORT', '29418')
        if not re.fullmatch(r'[A-Za-z0-9.-]+', host) or not re.fullmatch(r'[A-Za-z0-9_.-]+', user):
            raise SystemExit('Invalid Gerrit checkout endpoint')
        if not port.isdigit() or not 0 < int(port) < 65536:
            raise SystemExit('Invalid Gerrit SSH port')
        key = Path(os.environ['GERRIT_SUBMODULE_SSH_KEY_FILE'])
        known_hosts = Path(os.environ['GERRIT_SSH_KNOWN_HOSTS_FILE'])
        if not key.is_file() or key.stat().st_mode & 0o077 or not known_hosts.is_file():
            raise SystemExit('Require a private SSH key and pinned Gerrit host keys')
        os.environ['GIT_SSH_COMMAND'] = shlex.join([
            'ssh', '-i', str(key), '-p', port, '-o', 'BatchMode=yes', '-o', 'IdentitiesOnly=yes',
            '-o', 'StrictHostKeyChecking=yes', '-o', f'UserKnownHostsFile={known_hosts}',
        ])
        remote = f'ssh://{user}@{host}:{port}'
    # Match the managed Gerrit runner's module scheduling for timing-sensitive host simulations.
    os.environ.setdefault('XWALK_CI_MAX_WORKERS', '1')
    os.environ['GIT_TERMINAL_PROMPT'] = '0'
    artifacts = source / 'ci-artifacts'
    artifacts.mkdir(exist_ok=True)
    # Short paths also keep Unix socket fixtures below the platform path limit.
    with tempfile.TemporaryDirectory(prefix='xwalk-hw-', dir='/tmp') as temporary:
        work = Path(temporary)
        workspace = work / 'product'
        run(work, 'git', 'clone', '--no-checkout', remote + '/xWalkPiCarAI', str(workspace))
        run(workspace, 'git', 'merge-base', '--is-ancestor', context['product_revision'], 'origin/master')
        run(workspace, 'git', 'checkout', '--detach', context['product_revision'])
        run(workspace, 'git', '-c', f'url.{remote}/.insteadOf=https://github.com/TARS-v00-01/',
            'submodule', 'update', '--init', '--recursive')
        tool = workspace / 'xWalk-rpi5-tool'
        run(tool, 'git', 'fetch', remote + '/xWalk-rpi5-tool', 'refs/heads/master')
        run(tool, 'git', 'merge-base', '--is-ancestor', context['tool_revision'], 'FETCH_HEAD')
        run(tool, 'git', 'checkout', '--detach', context['tool_revision'])
        helper = tool / 'py-agent/gerrit-tool/py-src/xWalkHardwareIntegration.py'
        run(workspace, sys.executable, '-B', str(helper), 'overlay', str(source), '--workspace',
            str(workspace), '--remote-base', remote)
        quality = tool / 'py-agent/gerrit-tool/py-src/xWalkHardwareQuality.py'
        output = run(workspace, sys.executable, '-B', str(quality), str(workspace),
                     '--log', str(artifacts / 'host-quality.log'))
        print(output)


if __name__ == '__main__':
    main()
