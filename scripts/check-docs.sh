#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/networkfirewall-docs.XXXXXX")"
cleanup() {
  rm -rf "${temp_dir}"
}
trap cleanup EXIT

for source in "${repo_root}"/*.tf; do
  cp "${source}" "${temp_dir}/"
done
cp "${repo_root}/.header.md" "${repo_root}/.terraform-docs.yaml" "${repo_root}/.terraform.lock.hcl" "${temp_dir}/"

(
  cd "${temp_dir}"
  terraform-docs . >/dev/null
)

if ! cmp -s "${temp_dir}/README.md" "${repo_root}/README.md"; then
  printf 'README.md differs from terraform-docs output. Run: terraform-docs .\n' >&2
  diff -u "${repo_root}/README.md" "${temp_dir}/README.md" || true
  exit 1
fi

internal_pattern='/Users/|analysis/nfw-deep|R[0-9]+-F[0-9]+|[Pp]hase[[:space:]-]*[0-9]+|[Ww]ave[[:space:]-]*[0-9]+'
public_roots=(
  "${repo_root}/.header.md"
  "${repo_root}/README.md"
  "${repo_root}/docs"
  "${repo_root}/examples"
  "${repo_root}/modules"
)
for optional_file in CHANGELOG.md CONTRIBUTING.md SECURITY.md; do
  if [[ -f "${repo_root}/${optional_file}" ]]; then
    public_roots+=("${repo_root}/${optional_file}")
  fi
done

if grep -ERn --include='*.md' "${internal_pattern}" "${public_roots[@]}"; then
  printf 'Public Markdown contains an internal path, report label, or process-phase label.\n' >&2
  exit 1
fi

"${repo_root}/scripts/test-readme-usage.sh"
printf 'Generated documentation is current.\n'
