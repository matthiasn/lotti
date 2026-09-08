# People (relationships) — what exists today

An as-implemented inventory of the People feature at
`2fac43d50`, written to be handed to a designer alongside
[the screenshot bundle](SCREENSHOTS.md). Every claim here was read out of the
code, not out of an earlier design document; where a shipped surface diverges
from the 2026-09-06 design handover, the code wins and the divergence is named.

Product framing lives in
[`lib/features/relationships/README.md`](../../../lib/features/relationships/README.md);
the architecture is
[`knowledge/features/relationships.md`](../../../knowledge/features/relationships.md).
This document exists to answer one question a designer will ask first: *what
is actually on screen right now, and what is it made of?*

## 1 · Shape of the feature

A personal CRM for a deliberately small set of people, behind the
`enable_relationships` flag. Two journal entity types carry it:

| Entity | Payload | Owns |
|---|---|---|
| `JournalEntity.relationship` | [`RelationshipData`](../../../lib/classes/relationship_data.dart) | one tracked person |
| `JournalEntity.checkIn` | [`CheckInData`](../../../lib/classes/check_in_data.dart) | one logged interaction |

Routes: `/people`, `/people/<id>`, `/people/<id>/chat`. Phones push pages;
desktop renders a list/detail split and writes the selection into
`NavService.desktopSelectedRelationshipId` from the URL.

`RelationshipData` today: `title`, `nickname`, `status`
(active · dormant · archived), `important`, `checkInCadenceDays`, `birthday`,
`profileId`, `languageCode`, `contactChannels`, `contactRefs` — **and
`coverArtId`, which nothing reads.** See §5.

## 2 · The surfaces

### People list — `relationships_page.dart`
`people_list_*.png`, `people_list_empty_*.png`, `people_list_rows_mobile_dark.png`

- Summary card above the list: due-now over enrolled, who lapses next, how many
  are not enrolled. The due count carries warning ink only while non-zero.
- Three bands in fixed order — **Due · On track · Not enrolled** — empty bands
  omitted, each most-recent-contact first
  ([`people_list_model.dart`](../../../lib/features/relationships/ui/model/people_list_model.dart)).
- A row is: **persona avatar (40 px)** · name + sparkle when important · one
  monospace status line (`Call · Sat 1 Aug 12:44 · Weekly`) · a truthful
  cadence pill. "Truthful" is load-bearing: an overdue person reads
  `5 days over`, never `Due Sun`.
- Desktop: 416 px list pane, resizable divider, detail pane, and the selected
  row wears a wash.

### Person page — `relationship_details_page.dart`
`person_page_*.png` (four states, two viewports)

Top to bottom:

1. **Hero** (`PersonHeroAppBar`) — a pinned `SliverPersistentHeader`, **not** a
   `SliverAppBar`, so the avatar can hang past its lower edge; every app-bar
   layer would clip that overhang. It is a **flat teal wash with no imagery**:
   `Color.alphaBlend(interactive.enabled @ SurfaceAlphas.tint, background.level01)`
   (`PersonHeroAppBar.washColor`). Carries back · Talk to agent · edit · kebab.
2. **Persona avatar**, 80 px (`spacing.step11`), overlapping the hero's fold.
3. **Header block** — eyebrow (`Penguin Operations · Important`), wrapping name,
   the teal one-liner (`"Pip" · last spoke Sat 1 Aug 12:44`), then pills from
   the *list's own* rules so page and list never disagree about "due".
4. **Briefing card**, **Next time**, **Check-ins** (a `DecoratedSliver`, so an
   unbounded log stays lazy inside a card), **Reach**, **Tasks**.
5. **Action bar** — a glass strip: *Log check-in* · mic · the first channel the
   platform can actually open.

### Relationship agent card — `relationship_briefing_card.dart`
`agent_card_*.png` — all six faces plus the proposals band

`relationshipAgentCardStateOf` is a pure function of four signals and returns
one of: `notEnrolled`, `noBriefing`, `running`, `failed`, `current`,
`outOfDate`. Health bands are `thriving · steady · needsAttention · strained`,
parsed from report provenance. The card also hosts the suggestions band, where
the agent proposes tasks read out of check-in commitments.

### Check-in sheet — `check_in_capture_sheet.dart`
`check_in_capture_*.png`, `check_in_edit_*.png`

How it felt (sentiment chips) → what you talked about (narrative, *Speak
instead*) → when and how long (type chips, Started, Duration) → **More**,
folded, for topics and the two next-time fields. Save is pinned; editing adds
Delete. Sentiment: delightful · good · neutral · strained · difficult.
Interaction type: inPerson · call · videoCall · message · other.

### Person form — `relationship_form_modal.dart`
`person_form_add_*.png`, `person_form_edit_*.png`

Three cards — **Who** (name, nickname, category, status while editing),
**Important** (the consent switch, one line saying what it turns on, cadence
presets only once on), **How to reach them**. Cadence presets are
`[null, 7, 14, 30, 90]`. Save is pinned.

**There is no image field anywhere in this form.**

### Contact import — `contact_import_page.dart`
`contact_import_select_mobile_dark.png`, `contact_import_review_mobile_dark.png`

Two steps: bulk pick, then a per-person review that decides importance and
cadence. Nothing is written until the last button. Android/iOS only.

### Agent chat — `relationship_chat_pane.dart`
`person_chat_*.png`

The shared `AgentChatView` under an identity header: sparkle, `<name> ·
briefing agent`, and the line naming the boundary — *Knows your check-ins, not
the channels*. A page on phones, the detail pane on desktop.

## 3 · How a person is identified today

Identity is **one letter on a tinted circle**. There is no photograph anywhere
in the feature.

[`persona_avatar.dart`](../../../lib/features/relationships/ui/shared/persona_avatar.dart):

- `personaAccentForId(id, brightness)` folds the id with FNV-1a 32-bit and
  indexes a six-entry palette — `interactive.enabled`, the two hand-authored
  goal hues (neon, aurora), and the `ink` variants of warning, info and
  success. Deterministic, so the same person keeps the same accent on every
  device and the list does not reshuffle colours when it reorders.
- `PersonaAvatar` draws that accent at 20 % alpha as the fill with the initial
  in the accent itself, at `size * 0.42`.
- `personaInitial(name)` is the first character uppercased, `·` when blank.

Three sizes are in use: **40** (list row, the default), **48**
(`spacing.step9`, import review), **80** (`spacing.step11`, person hero).
`persona_avatar_palette_*.png` shows the whole palette and all three sizes.

## 4 · The image machinery that already exists elsewhere

Nothing below is wired to relationships — it is the vocabulary a design should
reuse rather than reinvent.

| Piece | Where | What it does |
|---|---|---|
| `JournalImage` / `ImageData` | [`journal_entities.dart`](../../../lib/classes/journal_entities.dart) | `imageDirectory` + `imageFile` relative to the documents dir, `capturedAt`, and an optional base64 **ThumbHash** — a few dozen bytes that decode into a blurred stand-in drawn until the file is on disk |
| `getFullImagePath` | [`image_utils.dart`](../../../lib/utils/image_utils.dart) | resolves an entity to an absolute path |
| `CoverArtThumbnail(imageId, size, cropX)` | [`cover_art_thumbnail.dart`](../../../lib/features/tasks/ui/cover_art_thumbnail.dart) | square thumbnail; watches the file (`FileWatcherMixin`) so a late sync arrival repaints; paints the ThumbHash meanwhile |
| `EventData.coverArtCropX` | [`event_data.dart`](../../../lib/classes/event_data.dart) | **a normalized `0.0…1.0` horizontal crop offset, defaulting to `0.5`** — the only crop the app has |
| `EntryController.updateEventCover(imageId, cropX)` | [`entry_controller.dart`](../../../lib/features/journal/state/entry_controller.dart) | writes both, clamping the crop |
| `TaskEntryController.setCoverArt(imageId)` | same | optimistic local update, then persist |

So the app can already store a picture, place it, survive sync latency, and
remember **one axis** of framing.

## 5 · Findings a design needs to know

1. **`RelationshipData.coverArtId` exists and is dead.** Declared with the
   comment *"ID of a linked JournalImage to use as cover art"*, it is written
   by nothing, read by nothing, and rendered by nothing. `Task`, `Event` and
   `Project` all carry the same field and all use it. A design is free to
   redefine what it means for a person rather than inherit "cover art".
2. **There is no two-axis crop anywhere in the app.** `coverArtCropX` is
   horizontal-only, which is enough for a wide banner and *not* enough to put a
   face inside a circle. A LinkedIn-style avatar crop (pan in both axes plus
   zoom) is new interaction surface, not a reuse.
3. **The hero is already banner-shaped and deliberately empty.** The design it
   came from records "cover-style hero (teal wash, **no imagery**)" as a
   decision. Putting an image there reverses a decision that was made on
   purpose; the design should say why, and what happens to the eyebrow, the
   name and the teal one-liner that currently sit on that wash.
4. **The persona accent is a real system, not a placeholder.** It is also the
   fallback for every person without a photo, and it is what the agent's beat
   rail reuses. Whatever a photo does, the accent has to keep working beside it.
5. **The import review derives the accent from the OS contact id, not the
   relationship id** (`draft.contact.id` in `contact_import_page.dart` versus
   `relationship.id` everywhere else), so a person visibly changes colour the
   moment they are imported. Compare the two import screenshots against the
   list. This is a bug the code has today, and a photo would mask rather than
   fix it.
6. **Cover-art cleanup only knows about tasks.**
   `JournalRepository._clearCoverArtReferences` clears `coverArtId` when the
   image behind it is deleted — but only `if (entity is Task)`. Events and
   projects already leak dangling ids; a relationship would too.
7. **Everything syncs.** Relationships and check-ins move through the user's
   own end-to-end encrypted Matrix rooms, and images move as files. A photo is
   therefore a *file* that arrives after the entity referencing it — which is
   exactly why `CoverArtThumbnail` watches the filesystem and paints a
   ThumbHash first.
8. **Contact channels never enter AI context** (ADR 0041 §5). A photo is a new
   kind of personal data on the same page and the design should say plainly
   whether the agent may see it. Today it cannot see anything but check-ins.
