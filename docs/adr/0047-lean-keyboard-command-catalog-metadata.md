# ADR 0047: Lean Keyboard Command Catalog Metadata

## Status

Accepted

## Date

2026-08-01

## Context

ADR 0030 established the typed desktop command system and described every
catalog definition as carrying command-context metadata and a destructive
status. The implementation subsequently proved that both concerns already have
stronger runtime owners:

- command availability and context are determined by the mounted
  `AppCommandScope` hierarchy and its enabled handlers;
- destructive confirmation belongs to the feature handler or UI action that
  performs the mutation.

No execution, menu, palette, help, or presentation surface consumed the
catalog's `context` or `destructive` fields. Retaining them therefore duplicated
runtime state without enforcing behavior and made the typed catalog claim a
contract its consumers did not use.

## Decision

Keep `AppCommandDefinition` limited to metadata shared by active consumers:

- stable command id;
- user-facing category;
- platform shortcut bindings;
- command-palette visibility; and
- key-repeat policy.

Do not encode scope context or destructive status in the catalog.
`AppCommandScope` and `AppCommandHandler` remain the authority for contextual
availability. Feature-owned handlers remain responsible for confirmation and
other safety checks before destructive work.

This decision supersedes only the `context` and `destructive` metadata clauses
in ADR 0030 decisions 2 and 6. The rest of ADR 0030 remains accepted.

## Consequences

- The catalog contains no unused metadata and cannot drift from the mounted
  handler graph.
- A destructive command is not made safe merely by catalog classification;
  safety stays at the mutation boundary where it can be tested with the actual
  feature behavior.
- Adding a new contextual command requires a scoped handler and an appropriate
  palette visibility value, not a second context enum.
- A future presentation surface that genuinely needs destructive styling must
  introduce an enforced contract with a consumer, rather than restoring an
  advisory field.

## Related

- [ADR 0030: Desktop Keyboard Command System](./0030-desktop-keyboard-command-system.md)
- [PR #3721](https://github.com/matthiasn/lotti/pull/3721)
