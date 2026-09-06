# People section redesign — implementation plan

Design: `~/Desktop/design_handover/people_handover/design_response/` (Claude Design,
2026-09-06, answering `HANDOVER.md` and `AGENT_CARD_CONCEPT.md` in the same folder).
Approved by the product owner on 2026-09-06 ("implement the redesign as in the zip").

The person page becomes a sibling of the task page: a cover-style hero, a header block
with the cadence fact and health band as pills, the relationship-agent card with a
suggestions band, a Next time card, then section cards for check-ins, contact channels
and tasks, above a bottom action bar. Desktop uses the Tasks list/detail split. The
People list gains grouping, a summary card and truthful pills.

## Decisions carried over from the design (do not relitigate)

| Topic | Decision |
|---|---|
| Header | Cover-style hero (teal wash, no imagery) with persona avatar overlapping the fold; full wrapping name; nickname + last contact as the teal one-liner; back · Talk to agent · edit · kebab (delete, link contact). |
| Star | Dropped. "Important" appears in the eyebrow and as the agent card's enrolment state; the switch stays in the edit sheet. |
| Desktop | List/detail split (Tasks pattern): rail · 416 px list pane · detail pane with an 880 px centred column. Chat renders in the detail pane. |
| List | Grouped Due · On track · Not enrolled, due-first; row = avatar, name + sparkle (important), one mono status line (`Call · Today 12:44 · weekly`), truthful pill (`5 days over` warning, never "Due Sun"). Summary card mirrors the Goals list. |
| Check-ins | Rows in one section card: mono `timestamp · type · duration`, tinted sentiment pill (Delightful=success, Good=teal, Neutral=grey, Strained=warning, Difficult=error), narrative, topic tags. |
| Post-call offer | A highlighted state at the top of the Check-ins card naming channel, start time and elapsed time. |
| Duration | Wheel; inline when the value is known (prefilled from the call), collapsed behind a Duration field otherwise; "No duration" is a wheel position; `dateTo − dateFrom`, no schema change. |
| Brief me | Becomes *Update now* in the controls footer; the empty state keeps a primary *Brief now*. |
| Next time | Its own card between the briefing and the check-ins, from the latest check-in. |
| Chat entry | Page header ("Talk to agent"), not the card footer. |
| Confirm all | Only when every pending suggestion is the same kind. |
| Tokens | Existing tokens only; the tinted pills need named `tint-*` washes — flagged, not invented. |

## Increments (one pull request each)

### A · People list and the desktop split
- `RelationshipListItem` gains the latest check-in's interaction type (one aggregate
  query, no N+1: extend `latestCheckInTimes` to return the newest check-in row per
  person).
- Grouping (Due · On track · Not enrolled) with counts; row status line and truthful pill
  (`{n} days over`, `Due {weekday}` within a week, `On track`, `Not enrolled`,
  `Dormant`/`Archived`); sparkle replaces the star.
- Summary card: due-now count over enrolled count, next due person and day, not-enrolled
  count; empty and all-clear variants.
- Header: labelled *Add person* button on desktop; import icon with tooltip on phones.
- Desktop split via `NavService.desktopSelectedRelationshipId`, `RelationshipsLocation`
  mirroring `ProjectsLocation`, the shared pane-width controller and the empty state.
- Tests: grouping/pill logic as property tests, row and summary widgets, split behaviour.

### B · Person page
- Hero (`GlassBackButton`, glass actions: Talk to agent, edit, kebab with delete and
  link-contact), header block (eyebrow, name, one-liner, pills: cadence fact, health
  band, next due), `DesignSystemSectionCard` sections in the design's order, bottom
  action bar (Log check-in · mic · actionable channel) replacing the floating button.
- Next time card from the latest check-in; Check-ins card with rows and the post-call
  state at the top; Reach card with the privacy line and 40 px circular actions; Tasks
  card with status glyphs.
- Desktop detail pane hosts the page in an 880 px column; the tab bar stays hidden on
  phones.

### C · Relationship agent card
- States: not enrolled (Mark important), enrolled without briefing (Next look · Brief
  now), thinking, current (cost pill, freshness, controls footer with Update now,
  automatic updates, model row), out of date, failed (reason inline, Choose a model),
  due (Log check-in · Call).
- Suggestions band over the generic change-set ledger, hidden while empty; the agent
  tools that would fill it (schedule a call, create a task) are a separate project.

### D · Check-in capture with duration
- Order: how it felt → what you talked about (+ Speak instead) → when and how long
  (type chips · Started date+time · Duration wheel) → More (folded). Pinned Save.
- Prefilled source strip; duration prefilled from the pending marker's start time;
  wheel positions none · 5 · 10 · 15 · 20 · 30 · 45 min · 1 h · 1 h 30 · 2 h · 3 h ·
  Custom; ranked by the user's own picks (estimate precedent).
- Desktop dialog with delete bottom-left. Check-in rows show the duration.

### E · Form, import, chat
- Edit person in three cards (Who · Important + cadence · How to reach them), category
  as a colour dot, privacy lines, "Add channel · or from contacts".
- Import review: cadence presets appear when Important is on; subtitle names the count.
- Chat: agent header (sparkle avatar, subtitle), desktop chat inside the detail pane with
  an Agent internals button.

Every increment: 100 % patch coverage, every new label in every catalog, a changelog
fragment, before/after captures from the handover recipe (`capture/` in the handover
folder), README and knowledge concept kept in step.

## Out of this plan
The suggestion-producing agent tools (S1 schedule a call onto the day plan, S2 create
and link a task, S3 add to a task) and the `tint-*` design tokens.
