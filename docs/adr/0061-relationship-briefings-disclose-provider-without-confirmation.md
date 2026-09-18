# ADR 0061: Relationship Briefings Name Their Provider Without Asking

- Status: Accepted — implemented. `RelationshipBriefingCard` requests a
  briefing directly; `relationshipBriefingDisclosureProvider` and its
  confirmation sheet are removed.
- Date: 2026-09-19
- Refines: ADR 0037 Decision 3, ADR 0059 Decision 7

## Context

ADR 0037 Decision 3 requires that "the UI states which provider will see the
data before the user triggers a briefing", and ADR 0059 Decision 7 carries it
into the runtime: "before any cloud-bound trigger the UI names the provider".

It was implemented as a confirmation sheet — *Send to {provider}? The briefing
runs on {provider}. Notes about this person will be sent there for
processing.* — shown on **every** cloud-routed *Brief now* and *Update now*,
followed by a *Briefing requested* toast. In use this read as friction without
information:

- the provider is one the user configured and chose, in an app whose purpose
  is to run these briefings; no other surface in the app confirms a request to
  its provider per action;
- the answer never changes between taps, so the sheet trains a reflexive
  *Continue*, which is the opposite of informed consent;
- the card already names the route before any tap: its model row reads
  *{model} · via {provider}* on every face.

## Decision

1. **The provider is disclosed passively, not by confirmation.** The briefing
   card's model row — present on every enrolled face, before and during a run
   — is the statement ADR 0037 requires. Tapping *Brief now* or *Update now*
   requests the briefing at once.
2. **No acknowledgement toast.** The card's running face (the spinner on its
   status line) is the acknowledgement; a failure to enqueue still toasts.
3. **An update never blanks the card.** While a new briefing is written, the
   previous one stays readable under the spinner; a first briefing shows the
   status line alone. No face estimates how long a run takes.
4. **A missing route is reported by the wake, not pre-empted.** Without the
   disclosure preflight there is no pre-tap route resolution; a wake with no
   resolvable model is stamped failed and the card offers *Choose a model*.

ADR 0037's substance — no Lotti-side retention, local-first defaults, the user
choosing any cloud provider explicitly — is unchanged.

## Consequences

- Fewer surfaces: the disclosure provider, its exception, and the sheet's,
  toast's and duration estimate's strings are gone.
- The model row carries a privacy duty: it must stay visible on every enrolled
  face and name the provider, not only the model.
