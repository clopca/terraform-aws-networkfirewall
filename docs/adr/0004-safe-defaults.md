# ADR 0004: Safe create-mode defaults

## Status

Accepted

## Decision

New firewalls default delete, policy-change, subnet-change, and Availability Zone-change protection to `true`. Encryption defaults to `AWS_OWNED_KMS_KEY`; customer KMS encryption is opt-in and requires a key ARN.

A v1-to-v2 state migration must first reproduce the deployed v1 flags, including `false` protections, in the `primary` object. Enabling safer protections is a separate reviewed plan after the zero-destroy migration. The migration must not combine state movement with policy, subnet, endpoint address-family, logging, or routing behavior changes.
