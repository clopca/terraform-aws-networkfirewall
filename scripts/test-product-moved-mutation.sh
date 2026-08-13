#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
moved_file="$repo_root/moved.tf"
backup="$(mktemp /tmp/nfw-product-moved.XXXXXX)"
log_file="$(mktemp /tmp/nfw-product-moved-test.XXXXXX)"
cp "$moved_file" "$backup"
trap 'cp "$backup" "$moved_file"' EXIT

block_count="$(python3 - "$moved_file" <<'PY'
from pathlib import Path
import sys
text = Path(sys.argv[1]).read_text()
count = 0
depth = 0
for line in text.splitlines():
    stripped = line.strip()
    if depth == 0 and stripped.startswith("moved {"):
        count += 1
    depth += line.count("{") - line.count("}")
print(count)
PY
)"

if [[ "$block_count" -eq 0 ]]; then
  echo "product moved mutation guard found no moved blocks" >&2
  exit 1
fi

for ((index = 0; index < block_count; index++)); do
  python3 - "$backup" "$moved_file" "$index" <<'PY'
from pathlib import Path
import sys
source, target, remove_index = Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3])
lines = source.read_text().splitlines(keepends=True)
result = []
depth = 0
inside = False
current = -1
for line in lines:
    if not inside and depth == 0 and line.strip().startswith("moved {"):
        current += 1
        inside = True
    depth += line.count("{") - line.count("}")
    if current != remove_index or not inside:
        result.append(line)
    if inside and depth == 0:
        inside = False
target.write_text("".join(result))
PY

  if terraform -chdir="$repo_root" test -no-color -filter=tests/product_moved.tftest.hcl >"$log_file" 2>&1; then
    echo "product moved mutation guard: deleting moved block $index left the migration suite green" >&2
    cat "$log_file" >&2
    exit 1
  fi
  cp "$backup" "$moved_file"
done

echo "Product moved mutation guard passed ($block_count moved block(s) independently required)"
