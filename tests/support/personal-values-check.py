#!/usr/bin/env python3
"""Check the portable zsh boundary without printing matched contents."""
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
rules = {
    "personal-home": re.compile(r"(?:/users/|/home/mark(?:/|\b)|/data/mark(?:/|\b)|~/?mark(?:/|\b))", re.I),
    "personal-work": re.compile(r"/data/work(?:/|\b)", re.I),
    "personal-name": re.compile(r"markfrommn|mgooderum|convoy|plesk|phorn|site-bac|beechaeroclub|psols|markmbm5|\bmark\b|\bgooderum\b|\bsol\b|\bjumpweb\.net\b|\bpowderhorns\.biz\b|\bbacweb\b|\bbacuser\b", re.I),
}
paths = [root / "core", root / "modules", root / "templates"]
failed = False
for boundary in paths:
    candidates = [boundary]
    if boundary.is_dir():
        candidates += sorted(boundary.rglob("*"))
    for path in candidates:
        if path.is_symlink():
            print(f"{path.relative_to(root)}: unsupported-symlink")
            failed = True
            continue
        if not path.exists():
            continue
        content = path.read_text(errors="replace") if path.is_file() else ""
        relative = str(path.relative_to(root))
        for name, pattern in rules.items():
            if pattern.search(relative) or pattern.search(content):
                print(f"{relative}: {name}")
                failed = True
sys.exit(1 if failed else 0)
