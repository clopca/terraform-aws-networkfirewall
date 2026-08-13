#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <saved-plan-or-plan.json>" >&2
  exit 2
fi

plan_path="$1"
if [[ ! -f "$plan_path" ]]; then
  echo "plan file not found: $plan_path" >&2
  exit 2
fi

if [[ "$plan_path" == *.json ]] || [[ "$(head -c 1 "$plan_path")" == "{" ]]; then
  cat "$plan_path"
else
  terraform show -json "$plan_path"
fi | python3 -c '
import json
import sys

plan = json.load(sys.stdin)
violations = []
for change in plan.get("resource_changes", []):
    actions = change.get("change", {}).get("actions", [])
    if "delete" in actions:
        violations.append((change.get("address", "<unknown>"), actions))
if violations:
    for address, actions in violations:
        print(f"delete action rejected: {address}: {actions}", file=sys.stderr)
    raise SystemExit(1)
print("Migration plan gate passed: no delete or replace actions")
'
