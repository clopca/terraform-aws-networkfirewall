#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

validate_golden_path() {
  local example_dir="${repo_root}/examples/end_to_end_vpc_v5"
  local fixture_dir="${repo_root}/tests/fixtures/vpc-v5-contract"
  local temp_dir
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/networkfirewall-vpc-v5.XXXXXX")"

  cleanup_golden_path() {
    rm -rf "${temp_dir}"
  }
  trap cleanup_golden_path RETURN

  cp -R "${example_dir}/." "${temp_dir}/"
  python3 - "${temp_dir}/main.tf" "${example_dir}" "${fixture_dir}" <<'PY'
from pathlib import Path
import json
import re
import sys

main_path = Path(sys.argv[1])
example_dir = Path(sys.argv[2]).resolve()
fixture_dir = Path(sys.argv[3]).resolve()
text = main_path.read_text()

registry = '''  source  = "aws-ia/vpc/aws"
  version = "~> 5.0"'''
replacement = f"  source = {json.dumps(str(fixture_dir))}"
if text.count(registry) != 1:
    raise SystemExit("end_to_end_vpc_v5 must contain exactly one canonical VPC v5 Registry source/version")
text = text.replace(registry, replacement)

pattern = re.compile(r'(?m)^(?P<indent>\s*)source\s*=\s*"(?P<source>\.\.?/[^\"]+)"\s*$')

def local_source(match: re.Match[str]) -> str:
    resolved = (example_dir / match.group("source")).resolve()
    return f'{match.group("indent")}source = {json.dumps(str(resolved))}'

text = pattern.sub(local_source, text)
main_path.write_text(text)
PY

  terraform -chdir="${temp_dir}" init -backend=false -no-color >/dev/null
  terraform -chdir="${temp_dir}" validate -no-color
  trap - RETURN
  cleanup_golden_path
}

while IFS= read -r example_dir; do
  example="$(basename "${example_dir}")"
  printf 'Validating example: %s\n' "${example}"
  if [[ "${example}" == "end_to_end_vpc_v5" ]]; then
    validate_golden_path
  else
    terraform -chdir="${example_dir}" init -backend=false -lockfile=readonly -no-color >/dev/null
    terraform -chdir="${example_dir}" validate -no-color
  fi
done < <(find "${repo_root}/examples" -mindepth 1 -maxdepth 1 -type d -print | LC_ALL=C sort)
