# ADR 0102: Pre-Approved Agent Changes

- Status: Accepted
- Date: 2026-09-27

## Context

The record provenance spec says agents change the record only through signed
proposals that take effect through a signed user approval (§8), and its rule R2
forbids a standing approval. The
[Phase 0 mapping](../implementation_plans/2026-09-25_record_provenance_phase0_mapping.md)
found seven paths where an agent or AI write applies immediately, with no
proposal (its section 4):

- the task agent setting an empty task title and language;
- the day agent's `apply_triage` (status, due date);
- the day agent's `create_task_from_phrase`;
- AI transcription, automatic behind a category consent switch or manual;
- AI summaries, image analysis and prompt generation (new `AiResponseEntry`);
- AI image generation, which imports an image and sets the task cover art;
- the legacy prompt path, which can append analysis to `entryText`.

Its decision D7 asked whether to route these through proposals, or keep them
immediate as a named class of pre-approved change. Agents are part of the
product rather than an add-on, and making the user confirm a title, a
transcript or a triage would make these features slower to use without
telling the user anything new.

## Decision

1. **These paths stay immediate.** They are not rerouted through change sets.
2. **They form one named class: pre-approved agent changes.** A write on one of
   these paths is signed with `author.type = agent`, like any agent write. It is
   never recorded as the user's own edit, and never as an approved proposal.
3. **The pre-approval is recorded, not implied.** Each such write refers to
   the user consent that allowed it, and that consent is itself a signed,
   user-authored record:
   - a standing consent (for example the category switch for automatic
     transcription) is one signed envelope. Turning it off is a later envelope,
     not an edit of the first;
   - a manual trigger (a button press on the AI menu) is its own consent, as the
     skill runner already treats it. It is recorded for the one write it
     started.
4. **The spec's R2 is amended for this class only.** Standing consent is allowed
   for the paths listed above and for any path later added to the class by an
   ADR. Everything else an agent does still needs a proposal and a per-item
   approval.
5. **The UI keeps the two apart.** Where provenance is shown, a pre-approved
   change reads as pre-approved (and names the consent), not as approved.

## Consequences

- The approval choke point (spec R1, mapping C5) has two ways in: an approval
  hash for a proposal, or a consent reference for a pre-approved change. An agent
  write with neither is refused.
- Four of the seven paths have no explicit consent today: the task agent's
  title and language, and both day-agent paths. Assigning the agent is the
  only consent the user gives. The approval phase must choose what the recorded
  consent is for each of them. Assigning an agent, or a category-level
  setting, are the likely candidates.
- The envelope gains one kind, `consent`, for the user's signed consent
  (granting and withdrawing). It is not an `approval`, because an approval
  answers one proposal. It is added in the approval phase, with the rest of
  the consent handling. A pre-approved write needs no format change: it is an
  ordinary agent-authored envelope whose `refs` name the consent. Its `author`
  (model, context hash) is the same as for any agent write.
- Adding a path to the class takes an ADR, so the class cannot grow by
  accident.

## Related

- [Phase 0 mapping](../implementation_plans/2026-09-25_record_provenance_phase0_mapping.md), decision D7 and section 4
- [ADR 0088: Provenance Crypto Primitives](./0088-provenance-crypto-primitives.md)
- [Provenance concept](../../knowledge/features/provenance.md)
