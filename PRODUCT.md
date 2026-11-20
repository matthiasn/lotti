# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

Recorded as `web` because Lotti ships one custom design language everywhere,
not because it is a website. It is a Flutter app on macOS, Linux, Windows, iOS
and Android, with no OS-native look and no per-OS adaptation.

## Users

An individual knowledge worker, often a developer, who cares about privacy.
They plan work and record what actually happened, moving between a desktop and
a phone: tasks, tracked time, voice notes, journal entries, and optionally
habits, health data, goals, people and events. They want AI help that reads
the record and suggests things, without acting on its own. The author uses it
daily and has tracked around 11,000 hours of work in it since 2022.

Direction: Lotti is expanding beyond work tracking toward broader personal
use, running life as well as work through the same record (habits, health,
goals, people, events, journal). Design for the knowledge worker first, and
don't make choices that lock the product into work-only framing, wording or
structure. Who the broader audience is has not been decided yet.

## Product Purpose

A private logbook for the work you actually did. Lotti keeps what you meant to
do (tasks, planned blocks) apart from what happened (time records, with the
notes, photos, recordings and measurements that explain them), so the record
stays honest when the week goes off plan. Persistent agents read the record,
keep the mess summarised and propose the next step. It succeeds when the
record is trustworthy and up to date and keeping it costs little effort.

## Positioning

- **Intent and reality are separate records.** Most tools flatten them into one
  list.
- **Agents propose, you decide, by construction.** Agent state and the user's
  record live in separate databases, and agent changes reach the record only
  through an approval path (the pre-approved exceptions are listed in
  `docs/adr/0102-pre-approved-agent-changes.md`).
- **No server ever holds your data in readable form.** Data is local-first and
  synced end-to-end encrypted over a Matrix relay that holds only ciphertext,
  and not forever. There is no telemetry.
- **The sync protocol and agent runtime are formally verified** (TLA+, in
  `specs/tla/`).
- **Inference runs on the user's own key, routed per category.** AI is
  optional. The recommended route is open-weight models on European
  infrastructure. Speech recognition can run fully offline.

## Operating Context

- Desktop for long sessions, such as reviewing tasks, planning the day and
  reading agent reports. The phone is for quick capture: voice notes, a timer
  started on the go, photos.
- Background sync and agent wakes happen while the user is looking at a
  screen, so surfaces refresh underneath them.
- Applications on the shared record: Tasks and the Journal are on by default.
  The rest are Sections the user switches on under Settings → Sections: Daily
  OS (day planning), habits, dashboards and insights, goals, people, events,
  GitHub pull request tracking, and the companion chat. Turning a section off
  hides it and deletes nothing.
- There is a user manual (Docusaurus site in `docs-site/`) with
  deterministic screenshots and tutorial videos generated from the real app.

## Capabilities and Constraints

- Every feature runs on all five platforms. No native-only tools.
- Every user-visible label is localized in every catalog in `lib/l10n/` (12
  catalogs, `app_en_GB.arb` handled as described in
  `knowledge/conventions/localization.md`).
- Visual values come from the design-system tokens exported from Figma
  (`assets/design_system/tokens.json` → generated Dart tokens). No ad hoc
  colors, spacing or type, see `knowledge/features/design_system/`.
- Background refresh never flashes established UI. Sync or database-driven
  reloads keep the last rendered data. Full loading shells are only for initial
  loads and deliberate navigation.
- Structured agent output on chat surfaces is drawn as A2UI components
  (`docs/adr/0163-chat-surfaces-are-a2ui-drawn-by-a2ui-flutter.md`), not
  Markdown.
- Terminology in use: task, time record / time entry, checklist, category,
  project, label, agent report, proposal (confirm / dismiss), Daily OS, Sections.
- Hosted Lotti Sync is not live yet. Do not present it as available.

## Brand Commitments

- Name: Lotti. License GPL-3.0. In development since 2016.
- **Agents propose, the human confirms.** Every agent-initiated change is
  shown as a proposal with dismiss and confirm. Except for the ADR 0102 set, no
  surface may imply an agent changed the record on its own.
- **Voice:**
  - Informal register in every language, with Romanian as the deliberate
    exception.
  - Sentence case, never all-caps (no uppercased labels or ARB values).
  - Companion copy is gender-neutral (no her/she).
  - Goal-surface copy is short and in the agent's first person.

## Evidence on Hand

- `README.md`: the positioning, architecture and privacy claims above, in the
  author's words.
- Manual and screenshots: `docs-site/`, with screenshot cases in
  `docs-site/metadata/screenshot-cases.json`, published per channel to R2.
- Fixtures for any capture or mock: `test/test_data` and the penguin demo
  world only. Never use the user's own tasks, notes, habits or people.
- Formal verification ledger: `specs/tla/LEDGER.md`.
- Absent: there are no testimonials, customer logos, press, pricing or usage
  statistics beyond the author's own hours and the public Flathub/GitHub
  download badges. Do not invent any of these.

## Product Principles

1. **The record is honest.** Surfaces show what happened apart from what was
   planned, and never blur a suggestion into a fact.
2. **AI assists and never acts unseen.** Agent output carries provenance and
   waits for a human decision.
3. **Private by construction.** Design choices never assume a server can read
   the data, and never add telemetry.
4. **Calm over time.** The app is open all day while things sync underneath.
   Stability and low churn outrank novelty.
5. **One product everywhere.** The same behavior and language on every
   platform and in every locale.
