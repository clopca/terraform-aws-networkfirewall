#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$repo_root" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
public_files = [*root.glob("*.tf"), *root.glob("modules/**/*.tf")]
checks = {
    r"\btype\s*=\s*any\b": "Public contracts must not use type = any",
    r"\bcount\s*=": "Public resources and modules must use caller keys, not count",
}
failures = []
for path in sorted(public_files):
    text = path.read_text()
    for pattern, message in checks.items():
        for match in re.finditer(pattern, text):
            line = text.count("\n", 0, match.start()) + 1
            failures.append(f"{path.relative_to(root)}:{line}: {message}")

published_files = [root / "README.md", *root.glob("docs/**/*.md"), *root.glob("modules/**/README.md")]
internal_label = re.compile(r"\[(?:Finding|Audit|R[0-9]+[-_])[^]]*\]", re.IGNORECASE)
for path in published_files:
    if not path.exists():
        continue
    for match in internal_label.finditer(path.read_text()):
        line = path.read_text().count("\n", 0, match.start()) + 1
        failures.append(f"{path.relative_to(root)}:{line}: internal audit label is not publishable")

if failures:
    raise SystemExit("\n".join(failures))
print(f"Public contract guard passed ({len(public_files)} Terraform files checked)")
PY
