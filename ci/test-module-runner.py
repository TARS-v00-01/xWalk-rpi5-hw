#!/usr/bin/env python3
"""Regression checks for full-module inventory filtering without running devices."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('runner', Path(__file__).with_name('run-module-tests.py'))
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class InventoryTest(unittest.TestCase):
    def setUp(self):
        self.root = Path('/tmp/test-hw-inventory')
        self.inventory = {'tests': [], 'backtraceGraph': {'files': [], 'nodes': []}}
        for component in ('xWalkHal', 'xWalkDriver', 'xWalkController', 'xWalkTest', 'xWalkLibrary'):
            self.add(component, component + '/CMakeLists.txt')

    def add(self, name, path, properties=()):
        graph = self.inventory['backtraceGraph']
        index = len(graph['files'])
        graph['files'].append(str(self.root / path))
        graph['nodes'].append({'file': index})
        self.inventory['tests'].append({'name': name, 'backtrace': index, 'properties': list(properties)})

    def test_all_required_groups_selected(self):
        self.assertEqual(len(runner.select_tests(self.inventory, self.root)), 5)

    def test_devices_disabled_and_unrelated_suites_excluded(self):
        self.add('motor-hardware', 'xWalkHal/CMakeLists.txt', [{'name': 'LABELS', 'value': ['hardware']}])
        self.add('disabled', 'xWalkTest/CMakeLists.txt', [{'name': 'DISABLED', 'value': True}])
        self.add('tooling', '../xWalk-rpi5-tool/CMakeLists.txt')
        self.assertEqual(len(runner.select_tests(self.inventory, self.root)), 5)

    def test_missing_component_fails(self):
        self.inventory['tests'].pop()
        with self.assertRaises(SystemExit):
            runner.select_tests(self.inventory, self.root)

    def test_root_library_checks_included(self):
        self.add('xWalkLibraryX86ArchitectureHostTest', 'CMakeLists.txt')
        self.assertIn('xWalkLibraryX86ArchitectureHostTest', runner.select_tests(self.inventory, self.root))


if __name__ == '__main__':
    unittest.main()
