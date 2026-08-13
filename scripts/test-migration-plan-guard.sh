#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
safe_plan="$(mktemp /tmp/nfw-safe-plan.XXXXXX)"
unsafe_plan="$(mktemp /tmp/nfw-unsafe-plan.XXXXXX)"
update_plan="$(mktemp /tmp/nfw-update-plan.XXXXXX)"
approvals="$(mktemp /tmp/nfw-plan-approvals.XXXXXX)"

cat >"$safe_plan" <<'JSON'
{"resource_changes":[{"address":"aws_route.moved","change":{"actions":["no-op"]}},{"address":"module.nfw.terraform_data.contract[\"primary\"]","change":{"actions":["create"]}}]}
JSON

cat >"$unsafe_plan" <<'JSON'
{"resource_changes":[{"address":"aws_route.replaced","change":{"actions":["delete","create"]}}]}
JSON

cat >"$update_plan" <<'JSON'
{"resource_changes":[{"address":"aws_route.approved","change":{"actions":["update"]}}]}
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

echo "Migration plan JSON guard tests passed"
