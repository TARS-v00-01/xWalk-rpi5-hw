#!/usr/bin/env python3
"""Verify the xWalk C++ decision-condition source check."""

from __future__ import annotations

from pathlib import Path
import subprocess
import tempfile
import unittest


TOOL = Path(__file__).parents[1] / "xWalkConditionCheck"


class XWalkConditionCheckTest(unittest.TestCase):
    """Exercise accepted variables, rejected calls, and excluded source trees."""

    def setUp(self) -> None:
        """Create one isolated source tree."""

        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)

    def tearDown(self) -> None:
        """Remove the isolated source tree."""

        self.temporary_directory.cleanup()

    def run_check(self) -> subprocess.CompletedProcess[str]:
        """Run the condition checker against the isolated source tree."""

        return subprocess.run(
            ["python3", str(TOOL), str(self.root)],
            check=False,
            capture_output=True,
            text=True,
        )

    def write(self, relative_path: str, contents: str) -> None:
        """Write one source fixture below the temporary root."""

        path = self.root / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents, encoding="utf-8")

    def test_named_boolean_conditions_pass(self) -> None:
        """Accept conditions composed only from values and operators."""

        self.write(
            "source/good.cpp",
            "bool run(bool ready)\n{\n    if (ready == false)\n    {\n        return false;\n    }\n"
            "    while (ready)\n    {\n        ready = false;\n    }\n    return true;\n}\n",
        )
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        self.assertIn("violations=0", result.stdout)

    def test_function_member_and_macro_calls_fail(self) -> None:
        """Reject multiline functions, member queries, and function-like macros."""

        self.write(
            "source/bad.cpp",
            "bool ready();\nvoid run(Value value)\n{\n    if (\n        ready())\n    {\n    }\n"
            "    if (value.empty())\n    {\n    }\n    while (CHECK_READY(value))\n    {\n    }\n}\n",
        )
        result = self.run_check()
        self.assertEqual(result.returncode, 1, result.stderr + result.stdout)
        self.assertIn("invokes ready", result.stdout)
        self.assertIn("invokes empty", result.stdout)
        self.assertIn("invokes CHECK_READY", result.stdout)

    def test_generated_and_build_sources_are_excluded(self) -> None:
        """Ignore generated output, dependency trees, and build directories."""

        self.write("generated/bad.cpp", "void run() { if (ready()) {} }\n")
        self.write("build-host/bad.cpp", "void run() { if (ready()) {} }\n")
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)


if __name__ == "__main__":
    unittest.main()
