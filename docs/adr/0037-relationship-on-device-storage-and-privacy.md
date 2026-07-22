# ADR 0037: Relationship Data Stays On-Device

- Status: Proposed
- Date: 2026-07-22

## Context

Relationship management makes Lotti store observations about third parties:
who the user knows, when they interacted, what was discussed, how the
interaction felt, and what to watch out for next time. This is the most
sensitive data class the app will hold — more sensitive than the user's own
journal, because the data subjects are other people who never consented to
being described. Handing that data to a third-party service would be
irresponsible; the feature is only acceptable under the app's existing
privacy posture.

That posture already exists (see `PRIVACY.md`): all data lives in local
SQLite databases, there is no Lotti cloud service and no telemetry, and the
only way data leaves a device is the optional end-to-end encrypted Matrix
sync between the user's own devices, with keys exchanged via QR code and
never transmitted. Journal entities sync payload-agnostically
(`SyncMessage.journalEntity` in `lib/features/sync/model/sync_message.dart`),
so new entity types inherit this posture automatically. AI inference can run
fully locally (Ollama, OMLX/MLX — `InferenceProviderType` in
`lib/features/ai/model/ai_config.dart`) or against a cloud provider the user
configured with their own API key.

Under GDPR, a private individual keeping personal notes about their own
relationships falls under the household exemption (Art. 2(2)(c)) — but only
as long as the processing stays personal. Software that silently ships such
notes to a vendor's servers would break that framing and turn the vendor
into a processor. Lotti must therefore never receive or retain relationship
data, and any cloud AI use must be an explicit, user-configured choice.

## Decision

1. **Local journal storage only.** Relationship entities and check-ins are
   `JournalEntity` subtypes stored in the existing `journal` table
   (serialized-JSON-in-column, ADR 0038). No new storage layer, no external
   service, no Lotti-operated backend. Reminders live in the existing local
   `NotificationsDb`; briefings are agent reports in the agent database.
2. **Sync stays opt-in and end-to-end encrypted.** Relationship data rides
   the existing payload-agnostic Matrix sync between the user's own devices.
   No server ever sees plaintext; users who never configure sync keep the
   data on a single device.
3. **Zero retention outside the user's devices.** No telemetry, analytics,
   or crash payloads ever include relationship data. Executive briefings
   (ADR 0040) default to local inference; a cloud provider is used only when
   the user has explicitly configured one and selected it via an inference
   profile, requests are transient, and the UI states which provider will
   see the data before the user triggers a briefing. Retention at a cloud
   provider is governed by the user's own account with that provider — Lotti
   adds no storage of its own.
4. **The `private` flag applies.** Relationships and check-ins honor the
   existing `Metadata.private` semantics, so they can be excluded from
   surfaces that respect the private filter.
5. **Deletion and export are local and complete.** Relationship entities use
   the app's normal soft-delete + purge lifecycle. Deleting a relationship
   also deletes its linked check-ins, its agent reports, and any pending
   reminder rows — the cascade is explicit so no orphaned data about a
   person survives. Relationship data is included in the existing full data
   export. This makes the data-subject rights that matter (erasure, access,
   portability) trivially implementable, entirely on-device.
6. **Document the stance.** `PRIVACY.md` gains a short section on
   relationship data restating the above; the manual page states it in user
   terms.

## Consequences

- No server-side capability exists by design: reminders must be computed and
  scheduled on-device (ADR 0039), and there is no push infrastructure.
- Briefing quality on the default local-inference path is bounded by local
  model capability; users trade that off knowingly when selecting a cloud
  profile.
- The deletion cascade (check-ins, reports, notifications) is a real
  implementation obligation, not just policy prose, and needs tests.
- Because Lotti never receives the data, the GDPR household exemption
  framing holds: the user remains the sole controller of their personal
  notes, and Lotti (the software vendor) is not a processor.

## Related

- [ADR 0038: Relationship Domain Model](./0038-relationship-domain-model.md)
- [ADR 0039: Relationship Check-In Reminders](./0039-relationship-check-in-reminders.md)
- [ADR 0040: Relationship Executive Briefing](./0040-relationship-executive-briefing.md)
- [Implementation plan](../implementation_plans/2026-07-22_relationship_management.md)
- `PRIVACY.md`
