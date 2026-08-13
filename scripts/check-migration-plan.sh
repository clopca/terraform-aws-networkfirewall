#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 <saved-plan-or-plan.json> [approved-actions.txt]" >&2
  echo "approved-actions format: one exact '<action> <resource-address>' entry per line" >&2
  exit 2
fi

plan_path="$1"
approvals_path="${2:-}"
if [[ ! -f "$plan_path" ]]; then
  echo "plan file not found: $plan_path" >&2
  exit 2
fi
if [[ -n "$approvals_path" && ! -f "$approvals_path" ]]; then
  echo "approved actions file not found: $approvals_path" >&2
  exit 2
fi

if [[ "$plan_path" == *.json ]] || [[ "$(head -c 1 "$plan_path")" == "{" ]]; then
  cat "$plan_path"
else
  terraform show -json "$plan_path"
fi | python3 -c '
import json
import re
import sys

approvals_path = sys.argv[1]
approved = set()
if approvals_path:
    with open(approvals_path, encoding="utf-8") as stream:
        for number, raw in enumerate(stream, 1):
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(maxsplit=1)
            if len(parts) != 2 or parts[0] not in {"create", "update"}:
                raise SystemExit(f"invalid approval line {number}: {line!r}")
            approved.add((parts[0], parts[1]))

plan = json.load(sys.stdin)
delete_violations = []
unapproved = []
for change in plan.get("resource_changes", []):
    address = change.get("address", "<unknown>")
    actions = change.get("change", {}).get("actions", [])
    if "delete" in actions:
        delete_violations.append((address, actions))
        continue
    for action in actions:
        if action in {"no-op", "read"}:
            continue
        if action == "create" and re.search(r"(?:^|\.)terraform_data\.", address):
            continue
        if (action, address) not in approved:
            unapproved.append((address, action, actions))

if delete_violations:
    for address, actions in delete_violations:
        print(f"delete action rejected: {address}: {actions}", file=sys.stderr)
if unapproved:
    for address, action, actions in unapproved:
        print(f"unapproved {action} action rejected: {address}: {actions}", file=sys.stderr)
if delete_violations or unapproved:
    raise SystemExit(1)
print("Migration plan gates passed: no delete/replace actions and every create/update is explicitly approved")
' "$approvals_path"
