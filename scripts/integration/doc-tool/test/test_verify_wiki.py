#!/usr/bin/env python3
"""Tests for developer-note source and rendered-site verification."""

from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest


SCRIPT_DIRECTORY = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPT_DIRECTORY))

from verify_wiki import validate_rendered_links  # noqa: E402


class VerifyRenderedWikiTest(unittest.TestCase):
    """Verify generated links stay within the published Pages artifact."""

    def setUp(self) -> None:
        """Create a minimal rendered site."""

        self.temporary_directory = tempfile.TemporaryDirectory()
        self.site = Path(self.temporary_directory.name)
        (self.site / "guide").mkdir()
        (self.site / "asset.css").write_text("body {}\n", encoding="utf-8")

    def tearDown(self) -> None:
        """Remove the rendered-site fixture."""

        self.temporary_directory.cleanup()

    def test_accepts_existing_internal_and_external_links(self) -> None:
        """Accept generated targets present in the artifact or hosted elsewhere."""

        (self.site / "guide" / "index.html").write_text(
            '<a href="../">Home</a><link href="../asset.css"><a href="https://github.com/">Source</a>\n',
            encoding="utf-8",
        )
        (self.site / "index.html").write_text('<a href="guide/">Guide</a>\n', encoding="utf-8")

        findings = validate_rendered_links(self.site, "https://example.github.io/project/")

        self.assertEqual(findings, [])

    def test_reports_missing_internal_target(self) -> None:
        """Reject a generated same-site link absent from the artifact."""

        (self.site / "index.html").write_text('<a href="missing/">Missing</a>\n', encoding="utf-8")

        findings = validate_rendered_links(self.site, "https://example.github.io/project/")

        self.assertEqual(findings, ["index.html:1: missing rendered target: missing/"])


if __name__ == "__main__":
    unittest.main()
