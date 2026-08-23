#!/usr/bin/env python3
"""Validate links owned by the developer-note source tree for the documentation tool."""

from __future__ import annotations

import argparse
from html.parser import HTMLParser
from pathlib import Path
import re
from urllib.parse import unquote, urljoin, urlsplit


MARKDOWN_LINK = re.compile(
    r"!?\[[^\]]*\]\((?P<target><[^>]+>|[^)\s]+)(?:\s+['\"][^)]*['\"])?\)"
)


class RenderedLinkParser(HTMLParser):
    """Collect navigation and asset targets from rendered HTML."""

    def __init__(self) -> None:
        """Initialize an empty target collection."""

        super().__init__()
        self.targets: list[tuple[int, str]] = []

    def handle_starttag(self, tag: str, attributes: list[tuple[str, str | None]]) -> None:
        """Collect non-empty href and src attribute values."""

        del tag
        line_number, _ = self.getpos()
        for name, value in attributes:
            if name in {"href", "src"} and value:
                self.targets.append((line_number, value))


def parse_arguments() -> argparse.Namespace:
    """Parse source and optional rendered-site validation arguments."""

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_root", type=Path)
    parser.add_argument("--site-root", type=Path)
    parser.add_argument("--site-url")
    arguments = parser.parse_args()
    if (arguments.site_root is None) != (arguments.site_url is None):
        parser.error("--site-root and --site-url must be provided together")
    return arguments


def local_target(raw_target: str) -> str | None:
    """Return a decoded local path, excluding external and same-page targets."""

    target = raw_target.removeprefix("<").removesuffix(">")
    parsed = urlsplit(target)
    if parsed.scheme or parsed.netloc or not parsed.path:
        return None
    return unquote(parsed.path)


def validate_links(source_root: Path) -> list[str]:
    """Report missing targets that resolve inside the wiki-owned source tree."""

    root = source_root.resolve(strict=True)
    findings: list[str] = []
    for markdown_file in sorted(root.rglob("*.md")):
        text = markdown_file.read_text(encoding="utf-8")
        for line_number, line in enumerate(text.splitlines(), start=1):
            for match in MARKDOWN_LINK.finditer(line):
                target = local_target(match.group("target"))
                if target is None:
                    continue
                resolved = (markdown_file.parent / target).resolve(strict=False)
                if not resolved.is_relative_to(root):
                    continue
                if not resolved.exists():
                    relative_file = markdown_file.relative_to(root)
                    findings.append(f"{relative_file}:{line_number}: missing local target: {target}")
    return findings


def rendered_target_path(site_root: Path, site_url: str, page_url: str, raw_target: str) -> Path | None:
    """Resolve a rendered same-site target to its expected artifact path."""

    site = urlsplit(site_url)
    resolved = urlsplit(urljoin(page_url, raw_target))
    if resolved.scheme not in {"http", "https"} or resolved.netloc != site.netloc:
        return None

    base_path = site.path.rstrip("/") + "/"
    if not resolved.path.startswith(base_path):
        return None
    relative_target = unquote(resolved.path[len(base_path) :])
    target_path = (site_root / relative_target).resolve(strict=False)
    if not target_path.is_relative_to(site_root):
        return target_path
    if resolved.path.endswith("/"):
        return target_path / "index.html"
    if target_path.is_dir():
        return target_path / "index.html"
    return target_path


def validate_rendered_links(site_root: Path, site_url: str) -> list[str]:
    """Report same-site links and assets absent from the generated artifact."""

    root = site_root.resolve(strict=True)
    findings: list[str] = []
    for html_file in sorted(root.rglob("*.html")):
        parser = RenderedLinkParser()
        parser.feed(html_file.read_text(encoding="utf-8"))
        relative_file = html_file.relative_to(root)
        page_url = urljoin(site_url.rstrip("/") + "/", relative_file.as_posix())
        for line_number, raw_target in parser.targets:
            target_path = rendered_target_path(root, site_url, page_url, raw_target)
            if target_path is None:
                continue
            if not target_path.is_relative_to(root):
                findings.append(f"{relative_file}:{line_number}: rendered target leaves site: {raw_target}")
            elif not target_path.exists():
                findings.append(f"{relative_file}:{line_number}: missing rendered target: {raw_target}")
    return findings


def main() -> int:
    """Validate the requested wiki source tree and return a CI-friendly status."""

    arguments = parse_arguments()
    findings = validate_links(arguments.source_root)
    if arguments.site_root is not None:
        findings.extend(validate_rendered_links(arguments.site_root, arguments.site_url))
    if findings:
        for finding in findings:
            print(f"ERROR: {finding}")
        return 1
    print("Wiki-owned Markdown and rendered-site links are valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
