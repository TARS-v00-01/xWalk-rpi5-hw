#!/usr/bin/env python3
"""Verify safe C++ formatting and validation through xWalkStyler."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


TOOL = Path(__file__).parents[1] / "xWalkStyler"
FORMATTED = """namespace xWalk
{
    class MotorController
    {
        public:
            void stop()
            {
            }
    };
}
"""


class XWalkStylerTest(unittest.TestCase):
    """Exercise file, directory, dependency, and exit-status behavior."""

    def setUp(self) -> None:
        """Create one isolated source tree outside the repository style hierarchy."""

        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)

    def tearDown(self) -> None:
        """Remove the isolated source tree."""

        self.temporary_directory.cleanup()

    def run_styler(
        self, *arguments: str, environment: dict[str, str] | None = None
    ) -> subprocess.CompletedProcess[str]:
        """Run xWalkStyler and retain text output without raising."""

        merged_environment = os.environ.copy()
        if environment is not None:
            merged_environment.update(environment)
        return subprocess.run(
            [str(TOOL), *arguments],
            check=False,
            capture_output=True,
            text=True,
            env=merged_environment,
        )

    def write(self, relative: str, contents: str) -> Path:
        """Create one test source file and return its path."""

        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")
        return path

    def test_correctly_formatted_cpp_passes_without_modification(self) -> None:
        """Accept the mandatory Allman and indentation style."""

        source = self.write("Motor Controller.cpp", FORMATTED)
        before = source.read_bytes()
        result = self.run_styler("check-file", str(source))
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertEqual(source.read_bytes(), before)
        self.assertIn("discovered=1 processed=1 passed=1 failed=0", result.stdout)

    def test_incorrect_brace_placement_fails_then_formats_in_place(self) -> None:
        """Reject attached braces and rewrite them with the format command."""

        source = self.write("brace.cpp", "int main() { return 0; }\n")
        failed = self.run_styler("check-file", str(source))
        formatted = self.run_styler("format-file", str(source))
        passed = self.run_styler("check-file", str(source))
        self.assertNotEqual(failed.returncode, 0)
        self.assertEqual(formatted.returncode, 0, formatted.stderr + formatted.stdout)
        self.assertEqual(passed.returncode, 0, passed.stderr + passed.stdout)
        self.assertIn("int main()\n{\n    return 0;\n}", source.read_text(encoding="utf-8"))

    def test_incorrect_indentation_is_reported(self) -> None:
        """Reject block contents that do not use four spaces."""

        source = self.write("indent.cc", "int main()\n{\n  return 0;\n}\n")
        result = self.run_styler("check-file", str(source))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(f"FAIL {source}", result.stdout)

    def test_line_exceeding_120_characters_is_reported(self) -> None:
        """Reject an unbreakable token longer than the configured column limit."""

        source = self.write("long.hxx", f"// {'x' * 121}\n")
        result = self.run_styler("check-file", str(source))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("failed=1", result.stdout)

    def test_directory_discovery_excludes_generated_and_external_trees(self) -> None:
        """Ignore every configured build, dependency, vendor, and generated directory."""

        self.write("source/good.hpp", FORMATTED)
        for directory in (
            ".git", "build", "Build", "build-host", "cmake-build-debug",
            "third_party", "external", "vendor", "auto-gen", "generated",
        ):
            self.write(f"{directory}/bad.cpp", "int main() { return 0; }\n")
        result = self.run_styler("check", str(self.root))
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("discovered=1 processed=1 passed=1 failed=0", result.stdout)

    def test_filename_containing_spaces_can_be_formatted(self) -> None:
        """Preserve one path as a single argument through formatting and checking."""

        source = self.write("directory with spaces/source file.cxx", "void run(){return;}\n")
        formatted = self.run_styler("format-file", str(source))
        checked = self.run_styler("check-file", str(source))
        self.assertEqual(formatted.returncode, 0, formatted.stderr + formatted.stdout)
        self.assertEqual(checked.returncode, 0, checked.stderr + checked.stdout)

    def test_missing_clang_format_has_clear_dependency_error(self) -> None:
        """Fail before discovery when the configured executable is unavailable."""

        result = self.run_styler(
            "check", str(self.root), environment={"XWALK_CLANG_FORMAT": "missing-xwalk-clang-format"}
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("clang-format is unavailable", result.stderr)

    def test_directory_exit_code_reflects_mixed_success_and_failure(self) -> None:
        """Return nonzero and count every discovered file when any source fails."""

        self.write("good.h", FORMATTED)
        bad = self.write("bad.h", "class Bad{};\n")
        result = self.run_styler("check", str(self.root))
        self.assertEqual(result.returncode, 1)
        self.assertIn(f"FAIL {bad}", result.stdout)
        self.assertIn("discovered=2 processed=2 passed=1 failed=1", result.stdout)

    @unittest.skipUnless(shutil.which("clang-format"), "clang-format is required")
    def test_invalid_input_path_returns_usage_error(self) -> None:
        """Reject a nonexistent path without passing it to clang-format."""

        result = self.run_styler("check-file", str(self.root / "missing.cpp"))
        self.assertEqual(result.returncode, 2)
        self.assertIn("file does not exist", result.stderr)


if __name__ == "__main__":
    unittest.main()
