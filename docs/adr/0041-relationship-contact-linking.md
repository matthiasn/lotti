# ADR 0041: Relationship Contact Linking and Communication Actions

- Status: Proposed
- Date: 2026-07-22

## Context

An executive briefing (ADR 0040) prepares the user for a conversation; the
natural next step is starting that conversation — calling or messaging the
person right from the briefing. That requires the relationship to know the
person's contact channels. Retyping phone numbers is friction, so pulling
them from the OS address book is attractive. It also closes the tracking
loop: an interaction Lotti itself initiated is the easiest possible
check-in to capture.

Two forces constrain the design. First, curation: relationships are a small
deliberate set of people (ADR 0038); importing an address book wholesale
would create hundreds of dormant relationship entities and destroy the
signal the reminders and briefings depend on. Second, platform reality:
OS contact pickers are well supported on iOS and Android, weakly on macOS,
and effectively unavailable on Linux/Windows; contact identifiers are
platform-local, so a contact reference cannot resolve on a synced peer
device. `url_launcher` (already a dependency) covers `tel:`, `sms:`, and
`mailto:` launching; no contacts plugin is currently in the dependency set.

## Decision

1. **No bulk import — selective linking only.** Contact integration is
   per-relationship and user-initiated: a "Link contact" action on the
   relationship opens the OS contact picker and copies the selected
   contact's channels into the relationship. The address book permission is
   requested only when the picker is invoked, never at startup, and Lotti
   never enumerates or reads the address book in the background.
2. **Channels are plain relationship data, not a live dependency.**
   `RelationshipData` gains `contactChannels`
   (`List<ContactChannel>` — `type` enum `phone`/`mobile`/`email`/
   `messaging`, optional `label`, `value`) and `contactRefs`
   (per-platform map of contact identifiers, used only for an explicit
   "Update from contact" refresh on the device that owns the contact).
   Channels are manually editable on every platform, so Linux/Windows get
   full feature parity through manual entry; the picker is a convenience,
   not a requirement. Snapshot data syncs and cascades like everything else
   in the relationship (ADR 0037).
3. **Quick actions via OS URL schemes.** Call, message, and email buttons
   appear on the relationship detail header and on the executive briefing
   card, launched through `url_launcher` (`tel:`/`sms:`/`mailto:`). Lotti
   contains no telephony code and never accesses call logs or content.
4. **Contact-initiated check-in capture.** When the user launches a call or
   message from Lotti, a transient pending-interaction marker (relationship
   id, channel type, timestamp — device-local, not synced) is recorded. On
   next app resume, a dismissable prompt offers to log a check-in
   pre-filled with the interaction type and time. Check-ins are never
   auto-created; declining leaves no trace.
5. **Channels are excluded from AI context.** The briefing context boundary
   (ADR 0040 §4) explicitly excludes `contactChannels` and `contactRefs` —
   the model has no need for phone numbers or email addresses, so they
   never reach any provider, local or cloud.
6. **Dependency scope.** The OS picker ships for iOS and Android first
   (e.g. `flutter_contacts` — new dependency, added at implementation
   time); macOS via the native Contacts framework is a later candidate.
   Desktop relies on manual entry until then.

## Consequences

- The curated-relationship model survives contact integration: the address
  book never drives entity creation, only enriches entities the user
  already chose to create.
- Per-platform `contactRefs` mean "Update from contact" works only on a
  device that has the contact — synced peers still see the channel values,
  which is what the quick actions need.
- The post-interaction prompt is a resume heuristic, not call detection: it
  can fire when no conversation happened (unanswered call) and misses
  interactions started outside Lotti. Accepted — it is an offer, not a log.
- One new mobile dependency (contacts picker); the action buttons
  themselves add none.

## Related

- [ADR 0037: Relationship Data Stays On-Device](./0037-relationship-on-device-storage-and-privacy.md)
- [ADR 0038: Relationship Domain Model](./0038-relationship-domain-model.md)
- [ADR 0040: Relationship Executive Briefing](./0040-relationship-executive-briefing.md)
- [Implementation plan](../implementation_plans/2026-07-22_relationship_management.md)
