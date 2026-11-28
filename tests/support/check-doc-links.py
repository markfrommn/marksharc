#!/usr/bin/env python3
"""Check relative Markdown links in the documentation.

For every inline link or image in the checked files, the target file must exist
under the repository, and a #fragment into a Markdown file must match one of
that file's headings (GitHub's anchor rules) or an explicit <a id="..."> anchor.
External links (with a scheme) are not fetched.

Usage: check-doc-links.py [--root DIR] [FILE ...]

With no FILE, checks README.md, CHANGELOG.md, docs/*.md, specs/*.md,
specs/archive/*.md, tests/README.md and templates/overlay/README.md.
"""

import argparse
import glob
import os
import re
import sys
import urllib.parse

DEFAULT_GLOBS = (
    "README.md",
    "CHANGELOG.md",
    "docs/*.md",
    "specs/*.md",
    "specs/archive/*.md",
    "tests/README.md",
    "templates/overlay/README.md",
)
# Rendered locally by the workflow tool and never committed.
SKIP = {"docs/COMMON-WORKFLOW.md"}

FENCE = re.compile(r"^\s*(```|~~~)")
INLINE_CODE = re.compile(r"`[^`\n]*`")
LINK = re.compile(r"!?\[(?:[^\]\[]|\[[^\]]*\])*\]\(\s*(<[^>]*>|[^)\s]*)(?:\s+\"[^\"]*\")?\s*\)")
HEADING = re.compile(r"^ {0,3}(#{1,6})\s+(.*?)\s*#*\s*$")
EXPLICIT_ANCHOR = re.compile(r"<a\s+(?:id|name)=\"([^\"]+)\"")
SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")
MD_LINK_TEXT = re.compile(r"!?\[([^\]]*)\]\([^)]*\)")


def prose_lines(path):
    """Yield (line_number, text) for lines outside fenced code blocks."""
    fence = None
    with open(path, encoding="utf-8") as handle:
        for number, line in enumerate(handle, 1):
            match = FENCE.match(line)
            if match:
                marker = match.group(1)
                if fence is None:
                    fence = marker
                elif fence == marker:
                    fence = None
                continue
            if fence is None:
                yield number, line.rstrip("\n")


def slug(text):
    """GitHub's heading anchor: lower-case, drop punctuation, spaces to hyphens."""
    text = MD_LINK_TEXT.sub(r"\1", text)
    text = text.replace("`", "").lower()
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


def anchors(path, cache={}):
    if path in cache:
        return cache[path]
    found = set()
    counts = {}
    for _, line in prose_lines(path):
        found.update(EXPLICIT_ANCHOR.findall(line))
        match = HEADING.match(line)
        if not match:
            continue
        base = slug(match.group(2))
        seen = counts.get(base, 0)
        counts[base] = seen + 1
        found.add(base if seen == 0 else f"{base}-{seen}")
    cache[path] = found
    return found


def check_file(root, relative):
    errors = []
    count = 0
    path = os.path.join(root, relative)
    for number, line in prose_lines(path):
        for match in LINK.finditer(INLINE_CODE.sub("", line)):
            target = match.group(1).strip("<>")
            if not target or SCHEME.match(target):
                continue
            count += 1
            file_part, _, fragment = target.partition("#")
            file_part = urllib.parse.unquote(file_part)
            if file_part:
                resolved = os.path.normpath(os.path.join(os.path.dirname(path), file_part))
            else:
                resolved = path
            inside = os.path.commonpath([os.path.realpath(root), os.path.realpath(resolved)]) == os.path.realpath(root)
            if not inside:
                errors.append(f"{relative}:{number}: link leaves the repository: {target}")
                continue
            if not os.path.exists(resolved):
                errors.append(f"{relative}:{number}: missing file: {target}")
                continue
            if fragment and resolved.endswith(".md") and os.path.isfile(resolved):
                if urllib.parse.unquote(fragment) not in anchors(resolved):
                    errors.append(f"{relative}:{number}: missing anchor: {target}")
    return count, errors


def main():
    parser = argparse.ArgumentParser(description="Check relative Markdown links.")
    default_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    parser.add_argument("--root", default=default_root)
    parser.add_argument("files", nargs="*")
    args = parser.parse_args()
    root = os.path.abspath(args.root)

    if args.files:
        files = args.files
    else:
        files = []
        for pattern in DEFAULT_GLOBS:
            for found in sorted(glob.glob(os.path.join(root, pattern))):
                relative = os.path.relpath(found, root)
                if relative not in SKIP:
                    files.append(relative)
    if not files:
        print("links: no Markdown files found", file=sys.stderr)
        return 1

    total = 0
    errors = []
    for relative in files:
        if not os.path.isfile(os.path.join(root, relative)):
            errors.append(f"{relative}: file not found")
            continue
        count, found = check_file(root, relative)
        total += count
        errors.extend(found)

    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        print(f"links: {len(errors)} broken link(s)", file=sys.stderr)
        return 1
    print(f"links: ok ({total} relative links in {len(files)} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
