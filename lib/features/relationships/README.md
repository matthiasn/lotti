# Relationships

A personal CRM for a small, deliberately curated set of people. One
relationship entity per person, with a timeline of **check-ins** — structured
interaction logs (type, sentiment, topics, narrative) — and, for people
marked important, a dedicated agent that tracks check-in cadence and briefs
the user before the next conversation.

This feature is landing in phases; see the
[implementation plan](../../../docs/implementation_plans/2026-08-13_relationship_management_v2.md)
and ADRs 0037–0041 plus 0059. What exists today (phases 1–5 and 7, behind
the `enable_relationships` flag):

- **Domain model** in `lib/classes/`: `relationship_data.dart`
  (`RelationshipData`, `RelationshipStatus`, `ContactChannel`) and
  `check_in_data.dart` (`CheckInData`, interaction type and sentiment enums).
  Both ride the journal table as `JournalEntity.relationship` /
  `JournalEntity.checkIn` — payload-agnostic sync, `private` flag,
  categories, and export all apply with zero new infrastructure.
- **Linking**: `EntryLink.relationship` binds relationship → check-in and
  relationship ↔ task. Check-ins also carry a denormalized
  `relationshipId` so `affectedIds` emits a precise agent wake token and the
  journal `subtype` column supports indexed check-in queries.
- `repository/` — `RelationshipRepository`: CRUD for both entity types
  (create, edit, delete — relationship deletion cascades to its check-ins,
  ADR 0037 §5) plus the recency-ordered list used by the People tab.
- `ui/` + `state/` — the flag-gated **People tab** (`/people`, its own
  beamer location): the People list — banded *Due · On track · Not enrolled*
  under a summary card that counts who is due now and names who lapses next,
  each row naming the last contact (`Call · Today 12:44 · Weekly`) with a
  truthful cadence pill, and on desktop a list/detail split like Tasks —
  the per-person page, a sibling of the task page: a cover-style hero
  (back · Talk to agent · edit · a menu with link-contact and delete) with
  the persona avatar hanging off it, a header block (category · Important,
  the full name, nickname and last contact, then the cadence fact, the
  health band and the next due day as pills), and section cards in the
  design's order — Briefing · Next time (what the latest check-in asked to
  bring up or avoid) · Check-ins (mono `timestamp · type · duration`, the
  sentiment as a tinted pill, topics as tags) · Reach (channels with the
  actions the device can service, under the privacy line) · Tasks
  (`RelationshipLink` both ways, a picker that also creates the task when
  none exists yet, per-row unlink) — above a sticky action bar: *Log
  check-in*, a mic that opens the capture sheet already recording, and the
  first channel the platform can open. The add/edit person modal (name, nickname, importance,
  cadence presets, status, and the manual contact-channel editor — desktop
  parity per ADR 0041 §2), and the check-in capture sheet (interaction
  type, date, user-set sentiment — never AI-filled, ADR 0038 — topics,
  narrative, next-time guidance; editable and deletable afterwards).

- `runtime/` + `service/` + `state/` — the **relationship agent's
  deterministic tier** (plan v2 phase 4, ADR 0059): marking a person
  important quietly creates their dedicated agent, which tracks the
  check-in cadence every day at zero AI cost. Deleting a person destroys
  their agent (the cascade's agent leg).
- `workflow/` + the rest of `service/`, `state/`, `ui/` — the **LLM tier**
  (plan v2 phase 5): a lapsed cadence, a check-in newer than the current
  briefing, a chat message, or an explicit "Brief me" triggers one AI run
  that writes an executive briefing (with a health band) and at most one
  check-in banner. The person page mounts the relationship agent's card —
  the *same* AI panel as the task agent's section and the goal agent's read,
  so the briefing renders as Markdown and "Read more" and "Open agent
  internals" behave exactly as they do on a task — in one of seven faces:
  not enrolled (a plain card with *Mark important*), no briefing yet (*Brief
  now*, which names the cloud provider first, per ADR 0037), running,
  failed (the reason, with *Choose a model* or *Try again* as the fix),
  current (*Update now*, the cost so far, the model row), out of date, and
  due (*Log check-in* · *Call*). `/people/<id>/chat`
  opens the per-person agent chat from the page's hero. A briefing runs on the AI profile of the
  person's category unless the person has one of their own. Banners surface through the
  kind-agnostic channel (`lib/features/nudges/`), tapping through to the
  person.

- **Voice check-ins** (plan v2 phase 6): "Speak check-in" on the capture
  sheet records through the shared recording sheet with the *person* as the
  recording's linked entity, then waits for the transcript and drops it into
  the narrative field for the user to edit and confirm. Nothing auto-saves —
  the check-in stays user-authored, and speaking never overwrites text the
  user already typed. Transcription resolves the person's inference profile
  (or their category's) because the automation path is now kind-agnostic
  rather than task-only, and the finished transcript wakes the relationship
  agent so the briefing catches up with what was just said.

  The button only needs a **transcription model** — not the category's
  automatic-inference switch. That switch governs unattended runs, so when it
  is off (or the person has no category at all) the sheet runs the
  transcription the user just asked for itself, rather than refusing. With no
  model configured anywhere it says so before recording, instead of capturing
  audio for a transcript that can never arrive — and if the recording sheet's
  speech-recognition checkbox was unticked for that take, it says so straight
  away rather than waiting out the transcription timeout.

  Transcription accuracy for names comes from the **category's
  `speechDictionary`**: terms listed there are sent to the provider as
  context bias and injected into the transcription prompt, so a category
  used for people should list the names it expects to hear. It is edited in
  category settings, and applies to every recording in that category — a
  spoken check-in included.

- `service/relationship_reminder_service.dart` — **OS check-in reminders**
  (plan v2 phase 8, ADR 0039). The banner needs the app open; this covers the
  case it cannot. The deterministic tier's cadence verdict is projected onto a
  durable notification row armed *ahead* of the due day, so the OS is already
  holding the alarm when the app closes. One row per cadence episode, retracted
  and replaced when a check-in moves the due day, and cleared outright when a
  person stops being eligible or is deleted. Lock-screen copy carries the
  person's name and nothing else about them.

- `service/` + `state/` + `ui/` — **contacts, quick actions and the
  post-call loop** (plan v2 phase 7, ADR 0041), on Android and iOS only.
  `contacts_service.dart` is the sole boundary to `flutter_contacts`, and
  `contact_import_mapper.dart` the sole file that knows its types; the
  import screen, the link action and their tests all run without a platform
  channel. The People tab gains a multi-select import (pick, then set
  importance and cadence per person before anyone is created), the detail
  page gains "Link contact" / "Update from contact" — a merge that never
  discards a hand-typed channel and never overwrites the name — and each
  contact channel renders call/message/email buttons for the actions the
  device can actually service. Launching one records a device-local marker
  in `settings.sqlite` (never synced, never journalled), which the next
  resume turns into a pre-filled check-in offer.

Phases 1–8 are built; phase 9 (privacy documentation, the manual pages
and release readiness) is outstanding. Relationships and check-ins
deliberately do not appear in the main journal timeline; the People tab is
their home. Desktop keeps manual channel entry: contact import and the
quick actions are absent there, by design.

Privacy stance (ADR 0037): relationship data is the most sensitive class the
app holds — it describes third parties. It stays on-device, syncs only via
the user's own end-to-end encrypted Matrix rooms, and contact channels never
enter AI context. Concretely, `private` covers the whole person: a check-in
inherits the relationship's `private` flag when it is created, the detail
page resolves a private person to "no longer tracked" while private entries
are hidden (the list filter alone would leave the `/people/<id>` route open),
and the delete cascade reads check-ins unfiltered so hidden ones cannot
survive the person they describe.

Why check-ins are bound to a person twice, how the People list orders by
recency without a per-person query, the status lifecycle, and what the delete
cascade does and does not reach are documented in the knowledge bundle:

**→ [knowledge/features/relationships.md](../../../knowledge/features/relationships.md)**
