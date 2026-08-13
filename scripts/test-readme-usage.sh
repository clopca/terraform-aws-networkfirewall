#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readme="${repo_root}/README.md"
smoke_dir="$(mktemp -d "${TMPDIR:-/tmp}/networkfirewall-readme.XXXXXX")"
cleanup() {
  rm -rf "${smoke_dir}"
}
trap cleanup EXIT

python3 - "${readme}" "${smoke_dir}/main.tf" "${repo_root}" <<'PY'
from pathlib import Path
import json
import re
import sys

readme = Path(sys.argv[1]).read_text()
out = Path(sys.argv[2])
repo_root = Path(sys.argv[3]).resolve()

section = re.search(
    r"^## Quick start\s*$\n(?P<body>.*?)(?=^##\s|\Z)",
    readme,
    flags=re.MULTILINE | re.DOTALL,
)
if section is None:
    raise SystemExit("README is missing the '## Quick start' section")

fence = re.search(r"^```hcl\s*$\n(?P<hcl>.*?)^```\s*$", section.group("body"), re.MULTILINE | re.DOTALL)
if fence is None:
    raise SystemExit("README quick start is missing its canonical HCL block")

hcl = fence.group("hcl")
if 'source  = "aws-ia/networkfirewall/aws"' not in hcl:
    raise SystemExit("README quick start must use the Registry source aws-ia/networkfirewall/aws")
if 'version = "~> 2.0"' not in hcl:
    raise SystemExit('README quick start must pin version = "~> 2.0"')

hcl, source_count = re.subn(
    r'(?m)^  source\s+=\s+"aws-ia/networkfirewall/aws"\s*$',
    f"  source = {json.dumps(str(repo_root))}",
    hcl,
    count=1,
)
hcl, version_count = re.subn(
    r'(?m)^  version\s+=\s+"~> 2\.0"\s*\n',
    "",
    hcl,
    count=1,
)
if source_count != 1 or version_count != 1:
    raise SystemExit("README quick-start Registry source/version could not be rewritten exactly once")

out.write_text(hcl)
PY

terraform -chdir="${smoke_dir}" init -backend=false -no-color >/dev/null
terraform -chdir="${smoke_dir}" validate -no-color >/dev/null
printf 'README quick-start smoke test passed.\n'
