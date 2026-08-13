#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
safe_plan="$(mktemp /tmp/nfw-safe-plan.XXXXXX)"
unsafe_plan="$(mktemp /tmp/nfw-unsafe-plan.XXXXXX)"
update_plan="$(mktemp /tmp/nfw-update-plan.XXXXXX)"
spoofed_type_plan="$(mktemp /tmp/nfw-spoofed-type-plan.XXXXXX)"
approvals="$(mktemp /tmp/nfw-plan-approvals.XXXXXX)"
fixture="$(mktemp -d /tmp/nfw-forget-plan.XXXXXX)"

cleanup() {
  rm -f "$safe_plan" "$unsafe_plan" "$update_plan" "$spoofed_type_plan" "$approvals"
  python3 - "$fixture" <<'PY'
from pathlib import Path
import shutil
import sys
path = Path(sys.argv[1])
if path.exists():
    shutil.rmtree(path)
PY
}
trap cleanup EXIT

cat >"$safe_plan" <<'JSON'
{"resource_changes":[{"address":"aws_route.moved","change":{"actions":["no-op"]}},{"address":"module.nfw.terraform_data.contract[\"primary\"]","change":{"actions":["create"]}}]}
JSON

cat >"$unsafe_plan" <<'JSON'
{"resource_changes":[{"address":"aws_route.replaced","change":{"actions":["delete","create"]}}]}
JSON

cat >"$update_plan" <<'JSON'
{"resource_changes":[{"address":"aws_route.approved","change":{"actions":["update"]}}]}
JSON

cat >"$spoofed_type_plan" <<'JSON'
{"resource_changes":[{"address":"module.terraform_data.aws_route.unapproved","change":{"actions":["create"]}}]}
JSON

printf '%s\n' 'update aws_route.approved' >"$approvals"

"$repo_root/scripts/check-migration-plan.sh" "$safe_plan"
if "$repo_root/scripts/check-migration-plan.sh" "$unsafe_plan" >/dev/null 2>&1; then
  echo "migration plan guard accepted a delete action" >&2
  exit 1
fi
if "$repo_root/scripts/check-migration-plan.sh" "$update_plan" >/dev/null 2>&1; then
  echo "migration plan guard accepted an unapproved update action" >&2
  exit 1
fi
"$repo_root/scripts/check-migration-plan.sh" "$update_plan" "$approvals"
if "$repo_root/scripts/check-migration-plan.sh" "$spoofed_type_plan" >/dev/null 2>&1; then
  echo "migration plan guard mistook a module label named terraform_data for the resource type" >&2
  exit 1
fi

cat >"$fixture/main.tf" <<'HCL'
terraform {
  required_version = ">= 1.7"
}

resource "terraform_data" "legacy" {
  input = "legacy-state"
}
HCL
terraform -chdir="$fixture" init -backend=false >/dev/null
terraform -chdir="$fixture" apply -auto-approve -no-color >/dev/null
cat >"$fixture/main.tf" <<'HCL'
terraform {
  required_version = ">= 1.7"
}

removed {
  from = terraform_data.legacy
  lifecycle {
    destroy = false
  }
}
HCL
terraform -chdir="$fixture" plan -out=forget.tfplan -no-color >/dev/null
terraform -chdir="$fixture" show -json forget.tfplan >"$fixture/forget.json"
python3 - "$fixture/forget.json" <<'PY'
import json
import sys
plan = json.load(open(sys.argv[1], encoding="utf-8"))
actions = {
    change["address"]: change.get("change", {}).get("actions", [])
    for change in plan.get("resource_changes", [])
}
if actions.get("terraform_data.legacy") != ["forget"]:
    raise SystemExit(f"real removed-block plan did not produce forget: {actions!r}")
PY
if "$repo_root/scripts/check-migration-plan.sh" "$fixture/forget.tfplan" >/dev/null 2>&1; then
  echo "migration plan guard accepted an unapproved forget action" >&2
  exit 1
fi
printf '%s\n' 'forget terraform_data.legacy' >>"$approvals"
"$repo_root/scripts/check-migration-plan.sh" "$fixture/forget.tfplan" "$approvals"

echo "Migration plan JSON and real forget-action guard tests passed"
