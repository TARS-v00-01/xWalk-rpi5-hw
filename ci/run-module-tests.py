#!/usr/bin/env python3
"""Build and verify the complete hardware aggregate using only host-safe providers."""
from pathlib import Path
import argparse
import json
import re
import subprocess
import sys


def run(*command: str) -> None:
    """Stop at the first failed or timed-out build/test command."""
    display = list(command)
    if '-R' in display:
        display[display.index('-R') + 1] = '<owned hardware test names>'
    print('+ ' + ' '.join(display), flush=True)
    subprocess.run(command, check=True, timeout=1800)


def select_tests(inventory: dict, root: Path) -> list[str]:
    """Select owned enabled host tests; fail if any required module is absent."""
    graph = inventory['backtraceGraph']
    selected = []
    groups = set()
    for test in inventory['tests']:
        properties = {entry['name']: entry['value'] for entry in test.get('properties', [])}
        if 'hardware' in properties.get('LABELS', []) or properties.get('DISABLED', False):
            continue
        frame = graph['nodes'][test['backtrace']]
        owner = Path(graph['files'][frame['file']]).resolve()
        try:
            component = owner.relative_to(root).parts[0]
        except ValueError:
            continue
        if component in ('xWalkHal', 'xWalkDriver', 'xWalkController', 'xWalkTest', 'xWalkLibrary'):
            selected.append(test['name'])
            groups.add(component)
        elif test['name'].startswith('xWalkLibrary') and test['name'].endswith('ArchitectureHostTest'):
            selected.append(test['name'])
            groups.add('xWalkLibrary')
    if not {'xWalkHal', 'xWalkDriver', 'xWalkController', 'xWalkTest', 'xWalkLibrary'} <= groups:
        raise SystemExit('Incomplete hardware test inventory: ' + ', '.join(sorted(groups)))
    return selected


def main() -> None:
    """Run all hardware component tests and the shared cross-module sequences."""
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--build-dir', type=Path, default=root.parent / 'build-host/cmake')
    parser.add_argument('--jobs', type=int, default=2)
    parser.add_argument('--no-build', action='store_true', help='Use an already built host aggregate')
    args = parser.parse_args()
    build = args.build_dir.resolve()
    if args.jobs < 1:
        parser.error('--jobs must be positive')
    if not args.no_build:
        run('cmake', '-S', str(root), '-B', str(build), '-G', 'Ninja',
            '-DCMAKE_EXPORT_COMPILE_COMMANDS=ON', '-DBUILD_TESTING=ON', '-DCMAKE_BUILD_TYPE=Debug', '-DXWALK_BUILD_RPI=OFF',
            '-DXWALK_CONTROLLER_BUILD_HOST=ON', '-DXWALK_CONTROLLER_BUILD_RPI5=OFF')
        run('cmake', '--build', str(build), '--parallel', str(args.jobs))
    cache = (build / 'CMakeCache.txt').read_text()
    required = ('XWALK_CONTROLLER_BUILD_HOST:BOOL=ON', 'XWALK_HAL_BUILD_HOST:BOOL=ON',
                'BUILD_TESTING:BOOL=ON')
    if not all(entry in cache.splitlines() for entry in required):
        raise SystemExit('Full hardware regression requires a HOST testing build')
    inventory = json.loads(subprocess.check_output(
        ['ctest', '--test-dir', str(build), '--show-only=json-v1'], text=True, timeout=30))
    selected = select_tests(inventory, root)
    pattern = '^(' + '|'.join(re.escape(name) for name in selected) + ')$'
    print(f'Selected {len(selected)} hardware module host tests', flush=True)
    run('ctest', '--test-dir', str(build), '--output-on-failure', '--no-tests=error',
        '-R', pattern, '-LE', 'hardware', '--timeout', '120')
    run(sys.executable, str(root / 'ci/check-audio.py'))


if __name__ == '__main__':
    try:
        main()
    except subprocess.CalledProcessError as error:
        raise SystemExit(error.returncode) from None
    except subprocess.TimeoutExpired:
        raise SystemExit('Hardware regression command exceeded its timeout') from None
