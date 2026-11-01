---
type: Feature Module
title: Events
description: A first-class destination for meaningful moments — its own entity rather than a task subtype, with a pure view layer and locale resolved at the presentation boundary.
resource: ../../lib/features/events
tags: [events, memories, view-models, localization]
status: stable
generated: { by: claude-code/fable-5.1, at: 2026-10-05T12:00:00Z }
stale_after: 2027-04-05
sources:
  - id: src
    resource: ../../lib/features/events
    title: Events feature source
    last_modified: 2026-11-01
  - id: timeline
    resource: ../../lib/features/events/ui/widgets/event_timeline.dart
    title: EventTimeline — the event's rows on DesignSystemTimelineRow, and its photo band
    last_modified: 2026-11-01
  - id: plan
    resource: ../../docs/implementation_plans/2026-11-01_event_agent_record.md
    title: Event agent record plan — image analysis, on-device search, person links
    last_modified: 2026-11-01
---

Events are the meaningful moments — a birthday, a trip, a wedding, an upcoming
race — promoted from a bare journal entry type to their own destination with a
memory-forward overview and a photographic detail page.

**Gated behind `enableEventsFlag`.** With it off, events are hidden *everywhere*:
the logbook query drops the `JournalEvent` type, `EntryDetailsWidget` renders a
linked event as nothing, the tab, create-event and type-filter affordances are
absent, and the Daily OS timeline's recorded lane — and the planner's
recorded-time lookback behind it — leave events out. The one exception is a
meeting planned with a person: an event linked from a live `RelationshipEntry`
shows on that person and on the Day view whatever the flag says (see
[relationships](relationships.md)).

# An entity, not a task subtype

An event stays its own `JournalEntity.event` with `EventData`. It **reuses** the
generic infrastructure tasks happen to use rather than **inheriting** task
semantics — so it gets linking, categories and the entry substrate without
acquiring statuses, checklists, estimates or a task agent's contract.

# The view layer is pure

```mermaid
flowchart TD
    DB[(JournalDb + EntitiesCacheService)]

    subgraph Overview
      ESP[eventsOverviewControllerProvider<br/>query + categoryIds<br/>EVENT + LINK_CHANGED + pending cover refresh<br/>loadResolvedEventsPage paged] -->|ResolvedEvent page| OP[EventsOverviewPage]
      OP -->|eventCardDataFromEvent<br/>+ groupEventsIntoSections| OV[EventsOverviewView]
      OV --> CARD[EventCard / EventFeatureCard]
    end

    subgraph Detail
      EC[entryControllerProvider] --> DP[EventDetailPage]
      RLE[resolvedOutgoingLinkedEntriesProvider] --> DP
      DP -->|eventTimelineEntryFor<br/>eventTaskRefFor| DV[EventDetailView]
      DP -->|bottomBar| BAR[EntryActionBar<br/>add a task · record · Add sheet]
    end

    DB --> ESP
    DB --> EC
    OV -->|tap card → /events/:id| DP
    OP -->|New event → createEvent → /events/:id| DP
    DP -->|timeline open → /journal/:id<br/>?linkedFromId=:eventId| LEGACY[Entry detail surface<br/>confirmed unlink available]
```

Presentational widgets render plain view models; **pages own the glue** — they
watch providers, apply the locale-dependent labelling and grouping the view models
cannot, and feed the result to the widgets. The pure mapping and grouping logic is
unit-tested in isolation.

**Status and relative-date labels are resolved at the presentation boundary** from
the active localizations and locale-aware formatter. Persistence stores only
stable status enums and timestamps, **never rendered copy** — so changing the app
language updates both surfaces immediately without migrating an event.

# Finding an event

The overview header is the shared `TabSectionHeader` the Tasks, Projects and
Logbook tabs use — title and bell, then a real search field beside the filter
funnel — and the page, header and card grid share one content column
(`detailContentInsets`), so the title, the field and the first card start on
the same edge. There is no events-only chip row: the category filter works the
way the Tasks filter does.

```mermaid
flowchart LR
    Field[Search field] -->|every edit| SQ[setQuery]
    Funnel[Filter funnel] --> Modal[showEventsFilterModal<br/>shared filter modal,<br/>category page only]
    Modal -->|Apply| SC[setCategoryIds]
    Chip[ActiveFilterChip] -->|remove one| SC
    ClearAll["Clear all"] --> CF[clearFilters]
    SQ --> AF[_applyFilters<br/>generation++]
    SC --> AF
    CF --> AF
    AF --> Load[loadResolvedEventsPage<br/>first page]
    Load -->|generation still current| State[EventsOverviewState]
```

**Search is a substring match over the title and the note text, run in Dart.**
The full-text index does not carry event titles (`Fts5Db.insertText` indexes a
title only for tasks), so matching there would miss the one field a user
searches by. With a query, `loadResolvedEventsPage` reads the whole category
scope, keeps `eventMatchesQuery` hits and pages *those*; without one it pages in
the database as before. Covers resolve only for the returned page either way.

**Every keystroke reloads, and only the newest one lands.** Like the Tasks
search there is no debounce; `_applyFilters` bumps the generation that already
guards `loadMore` and sync refreshes, so a slow earlier keystroke cannot
overwrite a later result. Filter changes merge against the *requested* filter
(`_requestedQuery`, `_requestedCategoryIds`), which runs ahead of the committed
state while a load is in flight — otherwise a category picked before the query
landed would drop the query, and a clear typed before it landed would look like
a no-op. A sync refresh reloads that requested filter too, and every committed
reload bumps the generation once more, so a `loadMore` page read under the old
filter cannot land on the new list. The previous list stays on screen while a reload
runs, and a filter that matches nothing shows an empty state that offers
**Clear all** rather than a blank page.

**Categories are multi-select, behind the funnel.** `showEventsFilterModal` is
the shared `showDesignSystemFilterModal` with only the category field — Unassigned
(`''`) first, then each category with its icon and colour. With a single field
the shared modal opens straight on that field's page (see
[Tasks filtering](tasks/filtering.md#the-filter-modal)). Applied categories show
as `ActiveFilterChip`s in their own colours, the funnel tints, and from two
narrowings up — the query counts as one — a **Clear all** chip ends the session.

**New event** is the page's `DesignSystemFloatingActionButton`, a bare glyph
like Projects'. On phones the navigation launcher docks it instead
(`eventsTabDockAction`). The launcher itself leaves on an event's own page
(`isEventDetailRoute`), which docks the entry action bar in its place — see
[Adding to an event](#adding-to-an-event).

# One way in

There is **one** way to open an event: `/events/<id>`. Every entry point routes
there — the overview, a logbook card tap, a freshly created event, a linked
event inside a task's timeline, and the event's block on the Daily OS Day
timeline. A linked event renders as a compact summary card resolved the same
way the detail page resolves its cover, **not** the generic entry editor.

# On the day

An event with a span is recorded time on the Daily OS Day timeline: it sits on
the recorded lane at the start and end the date line gave it, titled and
coloured as the event itself — never as a task it hangs off — and its block
opens the event page. A cancelled, missed or postponed event stays off the
lane. The
query, the flag gate and the status rule live with the lane, in
[Daily OS UI surfaces](daily_os_next/ui-surfaces.md#tracked-time).

# The hero is the interaction surface

Title is tap-to-edit; category and status pills open shared pickers; the date
line opens the shared date-time modal and is **the single source of the event's
when** — the body no longer repeats it.

**Rating stars only appear once the event has happened** or already carries a
rating, so a fresh or tentative event is not pushed gold stars. When they do,
they sit **in the state row** — category, status, stars — a `Wrap` that
reflows on a phone rather than overflowing. `EventStarRating` makes each star
its own `DsQuietInk` target: a tap sets that many stars, a long press the half
below, and hovering lifts only the star under the pointer. Nothing paints
across the row as a whole; the third-party `StarRating` it replaced gave every
star an ink radius as wide as the star itself, so its hover spilled over the
neighbours and read as one highlight around the group.

**Under the title, the event agent says what happened.** The hero carries the
`oneLiner` of the agent's newest report; the recap card below the hero carries
its `tldr`. Both are tiers of the one report the agent writes (see
[project and event agents](agents/project-and-event-agents.md#event-agents)),
read by the page through `eventAgentProvider` → `agentReportProvider`. `.value`
keeps the last line through a background reload. With no agent, or no
one-liner yet, the hero is title and date alone — the user's own note never
stands in for it.

**The recap card is the task agent's card.** `EventAiSummaryCard` builds on
`AgentSummaryCardSurface` — the shared `aiCardDecoration` wash, hairline and
radius, with no shadow — in the task card's reading order: `TldrHeader` (the
agent's name opens `AgentInternalsPanel`), `TldrBody` with *Read more* for the
full recap, then the compact `AgentAutomationRow` whose *Update now* re-wakes
the agent through `EventAgentService.triggerReanalysis`. Before the first recap
the body is the awaiting hint; a failed load says so instead; a first load in
flight shows the header alone. Without an agent, the passive summary (the
event note or the newest linked AI response) sits on the plain
`EventPassiveSummaryCard` — the design-system section card with a `plain`
`TldrHeader`, since no agent wrote it — and offers no refresh.

**Cover art becomes automatic then explicit**: while there is no linked photo,
an "add cover photo" action opens the create-entry menu; the **newest** linked
photo then stands in as the cover — a default that moves with every newer
photo, on the overview card and the detail hero alike (`_resolveEventCovers`
and `eventDetailDataFromEntities` pick it the same way, so the two never
disagree). A cover becomes *chosen* only through `coverArtId`, and the view
model says which is which: `EventCardData.coverChosen` and, on the gallery's
photos, `EventPhoto.isCover` (chosen only, never the default — so a `coverArtId`
pointing at an unlinked or deleted photo counts as no choice). Three surfaces
set it, all through `EntryController.updateEventCover`: the overflow menu's
picker (`showEventCoverPicker`), a "Set cover" chip on the hero that opens the
same picker while the cover is only the default, and the full-screen viewer's
"Set cover" pill for the photo in view (`EventPhotoGalleryViewer.onSetCover`,
forwarded through `EventPhotoGrid`). The viewer sits on the root navigator
with a snapshot of the photos, so it advances its own cover id optimistically
to flip the pill to "Cover" at once and awaits the write. The controller's
event edits (`_updateEventData`) return the persistence layer's verdict and
roll their own optimistic state back on `false` (the entity is gone); the
viewer takes the pill back on `false` or on a thrown error — the latter also
captured under the `event_photo_gallery` log domain like the download button
does — and shows the shared save-failed line. One gap is deliberate and lives
below this feature: `updateEvent` logs a storage exception and, by its
documented contract (pinned in `persistence_logic_test`), reports `true`, so
such a failure is invisible to every event edit on the page, not only to the
cover; the grid's "Cover"
badge follows on the page's next resolve. When the grid is capped, the "+N"
tile wears the badge whenever the chosen cover is among the photos it stands
for. The viewer chips — counter, date, badge, labelled action — all sit on one
`ImageViewerPill` shell in the journal's image-viewer widgets.

Linked photos render as a compact grid and open into a swipeable, zoomable
full-screen gallery. The gallery contains each image without changing its aspect
ratio, downloads the currently visible file, shows its capture/file date, hides
all chrome on a single tap, and keeps pinch zoom/pan while rotation is disabled.
It participates in the shared mobile image-viewer orientation lifecycle described
in [shared widgets](../architecture/shared-widgets.md).

**The timeline is the goal and person timeline.** `EventTimeline` puts each
linked entry on a `DesignSystemTimelineRow`, the row Goals and People hang on
their rails: a neutral tile naming the kind (note, photo, voice note, time
recording), a `time · kind` meta line, the words as `FoldedWords`, a recording
as the light `RecordingPlayback` with its `RecordingTranscript`, a recorded
span as its `TimeSpanBar`, one spoken sentence per row, and the whole row as
the door to its entry (`onOpenTimelineEntry`, inert without one). A recording
missing its span labels reads as a note.

What stays the event's own is the photo: a photo row carries the picture in
its footer as a **wide, short band** (`EventTimelinePhotoBand`) at 2.4 : 1 of
the column, held between 96 and 180 logical pixels tall, so it reads as a
strip on a phone instead of a block that pushes the next row off screen —
where a person's timeline shows a small thumbnail strip, an event is
photo-led. Under the band, its caption is the photo's **one-line summary** — the `oneLiner` of its newest
image analysis (`imageAnalysisOneLiner`, the same source the journal's
collapsed image row uses), falling back to the user's note — held to two
lines. The page watches each photo's analyses, so a caption appears in place
when an analysis lands after the photo; the pure mapping receives them as
`imageSummaryFor`.

The overview controller refreshes its loaded window for event entity
notifications and for `LINK_CHANGED` notifications whose endpoint ids include
an event currently loaded in the overview. Photo links are separate rows from
the event, so listening only for `EVENT` leaves fallback covers stale after
local linking or sync; gating by endpoint avoids reloading covers for unrelated
task and journal links.

Sync can apply the event→photo link before the photo's own entry (links are
also sent as their own messages, and `linked_entries` has no foreign keys). The
refresh then finds no photo, and the photo's later apply notifies only its own
id and `IMAGE`. So `_resolveEventCovers` reports every `coverArtId` or linked id
whose row is missing as `ResolvedEvent.pendingCoverIds`, and the controller also
refreshes when a notification names one of them.

The photo's bytes travel separately again: its entry can apply before the file
lands, and nothing is notified when the file does. `EventCoverImage` therefore
shows the fallback while a `FileImage`'s file is missing and watches for it
(`FileWatcherMixin`, which also covers a date directory that does not exist yet
and the atomic rename sync writes with); decoding early would leave the failed load in the image
cache under that key, where every later card for the photo would find it.

Opening a timeline source preserves the event id as `linkedFromId`. Mobile
passes it into the pushed detail page; desktop mirrors it beside the selected
entry id into the split pane. The journal detail resolves that exact live link
and exposes the existing confirmed unlink action; once removed, the link
notification updates the event timeline, gallery, and overview cover without
deleting the photo entry.

**When a callback is null the corresponding control is read-only or hidden**, so
the same widget renders cleanly in screenshots and tests. An empty event renders
the Timeline header over a quiet hint naming what the bar below adds — and no
Tasks section at all.

# Who it was with

An event's people are the people whose timeline holds it: the live
`RelationshipLink`s **from a person to the event** — the same rows that put
it on that person's page ([relationships](relationships.md)). There is no
second "attendee" list to keep in step; adding someone to an event *is*
putting the event on their timeline, so "what did I do with this person"
(read from the person) and "who was at this event" (read from the event) are
one fact.

```mermaid
flowchart LR
    P1[RelationshipEntry Pip] -- RelationshipLink --> E[JournalEvent]
    P2[RelationshipEntry Rocko] -- RelationshipLink --> E
    E -->|personTimelineLinkSources| ROW[EventPeopleRow on the event page]
    P1 -->|personTimelineLinkTargets| TL[Pip's timeline]
    E -->|getTypedLinksForTaskIds| CTX[Event agent: ### People]
```

- **Read.** `peopleOnEntryProvider(eventId)` reads
  `PersonTimelineRepository.getPeopleOn` — the link sources, resolved with
  the private filter, by name — and re-reads when a link to the event is
  written or tombstoned (both notify the event's id), when a person shown
  changes, and when private entries are shown or hidden. The page reads it
  with `.value`, so the row never blanks while it re-reads.
- **Show.** Under the recap, a *People* section of `DesignSystemChip`s, each
  with the person's `PersonaAvatar` and name, opening `/people/<id>`, then an
  *Edit people* chip. With no one linked there is no section, only an *Add
  people* chip — people are an attribute of the event, like its category,
  not content the action bar adds.
- **Change.** The chip opens `showPersonPicker`, the multi-select
  `EntityPickerSheet` over the People list (search by name or nickname,
  staged until *Apply*). `PersonTimelineRepository.setPeopleOn` writes only
  the difference: `addToTimeline` for each person added, `removeFromTimeline`
  for each one dropped. A write that did not land raises
  `eventsPeopleSaveFailed` above the bar; the row re-reads either way, so it
  shows what was stored.
- **Recap.** `EventAgentContextBuilder` lists the people first in the
  linked-entries digest (see
  [project and event agents](agents/project-and-event-agents.md#event-agents)),
  and a link write notifies the event id, so the event agent wakes to name
  who was there.

# Adding to an event

An event is a `JournalEntity`, so its page ends in the very same
`EntryActionBar` an entry's page does ([journal
overview](journal/overview.md#create-import-and-paste)): `EventDetailPage` hands
it to `EventDetailView.bottomBar`, which docks it in the Scaffold's
`bottomNavigationBar` slot over an extended body and consumes its height with a
trailing `SliverPadding`, exactly as `EntryDetailsPage` does. Left to right:

* **Add a task** — `EntryCreationService.createTaskAndOpen` creates the task
  linked *from* the event and in its category (so the event shows under the
  task's "Linked from"), hands it the category's default agent and opens it. A
  task made here is the event's preparation or follow-up.
* **Record** — the shared `GlassRecordButton`
  ([recording UI](speech/recording-ui.md)), lit while a recording linked to
  *this* event is in progress. A recording made here is the event's voice memo.
* **Plus** — the Add sheet (`CreateEntryModal`) with `linkedFromId` set to the
  event, for photos, notes and the long tail.

The sections carry **no add buttons of their own** any more, and the **Tasks
section exists only once a task is linked** — on a wide body the tasks rail
appears with the first task, and an event without one reads as a single column
at every width. The one add affordance outside the bar is the hero's cover pill
while there is no cover ("Add cover photo", which opens the same Add sheet),
because the cover is the hero's own concern.

Two consequences follow the entry page's lead. The page nests a
`ScaffoldMessenger` so a toast raised on it — the delete-failed line, anything
the recap or change-set cards show — floats above the bar rather than at the
window's bottom edge under it. And the mobile shell **unmounts the launcher on
`/events/<uuid>`** — menu button, docked create action and activity island
alike — so the bar docks flush with the home indicator
([navigation](../architecture/navigation.md#chrome-rules-are-pure-functions-of-router-state)).
Go back to reach the overview and its launcher, as on a task or an entry.

# Related

* [Project and event agents](agents/project-and-event-agents.md) - the recap writer, and the human-only rating/cover invariant.
* [Event agent record plan](../../docs/implementation_plans/2026-11-01_event_agent_record.md) - the proposed next steps: people on the event page, events and recaps in on-device search.
