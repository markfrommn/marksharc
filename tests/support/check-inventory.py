#!/usr/bin/env python3
"""Verify the contract inventory in tests/README.md.

Checks:
  1. Every listed spec path resolves to an existing regular file (no missing
     files, directories, or <name>/glob placeholders).
  2. Every public module under modules/ is represented in the inventory.
  3. Coverage (rows with at least one existing spec file / total behaviour rows)
     meets or exceeds --min-coverage (default 90%).
"""
import argparse
import os
import re
import sys


UNCOVERED_MARKERS = {"", "-", "—", "--", "none", "tbd", "uncovered"}


def split_row(line):
    inner = line.strip()
    if inner.startswith("|"):
        inner = inner[1:]
    if inner.endswith("|"):
        inner = inner[:-1]
    return [cell.strip() for cell in re.split(r"(?<!\\)\|", inner)]


def parse_inventory(readme_path):
    with open(readme_path, encoding="utf-8") as fh:
        text = fh.read()

    match = re.search(r"^##\s+Contract inventory\s*$", text, re.MULTILINE)
    if not match:
        raise ValueError(f"{readme_path}: missing '## Contract inventory' section")

    section = text[match.end():]
    next_heading = re.search(r"^##\s+", section, re.MULTILINE)
    if next_heading:
        section = section[:next_heading.start()]

    rows = []
    in_table = False
    for lineno_offset, line in enumerate(section.splitlines(), start=1):
        stripped = line.strip()
        if not stripped.startswith("|"):
            if in_table and rows:
                break
            continue
        cells = split_row(stripped)
        if len(cells) < 3:
            continue
        if cells[0].lower() in ("area", "module") and cells[1].lower() in ("behaviour", "behavior"):
            in_table = True
            continue
        if all(set(c.replace(":", "").replace("-", "").strip()) == set() for c in cells[:3]):
            in_table = True
            continue
        if in_table:
            rows.append((lineno_offset, cells[0], cells[1], cells[2]))

    if not rows:
        raise ValueError(f"{readme_path}: Contract inventory table has no rows")
    return rows


def resolve_spec(spec_ref, tests_dir, repo_root):
    if any(ch in spec_ref for ch in ("<", ">", "*", "?")):
        return None, f"wildcard/placeholder not allowed: {spec_ref}"

    for base in (tests_dir, repo_root):
        cand = os.path.join(base, spec_ref)
        if os.path.isfile(cand):
            return os.path.normpath(cand), None
        if os.path.isdir(cand):
            return None, f"path is a directory, not a file: {spec_ref}"
    return None, f"missing spec file: {spec_ref}"


def extract_area_tokens(area):
    tokens = set()
    for part in area.split(","):
        cleaned = re.sub(r"\([^)]*\)", "", part).strip()
        cleaned = cleaned.strip("`").strip()
        if cleaned:
            tokens.add(cleaned)
    return tokens


def main(argv=None):
    parser = argparse.ArgumentParser(description="Validate tests/README.md contract inventory")
    default_tests = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    default_root = os.path.abspath(os.path.join(default_tests, ".."))
    parser.add_argument("--readme", default=os.path.join(default_tests, "README.md"))
    parser.add_argument("--modules-dir", default=os.path.join(default_root, "modules"))
    parser.add_argument("--tests-dir", default=default_tests)
    parser.add_argument("--repo-root", default=default_root)
    parser.add_argument("--min-coverage", type=float, default=90.0)
    args = parser.parse_args(argv)

    errors = []
    try:
        rows = parse_inventory(args.readme)
    except (OSError, ValueError) as exc:
        print(f"inventory: {exc}", file=sys.stderr)
        return 1

    covered = 0
    unique_files = set()
    covered_areas = set()

    for idx, area, behaviour, spec_col in rows:
        if not behaviour:
            errors.append(f"row {idx} ({area}): empty behaviour description")
            continue

        covered_areas.update(extract_area_tokens(area))
        raw_spec = spec_col.strip()
        refs = re.findall(r"`([^`]+)`", raw_spec)

        if not refs:
            if raw_spec.lower() in UNCOVERED_MARKERS:
                continue
            errors.append(f"row {idx} ({area}): spec column must list backtick-quoted files or '—': {raw_spec!r}")
            continue

        remainder = re.sub(r"`[^`]+`", "", raw_spec).replace(",", "").strip()
        if remainder:
            errors.append(f"row {idx} ({area}): unquoted text in spec column: {remainder!r}")
            continue

        row_valid_files = 0
        for ref in refs:
            resolved, err = resolve_spec(ref, args.tests_dir, args.repo_root)
            if err:
                errors.append(f"row {idx} ({area}): {err}")
            else:
                unique_files.add(os.path.realpath(resolved))
                row_valid_files += 1

        if row_valid_files == len(refs) and row_valid_files > 0:
            covered += 1

    if not os.path.isdir(args.modules_dir):
        errors.append(f"modules directory not found: {args.modules_dir}")
        modules = []
    else:
        modules = sorted(
            d for d in os.listdir(args.modules_dir)
            if os.path.isdir(os.path.join(args.modules_dir, d)) and not d.startswith(".")
        )
        missing_modules = [m for m in modules if m not in covered_areas]
        for mod in missing_modules:
            errors.append(f"module not listed in contract inventory: {mod}")

    total = len(rows)
    pct = (covered / total * 100.0) if total else 0.0
    if pct < args.min_coverage:
        errors.append(
            f"coverage {pct:.1f}% ({covered}/{total}) is below required {args.min_coverage:.1f}%"
        )

    if errors:
        for err in errors:
            print(f"inventory: {err}", file=sys.stderr)
        return 1

    print(
        f"inventory: ok ({covered}/{total} behaviours covered, {pct:.1f}%; "
        f"{len(modules)}/{len(modules)} modules; {len(unique_files)} spec files)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
