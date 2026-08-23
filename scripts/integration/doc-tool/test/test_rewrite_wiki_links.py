#!/usr/bin/env python3
"""Tests for staged developer-note repository-link rewriting."""

from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest


SCRIPT_DIRECTORY = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPT_DIRECTORY))

from rewrite_wiki_links import rewrite_staged_links  # noqa: E402


class RewriteWikiLinksTest(unittest.TestCase):
    """Verify repository links become stable GitHub source links."""

    def setUp(self) -> None:
        """Create a minimal repository, documentation tree, and staged copy."""

        self.temporary_directory = tempfile.TemporaryDirectory()
        self.repository = Path(self.temporary_directory.name)
        self.documentation = self.repository / "devloper-note"
        self.staged = self.repository / "build" / "docs"
        (self.documentation / "guide").mkdir(parents=True)
        (self.staged / "guide").mkdir(parents=True)
        (self.repository / "module").mkdir()
        (self.repository / "module" / "README.md").write_text("# Module\n", encoding="utf-8")
        (self.documentation / "guide" / "local.md").write_text("# Local\n", encoding="utf-8")

    def tearDown(self) -> None:
        """Remove the temporary test repository."""

        self.temporary_directory.cleanup()

    def test_rewrites_repository_file_and_preserves_other_links(self) -> None:
        """Convert repository targets while retaining wiki and external links."""

        source_text = (
            "[module](../../module/README.md#usage)\n"
            "[local](local.md)\n"
            "[external](https://example.com/)\n"
        )
        source_file = self.documentation / "guide" / "index.md"
        staged_file = self.staged / "guide" / "index.md"
        source_file.write_text(source_text, encoding="utf-8")
        staged_file.write_text(source_text, encoding="utf-8")

        replacements, findings = rewrite_staged_links(
            self.repository,
            self.documentation,
            self.staged,
            "https://github.com/example/project",
            "test revision",
        )

        rewritten_text = staged_file.read_text(encoding="utf-8")
        self.assertEqual(replacements, 1)
        self.assertEqual(findings, [])
        self.assertIn(
            "https://github.com/example/project/blob/test%20revision/module/README.md#usage",
            rewritten_text,
        )
        self.assertIn("[local](local.md)", rewritten_text)
        self.assertIn("[external](https://example.com/)", rewritten_text)
        self.assertEqual(source_file.read_text(encoding="utf-8"), source_text)

    def test_reports_missing_repository_target(self) -> None:
        """Reject a repository-relative link whose destination does not exist."""

        source_text = "[missing](../../module/missing.md)\n"
        source_file = self.documentation / "guide" / "index.md"
        staged_file = self.staged / "guide" / "index.md"
        source_file.write_text(source_text, encoding="utf-8")
        staged_file.write_text(source_text, encoding="utf-8")

        replacements, findings = rewrite_staged_links(
            self.repository,
            self.documentation,
            self.staged,
            "https://github.com/example/project",
            "main",
        )

        self.assertEqual(replacements, 0)
        self.assertEqual(
            findings,
            ["devloper-note/guide/index.md: missing repository target: ../../module/missing.md"],
        )
        self.assertEqual(staged_file.read_text(encoding="utf-8"), source_text)


if __name__ == "__main__":
    unittest.main()
