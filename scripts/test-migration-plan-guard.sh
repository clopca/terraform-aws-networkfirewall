#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
safe_plan="$(mktemp /tmp/nfw-safe-plan.XXXXXX.json)"
unsafe_plan="$(mktemp /tmp/nfw-unsafe-plan.XXXXXX.json)"

cat >"$safe_plan" <<'JSON'
{"resource_changes":[{"address":"aws_route.safe","change":{"actions":["update"]}},{"address":"terraform_data.new","change":{"actions":["create"]}}]}
JSON

cat >"$unsafe_plan" <<'JSON'
{"resource_changes":[{"address":"aws_route.replaced","change":{"actions":["delete","create"]}}]}
JSON

"$repo_root/scripts/check-migration-plan.sh" "$safe_plan"
if "$repo_root/scripts/check-migration-plan.sh" "$unsafe_plan" >/dev/null 2>&1; then
  echo "migration plan guard accepted a delete action" >&2
  exit 1
fi

echo "Migration plan JSON guard tests passed"
