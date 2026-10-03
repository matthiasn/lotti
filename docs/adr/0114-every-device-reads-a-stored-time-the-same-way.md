# ADR 0114: Every Device Reads a Stored Time the Same Way

- Status: Accepted — model-checked in `specs/tla/RelationshipCadence.tla`
  and implemented; a conformance trace replays the model against the real
  tick on two devices in two zones
- Date: 2026-10-02

## Context

A relationship's check-in cadence is derived on every device by the same
deterministic tick (`RelationshipAgentPhaseA`, ADR 0059 Decision 2). The
derivation reads journal times: a check-in's `dateFrom` for the day the
cadence counts from, its `updatedAt` for when the evidence last changed, and
the person's own `dateFrom` when there is no check-in. From them it writes
the one register row and arms the per-episode escalation whose key is the
due day, and the elected run writes the briefing.

Journal metadata times are written as the writer's local wall-clock
components without an offset — `toIso8601String` on a local `DateTime`
drops the zone — beside the `utcOffset` the entry was created with. A
device in another zone parses the same components as a different instant.
So anything derived through `.toUtc()` on a stored value is a different
answer on every device, and the derivation did exactly that for the due
day (`GoalWindow.dayUtc(dateFrom.toUtc())`) and for the register's
instants. `updateMetadata` kept the creation offset beside a new local
`updatedAt`, so a touch from another zone named an instant hours off. The
run stamped the briefing's `createdAt` with its local wall clock, which a
peer read as another instant. The cadence tick's own deadline was a local
07:00 that every zone read as its own. And the UI counted the days a
person was over with a floored difference of local midnights, which makes
the 23-hour day of a spring-forward zero days.

`RelationshipCadence.tla` models two devices in two zones reading stored
times as the code does. Against the code at `a0f9af57f`, TLC finds:

- **Two zones derive two due days** for one check-in near midnight
  (`DueDayAgreed`, 3 states). The register's `dueAt` then differs per
  device, and the two rewrite the row at each other for as long as that
  check-in is the newest (`RegisterStable`, 5 states). A lapse gets one
  escalation per zone, keyed by a day no calendar names for the check-in —
  two episodes, two paid briefings (`EscalationKeyIsTheDueDay`, 7 states).
- **A touch from another zone is read as older than the briefing** it
  should have made stale, on every device, so the refresh is never armed
  (`BriefedOnNewEvidence`, 9 states).
- **A peer reads the briefing as hours behind its evidence** and arms a
  refresh for evidence already briefed (`StalenessAgreed`, 6 states). The
  writing device reads its own stamp correctly, so a briefing is never
  missed.

## Decision

- **A stored journal time is read in two ways, and only these two.** Both
  live in `relationship_calendar.dart`:
  - its **calendar day** is the day its components name
    (`relationshipCalendarDay`): the day the writer saw on their own
    calendar, the same on every device;
  - its **instant** is the components rebuilt through the entry's own
    `utcOffset` (`relationshipStoredInstant`): the moment the writer meant
    for the stamp the offset was written beside, and for any other stamp
    the same moment on every device.

  Never `.toUtc()` on a stored value. The due day is the reference's
  calendar day plus the cadence, counted on day keys
  (`relationshipDueDay`); the register's `referenceAt` and `lastCheckInAt`
  are stored instants, and the facts the model reads take the check-in's
  day from its day key (`lastCheckInDay`), never from the instant. The
  lapse is still detected at UTC midnight of the
  due day — one instant for every device — which keeps the register's
  status convergent. The UI's due date and overdue count use the same day
  arithmetic (`cadenceDueDate`, `cadenceOverdueDays`), so the list, the
  register and the reminder name one day.
- **The offset beside a stamp is the offset of that stamp.**
  `updateMetadata` writes this device's `utcOffset` and `timezone` beside
  the new `updatedAt`, as `createMetadata` does beside the creation. The
  evidence instant of a touch is then the instant the toucher meant. A
  `dateFrom` was never recoverable from the offset — a backdated entry
  carries the offset of the day it was saved — which is why the cadence
  reads `dateFrom` by its calendar day.
- **Agent stamps that peers compare are written in UTC.** The briefing's
  `createdAt` (`relationshipBriefingCreatedAt`), the standing head's
  in-period `updatedAt` (`relationshipReportHeadUpdatedAt`), and the
  cadence tick's deadline (`relationshipCadenceWake`), as the nudges' and
  the escalations' deadlines already were. A reader that formats one calls
  `toLocal()`.
- **Days are counted on the calendar.** `relationshipCalendarDaysBetween`
  subtracts day keys, so a day is one day long whatever the clocks did.

## Consequences

- One due day in every zone: the register is written once per change and
  stands, one escalation and one briefing per lapse, and the OS reminder
  fires on the day the person's own calendar names.
- The evidence instant of a touch is the toucher's, so a check-in that
  gains an entry on a device in another zone makes the briefing stale
  everywhere. The register's instants shift once on upgrade for entries
  touched across zones; the row is rewritten once.
- A briefing written before this change carries a local stamp. A peer in
  another zone may read it as stale once more and refresh it once; after
  that every briefing is read alike. Reports have no offset to recover an
  older stamp with, and a second refresh is the cheaper repair.
- The cadence tick's deadline is one instant every device reads alike. It
  is not one tick a day fleet-wide: concurrent re-arms are decided by the
  later deadline, but a causal re-arm by whichever device ran the tick
  replaces it with that device's own 07:00, so the deadline may move
  between zones and a day may see a tick from each. Harmless — the tick is
  free, and the escalation it arms is keyed by episode. Which hour the €0
  tick runs at does not matter; that every device reads one deadline alike
  does.
- Whether the cadence should count from `importantSince` rather than the
  person's `dateFrom` (the plan's R-10) is a product choice this ADR does
  not make; the model carries both.

## Verification

- `specs/tla/RelationshipCadence.tla`, run with `specs/tla/tlc.sh`:
  `RelationshipCadence` (two devices, UTC+2 and UTC+9, one check-in, one
  touch, three ticks, one run, 10,216,310 distinct states) and
  `RelationshipCadenceEnroll` (210,930). Each switch set to the old code's
  value, in a temporary configuration, fails a property: `DayFromWallClock`
  — `DueDayAgreed` in 3 states, `RegisterStable` in 5,
  `EscalationKeyIsTheDueDay` in 7; `OffsetRefreshed` —
  `BriefedOnNewEvidence` in 9, `StalenessAgreed` in 8; `ReportStampUtc` —
  `StalenessAgreed` in 6.
- `test/features/relationships/runtime/relationship_cadence_model_conformance.dart`
  replays the model against the real `RelationshipAgentPhaseA`,
  `MetadataService` and agent sync on two devices whose clocks are
  `TZDateTime`s in Berlin and Tokyo, every received stamp read in the
  reader's zone: 120 generated traces and five pinned ones, one per
  counterexample. Reverting any decision in the Dart code fails the trace.
- Unit regressions: the Phase A derivation with the same stored components
  parsed in Berlin and in Tokyo; `relationship_calendar_test.dart` over
  every day of the year in three zones; `updateMetadata` stamping the
  device's offset; the briefing's and the head's stamps; the UI's due date
  across a spring-forward.
