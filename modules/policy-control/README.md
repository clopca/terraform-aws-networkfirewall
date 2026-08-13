# Policy control

This public module is a `STRICT_ORDER` policy-release and rule-group **binding** layer. A stateful slot is declared metadata plus ARN, priority, behavior, and rollout controls; it never contains rule content. Updating IOCs or Suricata signatures inside a referenced group does not appear in this module's plan. Consequently, an apply here changes policy structure only.

First-class ARN origins are: AWS managed rule groups, Terraform-owned groups from `modules/rule-groups`, and external groups whose SOC/SOAR pipeline calls `UpdateRuleGroup`. The provider has no `data.aws_networkfirewall_rule_group`; ARN existence, capacity, kind, and compatibility are caller attestations and AWS remains the apply-time authority.

## Correct gate

`DROP_TO_ALERT` is emitted only for `kind = "managed"`. Customer groups with `drop` or `reject` that would be observed must provide an alert-only `observation_arn`; otherwise plan fails and tells the caller to supply that variant or promote the group through `enforce_from`. Blocking references in observation also require `behavior.override_coverage = "all_blocking"`.

`incident_control.group_overrides` (`observe|force_enforce`) has precedence over `incident_control.mode`, which has precedence over `enforce_from`. `observe_all_stateful` is therefore reversible per slot. Non-normal incident posture requires `change_id`, `owner`, and `expires_at`. Expiry is metadata for CI/on-call automation; Terraform does not auto-revert it. Stateless groups are always enforced.

`home_net_cidrs` is the only policy-variable input and renders only `HOME_NET`. It is mandatory and non-empty for any reference declaring `requires_home_net`, including generated domain ALLOWLIST groups.

## Immutable releases and TLS

Every policy key is a release and must end in `-plain` or `-tls`, matching TLS absence/presence. The key and physical name include the release identity. Adding/removing TLS is a new key, never a toggle on an existing release. Terraform cannot compare prior input history, so this naming invariant plus lifecycle tests enforce the supported candidate/active/last-known-good pattern.

Engine defaults are `stream_exception_policy = "DROP"` and `tcp_idle_timeout_seconds = 350`. Changing either can restart the stateful engine and requires a change window.

ActionOrder policies and groups are not adopted in place. Create new STRICT_ORDER-compatible releases instead.
