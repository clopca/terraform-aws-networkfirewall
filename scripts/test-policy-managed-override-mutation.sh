#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
policy_file="$repo_root/modules/policy-control/main.tf"
backup="$(mktemp /tmp/nfw-policy-managed-override.XXXXXX)"
log_file="$(mktemp /tmp/nfw-policy-managed-override-test.XXXXXX)"
cp "$policy_file" "$backup"
trap 'cp "$backup" "$policy_file"; rm -f "$backup" "$log_file"' EXIT

python3 - "$policy_file" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
text = path.read_text()
needle = '''            local.stateful_decisions[each.key][stateful_rule_group_reference.key].blocking &&
            stateful_rule_group_reference.value.kind == "managed"
'''
replacement = '''            local.stateful_decisions[each.key][stateful_rule_group_reference.key].blocking
'''
if text.count(needle) != 1:
    raise SystemExit("managed-only override predicate was not found exactly once")
path.write_text(text.replace(needle, replacement, 1))
PY

terraform -chdir="$repo_root" fmt -check modules/policy-control/main.tf
if terraform -chdir="$repo_root" test -no-color -filter=tests/policy_control.tftest.hcl >"$log_file" 2>&1; then
  echo "policy mutation guard: removing the managed-only override filter left the policy suite green" >&2
  cat "$log_file" >&2
  exit 1
fi

if ! grep -Fq "The rendered AWS policy must give exactly one managed reference DROP_TO_ALERT" "$log_file"; then
  echo "policy mutation guard: suite failed for an unrelated reason" >&2
  cat "$log_file" >&2
  exit 1
fi

echo "Policy managed-only override mutation guard passed"
