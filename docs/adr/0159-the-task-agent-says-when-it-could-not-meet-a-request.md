# ADR 0159: The Task Agent Says When It Could Not Meet a Request

- Status: Accepted
- Date: 2026-11-06
- Concepts: [task agents](../../knowledge/features/agents/task-agents.md#saying-a-request-was-not-met), [UI surfaces](../../knowledge/features/agents/ui-surfaces.md#the-unmet-request-callout)
- Builds on: [ADR 0115](0115-the-last-wake-outcome-is-two-watermarks.md)

## Context

`create_time_entry` once took one session per call, at most once per wake. A
user who dictated five time blocks needed ten-plus wakes to see them all
proposed, and nothing on the task card said so: every wake *completed*, the
report read normally, and the only trace was in the agent's private
observations, which the user had to open the agent internals to find.

A failed wake is already visible (`lastWakeFailedAt`, ADR 0115). This is the
other case: the wake succeeds and the user's request does not. The app cannot
detect it — no status, no error, nothing rejected. Only the agent knows that
what it was asked could not be done, the way a server knows when to answer
with a 500.

## Decision

1. **The agent has a panic button.** `flag_unmet_request {reason, details}`
   is an immediate, always-offered task-agent tool for a completed wake whose
   request did not complete: a tool that cannot express the request, a missing
   capability, a tool that kept failing, a user frustrated that their intent
   was not met. It is not for work that is merely waiting, or for proposals
   awaiting the user. The prompt names it in both scaffolds.
2. **The reason is for the card, the details for the internals.** `reason` is
   one sentence to the user in the task's language; `details` is filed as a
   `critical` `grievance` observation, so "check observations" always has
   something to show, and template evolution reads it with the other
   grievances.
3. **Two watermarks, like the wake outcome.** `unmetRequestAt` (with its
   `unmetRequestReason`) and `unmetRequestClearedAt` live in the agent state's slots
   and are joined by latest instant on every receive. The flag stands while it
   is newer than the last clear (`hasOpenUnmetRequest`). The reason travels
   with the newer flag; equal stamps take the row winner's, so every device
   agrees.
4. **Stamped at commit.** The flag is written with the wake's other outputs
   and stamped when they commit, not at wake start, so a clear the user makes
   while the wake runs cannot hide the flag that wake raises. A wake that fails
   after the call raises nothing.
5. **Only the user clears it.** A later wake that completes does not — wakes
   completing is exactly what hid the problem. The card's *Clear* stamps
   `unmetRequestClearedAt` past the flag it acknowledges, and a new flag is
   stamped past both watermarks (`decisionStampAfter`, ADR 0111), so a device
   whose clock runs ahead can neither keep a cleared flag up nor hide a new
   one. The clear never erases the flag.
6. **The agent sees its own flag.** Once it has ever flagged, the wake payload
   carries a `## Unmet Request` section: standing (do not raise it again for
   the same request) or cleared and when (flag again only for a new ask).

## Consequences

- The card answers "is this stuck?" without opening the agent: a warning
  callout leads the card body until the user clears it, with *See
  observations* opening the internals on the Observations tab.
- The signal depends on the model's judgement. A model that never presses the
  button shows nothing, and one that presses it too readily nags; both are
  tuned through the prompt and template evolution, not code.
- Three nullable fields in the agent state's slots. A peer on an older build does not
  know them: a concurrent write from it is merged and keeps the stamps, but a
  write from it that supersedes this device's replaces the row and drops a
  standing flag. Mixed-version households can lose a flag that way; the
  observation it filed stays.
