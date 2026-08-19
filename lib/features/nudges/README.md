# Nudges — the kind-agnostic banner channel

The substrate behind the in-app banner dock (ADR 0055/0058): model-authored
copy rendered procedurally, quiet by default, with dismissal-as-data,
snoozes, per-activation ratings, and exposure metering. Generalized out of
the goal feature by ADR 0059 so a second agent kind — relationship agents —
can speak through the same channel without duplicating it. This module owns
the *channel*; each kind owns its *producer* (what generates a nudge and
what its banners advertise).

- `model/` — `NudgeEntityView`, a zero-cost view over the nudge variants of
  `AgentDomainEntity` (`goalNudge`, `relationshipNudge` — siblings with
  identical banner-facing fields but no common supertype), plus
  `NudgeBannerEntry`/`NudgeBannerKind`/`NudgeBannerSurface` and the
  per-kind surface rule: goal banners speak on tasks/dailyOs/habits;
  relationship banners add the People pages.
- `logic/` — snooze and rest-of-day dismissal as pure entity rewrites,
  DST-safe, idempotent per event id, dual-writing the legacy provenance
  deadline for older peers.
- `service/` — `NudgeInteractions`: the user's side of the banner contract
  (snooze, dismiss for today, rate once per activation, account exposure),
  serialized per nudge and transactional against incoming sync.
- `state/` — the source registry (`nudgeBannerSourcesProvider`, one
  active-banner provider per kind, merged in `app_bootstrap.dart` — the
  `agentWakeRunnersProvider` pattern), the merged `activeNudgeBannersProvider`
  the dock watches, local snooze suppression, and the exposure flush.
- `ui/` — the shell dock (rotating tenants, top-of-shell banner lane,
  per-surface filtering), the banner style/animated-text/persona-chip/CTA
  primitives, and the snooze/rating sheets.

This module never imports a producing feature. Both current producers
register their source in `app_bootstrap.dart`: goals contributes
`activeGoalNudgesProvider` and relationships contributes
`activeRelationshipNudgesProvider`, so the dock's multi-source merge and
the per-kind surface gate are live paths, not future-proofing.

How the two entity variants are read through one view, why the dock's
visibility rule is shared with the shell's reserved lane, how the rotation
reconciles against each snapshot, and how concurrent edits merge losslessly are
documented in the knowledge bundle:

**→ [knowledge/features/nudges.md](../../../knowledge/features/nudges.md)**

The decisions behind them are
[ADR 0059](../../../docs/adr/0059-relationship-agent-runtime-and-nudge-generalization.md),
[ADR 0055](../../../docs/adr/0055-banner-nudge-attention-channel.md) and
[ADR 0058](../../../docs/adr/0058-procedural-text-banners-no-generative-imagery.md).
