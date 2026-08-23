#!/usr/bin/env python3
"""Test repository-owned CodeScene configuration and CI policy behavior."""

from __future__ import annotations

import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock


TOOL_PATH = Path(__file__).parents[1] / "xWalkCodeHealth"
LOADER = importlib.machinery.SourceFileLoader("xWalkCodeHealth", str(TOOL_PATH))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
assert SPEC is not None
MODULE = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(MODULE)


class XWalkCodeHealthTest(unittest.TestCase):
    """Verify exact revisions, safe rollout, mappings, and CLI results."""

    @classmethod
    def setUpClass(cls) -> None:
        """Load the real repository configuration for structural tests."""

        git_root = Path(
            subprocess.run(
                ["git", "-C", str(TOOL_PATH.parent), "rev-parse", "--show-toplevel"],
                check=True,
                capture_output=True,
                text=True,
            ).stdout.strip()
        )
        cls.root = (
            git_root
            if (git_root / ".codescene/project.json").is_file()
            else Path(__file__).parents[4]
        )
        if not (cls.root / ".codescene/project.json").is_file():
            raise unittest.SkipTest("Code Health tests require the integrated workspace")
        cls.configuration = MODULE.load_configuration(cls.root)

    def test_component_mapping_uses_actual_integrated_paths(self) -> None:
        """Map all eight requested modules without excluding their tests."""

        expected = {
            "Agent", "Audio Resources", "Controller", "HAL", "Interface", "Library",
            "Trace", "Developer Documentation",
        }
        self.assertEqual(
            {component["name"] for component in self.configuration["components"]}, expected
        )
        self.assertEqual(
            MODULE.matching_component(
                "xWalk-rpi5-hw/xWalkHal/interface/xWalkI2c/test/xWalkI2cHostTest.cpp",
                self.configuration,
            ),
            "HAL",
        )
        self.assertFalse(
            MODULE.is_excluded(
                "xWalk-rpi5-hw/xWalkHal/interface/xWalkI2c/test/xWalkI2cHostTest.cpp",
                self.configuration,
            )
        )

    def test_generated_and_build_outputs_are_excluded(self) -> None:
        """Exclude only generated, downloaded, cache, and build result paths."""

        for path in (
            "build-host/cmake/Testing/result.xml",
            "xWalk-rpi5-iw/auto-gen/message.pb.cc",
            "xWalk-rpi5-hw/xWalkTrace/generated/trace.hpp",
            "xWalk-rpi5-hw/xWalkController/build-eclipse-host/Testing/report.xml",
        ):
            self.assertTrue(MODULE.is_excluded(path, self.configuration), path)

    def test_no_tracked_source_header_or_test_is_excluded(self) -> None:
        """Retain every tracked production, public-header, and host-test file."""

        tracked = MODULE.git_output(self.root, "ls-files", "--recurse-submodules").splitlines()
        protected = [
            path for path in tracked
            if path.startswith("xWalk-rpi5-hw/")
            and any(part in {"src", "include", "test", "HostTest"} for part in Path(path).parts)
            and "/auto-gen/" not in path
            and "/generated/" not in path
        ]
        self.assertTrue(protected)
        excluded = [
            path for path in protected if MODULE.is_excluded(path, self.configuration)
        ]
        self.assertEqual(excluded, [])

    def test_missing_cli_is_non_blocking_by_default(self) -> None:
        """Mark analysis unavailable without hiding other CI during rollout."""

        baseline = "a" * 40
        revision = "b" * 40
        with tempfile.TemporaryDirectory() as directory:
            report = Path(directory)
            environment = {
                "XWALK_CODESCENE_CLI": "missing-codescene-cli",
                "XWALK_CODESCENE_REPORT_DIRECTORY": str(report),
                "XWALK_CODESCENE_BASE_REVISION": baseline,
                "XWALK_CODESCENE_REVISION": revision,
                "XWALK_CODESCENE_STRICT": "false",
            }
            with mock.patch.dict(os.environ, environment, clear=False), \
                    mock.patch.object(
                        MODULE, "resolve_revision", side_effect=[revision, baseline]
                    ), \
                    mock.patch.object(
                        MODULE,
                        "changed_files",
                        return_value=["xWalk-rpi5-hw/xWalkHal/example.cpp"],
                    ):
                result = MODULE.analyze(self.root, self.configuration)
            summary = json.loads((report / "summary.json").read_text(encoding="utf-8"))
        self.assertEqual(result, 0)
        self.assertEqual(summary["status"], "UNAVAILABLE")
        self.assertEqual(summary["quality_gate"], "UNAVAILABLE")

    def test_missing_cli_fails_when_strict_enforcement_is_enabled(self) -> None:
        """Make an unavailable mandatory CodeScene gate fail the CI stage."""

        baseline = "a" * 40
        revision = "b" * 40
        with tempfile.TemporaryDirectory() as directory:
            environment = {
                "XWALK_CODESCENE_CLI": "missing-codescene-cli",
                "XWALK_CODESCENE_REPORT_DIRECTORY": directory,
                "XWALK_CODESCENE_BASE_REVISION": baseline,
                "XWALK_CODESCENE_REVISION": revision,
                "XWALK_CODESCENE_STRICT": "true",
            }
            with mock.patch.dict(os.environ, environment, clear=False), \
                    mock.patch.object(
                        MODULE, "resolve_revision", side_effect=[revision, baseline]
                    ), \
                    mock.patch.object(
                        MODULE,
                        "changed_files",
                        return_value=["xWalk-rpi5-hw/xWalkHal/example.cpp"],
                    ):
                result = MODULE.analyze(self.root, self.configuration)
        self.assertEqual(result, 1)

    def test_cli_uses_official_user_install_location_outside_service_path(self) -> None:
        """Find the official CLI location used by a non-login CI service."""

        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            cli = home / ".local" / "bin" / "cs"
            cli.parent.mkdir(parents=True)
            cli.write_text("#!/bin/sh\n", encoding="utf-8")
            cli.chmod(0o700)
            with mock.patch.dict(
                os.environ, {"XWALK_CODESCENE_CLI": "cs"}, clear=False
            ), mock.patch.object(MODULE.shutil, "which", return_value=None), mock.patch.object(
                MODULE.Path, "home", return_value=home
            ):
                resolved = MODULE.configured_cli()

        self.assertEqual(resolved, str(cli.resolve()))

    def test_missing_cli_activation_is_reported_before_delta_execution(self) -> None:
        """Explain the missing licensed PAT without invoking an unauthenticated delta."""

        baseline = "a" * 40
        revision = "b" * 40
        with tempfile.TemporaryDirectory() as directory:
            environment = {
                "CS_ACCESS_TOKEN": "",
                "XWALK_CODESCENE_REPORT_DIRECTORY": directory,
                "XWALK_CODESCENE_BASE_REVISION": baseline,
                "XWALK_CODESCENE_REVISION": revision,
                "XWALK_CODESCENE_STRICT": "false",
            }
            with mock.patch.dict(os.environ, environment, clear=False), mock.patch.object(
                MODULE, "resolve_revision", side_effect=[revision, baseline]
            ), mock.patch.object(
                MODULE,
                "changed_files",
                return_value=["xWalk-rpi5-hw/xWalkHal/example.cpp"],
            ), mock.patch.object(
                MODULE, "configured_cli", return_value="/opt/cs"
            ), mock.patch.object(MODULE.subprocess, "run") as run:
                result = MODULE.analyze(self.root, self.configuration)
            summary = json.loads(
                (Path(directory) / "summary.json").read_text(encoding="utf-8")
            )

        self.assertEqual(result, 0)
        self.assertEqual(summary["status"], "UNAVAILABLE")
        self.assertIn("CS_ACCESS_TOKEN", summary["reason"])
        run.assert_not_called()

    def test_unsupported_component_history_is_reported_without_using_root_head(self) -> None:
        """Never substitute an unrelated integrated revision for a component patch set."""

        with tempfile.TemporaryDirectory() as directory:
            environment = {
                "GERRIT_PATCHSET_REVISION": "b" * 40,
                "XWALK_CODESCENE_REPORT_DIRECTORY": directory,
                "XWALK_CODESCENE_STRICT": "false",
                "XWALK_CODESCENE_UNAVAILABLE_REASON": "Component requires integrated history.",
            }
            with mock.patch.dict(os.environ, environment, clear=False):
                result = MODULE.analyze(self.root, self.configuration)
            summary = json.loads((Path(directory) / "summary.json").read_text(encoding="utf-8"))
        self.assertEqual(result, 0)
        self.assertEqual(summary["status"], "UNAVAILABLE")
        self.assertEqual(summary["revision"], "b" * 40)

    def test_metadata_only_change_passes_without_invoking_cli(self) -> None:
        """Ignore repository metadata outside the configured architectural components."""

        baseline = "a" * 40
        revision = "b" * 40
        with tempfile.TemporaryDirectory() as directory:
            environment = {
                "XWALK_CODESCENE_REPORT_DIRECTORY": directory,
                "XWALK_CODESCENE_BASE_REVISION": baseline,
                "XWALK_CODESCENE_REVISION": revision,
                "XWALK_CODESCENE_STRICT": "true",
            }
            with mock.patch.dict(os.environ, environment, clear=False), \
                    mock.patch.object(
                        MODULE, "resolve_revision", side_effect=[revision, baseline]
                    ), \
                    mock.patch.object(
                        MODULE,
                        "changed_files",
                        return_value=[".gitmodules", "xWalk-rpi5-hw/.gitmodules"],
                    ), \
                    mock.patch.object(MODULE, "configured_cli") as configured_cli:
                result = MODULE.analyze(self.root, self.configuration)
            summary = json.loads(
                (Path(directory) / "summary.json").read_text(encoding="utf-8")
            )

        self.assertEqual(result, 0)
        self.assertEqual(summary["status"], "PASSED")
        self.assertEqual(summary["changed_files_analysed"], 0)
        self.assertEqual(summary["components"], [])
        configured_cli.assert_not_called()

    def test_cli_receives_exact_base_and_revision_and_reports_degradation(self) -> None:
        """Use supported cs delta arguments and honor a returned degradation gate."""

        baseline = "a" * 40
        revision = "b" * 40
        response = {
            "view": "https://codescene.example.invalid/projects/1/delta/2",
            "result": {"quality-gates": {"degrades-in-code-health": True}},
        }
        completed = subprocess.CompletedProcess(
            ["cs"], returncode=0, stdout=json.dumps(response), stderr=""
        )

        with tempfile.TemporaryDirectory() as directory:
            environment = {
                "CS_ACCESS_TOKEN": "test-token",
                "XWALK_CODESCENE_REPORT_DIRECTORY": directory,
                "XWALK_CODESCENE_BASE_REVISION": baseline,
                "XWALK_CODESCENE_REVISION": revision,
                "XWALK_CODESCENE_STRICT": "true",
            }
            with mock.patch.dict(os.environ, environment, clear=False), \
                    mock.patch.object(
                        MODULE, "resolve_revision", side_effect=[revision, baseline]
                    ), \
                    mock.patch.object(
                        MODULE,
                        "changed_files",
                        return_value=["xWalk-rpi5-hw/xWalkHal/example.cpp"],
                    ), \
                    mock.patch.object(MODULE, "configured_cli", return_value="/opt/cs"), \
                    mock.patch.object(MODULE.subprocess, "run", return_value=completed) as run:
                result = MODULE.analyze(self.root, self.configuration)
            summary = json.loads(
                (Path(directory) / "summary.json").read_text(encoding="utf-8")
            )
        self.assertEqual(result, 1)
        self.assertEqual(summary["code_health_degradation"], "YES")
        self.assertEqual(summary["quality_gate"], "FAILED")
        command = next(
            call.args[0] for call in run.call_args_list if call.args[0][0] == "/opt/cs"
        )
        self.assertEqual(
            command, ["/opt/cs", "delta", "--output-format", "json", baseline, revision]
        )

    def test_successful_empty_cli_result_reports_no_new_findings(self) -> None:
        """Treat the CLI's successful empty JSON-mode response as a clean delta."""

        baseline = "a" * 40
        revision = "b" * 40
        completed = subprocess.CompletedProcess(
            ["cs"], returncode=0, stdout="", stderr=""
        )

        with tempfile.TemporaryDirectory() as directory:
            environment = {
                "CS_ACCESS_TOKEN": "test-token",
                "XWALK_CODESCENE_REPORT_DIRECTORY": directory,
                "XWALK_CODESCENE_BASE_REVISION": baseline,
                "XWALK_CODESCENE_REVISION": revision,
                "XWALK_CODESCENE_STRICT": "true",
            }
            with mock.patch.dict(os.environ, environment, clear=False), \
                    mock.patch.object(
                        MODULE, "resolve_revision", side_effect=[revision, baseline]
                    ), \
                    mock.patch.object(
                        MODULE,
                        "changed_files",
                        return_value=["devloper-note/README.md"],
                    ), \
                    mock.patch.object(MODULE, "configured_cli", return_value="/opt/cs"), \
                    mock.patch.object(MODULE.subprocess, "run", return_value=completed):
                result = MODULE.analyze(self.root, self.configuration)
            report = Path(directory)
            summary = json.loads((report / "summary.json").read_text(encoding="utf-8"))
            diagnostic = (report / "diagnostic.txt").read_text(encoding="utf-8")

        self.assertEqual(result, 0)
        self.assertEqual(summary["status"], "PASSED")
        self.assertEqual(summary["quality_gate"], "PASSED")
        self.assertEqual(summary["code_health_degradation"], "NO")
        self.assertIn("no new findings", summary["reason"])
        self.assertIn("exit_code=0", diagnostic)

    def test_failed_empty_cli_result_retains_diagnostic_metadata(self) -> None:
        """Keep an empty failed response unavailable and explain its exit status."""

        baseline = "a" * 40
        revision = "b" * 40
        completed = subprocess.CompletedProcess(
            ["cs"], returncode=1, stdout="", stderr=""
        )

        with tempfile.TemporaryDirectory() as directory:
            environment = {
                "CS_ACCESS_TOKEN": "test-token",
                "XWALK_CODESCENE_REPORT_DIRECTORY": directory,
                "XWALK_CODESCENE_BASE_REVISION": baseline,
                "XWALK_CODESCENE_REVISION": revision,
                "XWALK_CODESCENE_STRICT": "false",
            }
            with mock.patch.dict(os.environ, environment, clear=False), \
                    mock.patch.object(
                        MODULE, "resolve_revision", side_effect=[revision, baseline]
                    ), \
                    mock.patch.object(
                        MODULE,
                        "changed_files",
                        return_value=["xWalk-rpi5-hw/xWalkHal/example.cpp"],
                    ), \
                    mock.patch.object(MODULE, "configured_cli", return_value="/opt/cs"), \
                    mock.patch.object(MODULE.subprocess, "run", return_value=completed):
                result = MODULE.analyze(self.root, self.configuration)
            report = Path(directory)
            summary = json.loads((report / "summary.json").read_text(encoding="utf-8"))
            diagnostic = (report / "diagnostic.txt").read_text(encoding="utf-8")

        self.assertEqual(result, 0)
        self.assertEqual(summary["status"], "UNAVAILABLE")
        self.assertIn("malformed JSON", summary["reason"])
        self.assertIn("exit_code=1", diagnostic)
        self.assertIn("stdout_bytes=0", diagnostic)
        self.assertIn("stderr_bytes=0", diagnostic)

    def test_correlation_contains_identifiers_but_no_credentials(self) -> None:
        """Record review and mirror identifiers without capturing secret variables."""

        environment = {
            "GERRIT_CHANGE_NUMBER": "62",
            "GERRIT_PATCHSET_NUMBER": "3",
            "GERRIT_PATCHSET_REVISION": "a" * 40,
            "GERRIT_REFSPEC": "refs/changes/62/62/3",
            "CODESCENE_ACCESS_TOKEN": "must-not-be-recorded",
        }
        with mock.patch.dict(os.environ, environment, clear=True):
            result = MODULE.correlation()
        self.assertEqual(result["GERRIT_CHANGE_NUMBER"], "62")
        self.assertNotIn("CODESCENE_ACCESS_TOKEN", result)


if __name__ == "__main__":
    unittest.main()
