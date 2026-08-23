#!/usr/bin/env python3
"""Rewrite staged wiki links to tracked repository files as GitHub source URLs."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
from urllib.parse import quote, urlsplit, urlunsplit

from verify_wiki import MARKDOWN_LINK, local_target


def parse_arguments() -> argparse.Namespace:
    """Parse repository, documentation, staging, and GitHub source arguments."""

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("repository_root", type=Path)
    parser.add_argument("documentation_root", type=Path)
    parser.add_argument("staged_root", type=Path)
    parser.add_argument("repository_url")
    parser.add_argument("revision")
    return parser.parse_args()


def source_file_for(
    staged_file: Path,
    staged_root: Path,
    documentation_root: Path,
) -> Path:
    """Return the source Markdown file corresponding to one staged page."""

    relative_file = staged_file.relative_to(staged_root)
    if relative_file == Path("wiki-tool/index.md"):
        return documentation_root / "README.md"
    return documentation_root / relative_file


def repository_target_url(
    resolved_target: Path,
    repository_root: Path,
    repository_url: str,
    revision: str,
    query: str,
    fragment: str,
) -> str:
    """Build a GitHub source URL for one tracked file or directory."""

    target_kind = "tree" if resolved_target.is_dir() else "blob"
    relative_target = resolved_target.relative_to(repository_root).as_posix()
    encoded_revision = quote(revision, safe="")
    encoded_target = quote(relative_target, safe="/")
    repository = urlsplit(repository_url)
    path = f"{repository.path.rstrip('/')}/{target_kind}/{encoded_revision}/{encoded_target}"
    return urlunsplit((repository.scheme, repository.netloc, path, query, fragment))


def rewrite_markdown(
    text: str,
    source_file: Path,
    repository_root: Path,
    documentation_root: Path,
    repository_url: str,
    revision: str,
) -> tuple[str, int, list[str]]:
    """Rewrite repository-owned targets in one staged Markdown document."""

    replacements = 0
    findings: list[str] = []

    def replace_match(match: re.Match[str]) -> str:
        nonlocal replacements

        raw_match = match.group(0)
        raw_target = match.group("target")
        target = local_target(raw_target)
        if target is None:
            return raw_match

        parsed_target = urlsplit(raw_target.removeprefix("<").removesuffix(">"))
        resolved_target = (source_file.parent / target).resolve(strict=False)
        if resolved_target.is_relative_to(documentation_root):
            return raw_match
        if not resolved_target.is_relative_to(repository_root):
            findings.append(f"target leaves the repository: {target}")
            return raw_match
        if not resolved_target.exists():
            findings.append(f"missing repository target: {target}")
            return raw_match

        replacement_target = repository_target_url(
            resolved_target,
            repository_root,
            repository_url,
            revision,
            parsed_target.query,
            parsed_target.fragment,
        )
        target_start = match.start("target") - match.start(0)
        target_end = match.end("target") - match.start(0)
        replacements += 1
        return f"{raw_match[:target_start]}{replacement_target}{raw_match[target_end:]}"

    rewritten_text = MARKDOWN_LINK.sub(replace_match, text)
    return rewritten_text, replacements, findings


def rewrite_staged_links(
    repository_root: Path,
    documentation_root: Path,
    staged_root: Path,
    repository_url: str,
    revision: str,
) -> tuple[int, list[str]]:
    """Rewrite every staged link that resolves outside the documentation tree."""

    repository = repository_root.resolve(strict=True)
    documentation = documentation_root.resolve(strict=True)
    staged = staged_root.resolve(strict=True)
    replacements = 0
    findings: list[str] = []

    for staged_file in sorted(staged.rglob("*.md")):
        source_file = source_file_for(staged_file, staged, documentation)
        rewritten_text, file_replacements, file_findings = rewrite_markdown(
            staged_file.read_text(encoding="utf-8"),
            source_file,
            repository,
            documentation,
            repository_url,
            revision,
        )
        if file_findings:
            relative_file = source_file.relative_to(repository)
            findings.extend(f"{relative_file}: {finding}" for finding in file_findings)
            continue
        if file_replacements > 0:
            staged_file.write_text(rewritten_text, encoding="utf-8")
            replacements += file_replacements

    return replacements, findings


def main() -> int:
    """Rewrite staged repository links and return a CI-friendly status."""

    arguments = parse_arguments()
    replacements, findings = rewrite_staged_links(
        arguments.repository_root,
        arguments.documentation_root,
        arguments.staged_root,
        arguments.repository_url,
        arguments.revision,
    )
    if findings:
        for finding in findings:
            print(f"ERROR: {finding}")
        return 1
    print(f"Rewrote {replacements} staged repository links")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
