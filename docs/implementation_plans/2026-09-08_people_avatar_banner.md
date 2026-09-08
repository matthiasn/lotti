# A photo and a banner for a person — implementation plan

Design: `~/Desktop/RelationshipsRedesign.dc.html` (Claude Design, 2026-09-08),
answering `docs/design/people_avatar_banner/HANDOVER.md` and the 38-capture
inventory beside it. **Direction 2b is the approved hero treatment** (product
owner, 2026-09-08: "go with 2b").

Only the board's *turn 2* sections apply. Turn 1 (`1a`/`1b`/`1c`, "three
directions for the relationship surface") predates #4178 — it describes the
pre-redesign People tab as "stock Material" and its proposals shipped across
#4178–#4187. It is history; do not implement from it.

A person gets two images. The **avatar** is a photograph wherever the tinted
initial is drawn today — People row (40), import review (48), person hero (80)
— with the persona accent surviving as a ring, so identity colour holds whether
or not there is a face yet. The **banner** takes the upper part of the person
hero while the teal wash keeps the bottom bar the avatar overlaps. The crop is a
manual two-axis pan plus zoom in a circular mask. The agent sees neither image.

## Decisions carried over from the design (do not relitigate)

| Topic | Decision |
|---|---|
| Hero | **2b.** Photo strip takes the toolbar and the upper band; the existing wash keeps the bottom bar as a solid strip the avatar overlaps. One new scrim over the photo only. The hard edge means the photo never blends with anything, and the wash still says "this is a Lotti page". |
| Avatar | The photo replaces the tinted fill; the accent becomes a ring (2 px, 3 px at 80). Same FNV-1a hash, same colour, the list never reshuffles. |
| Four avatar states | No photo (exactly as shipped) · photo + ring · arriving (ThumbHash under the ring) · id known with no ThumbHash (tinted initial inside the ring). **Nothing ever shows an empty circle.** |
| Glass actions | Become photo-neutral (dark glass, white glyph) whenever a banner is set — in both themes. |
| Name, eyebrow, one-liner | Never sit on the photograph. In 2b they are below the hero entirely, so this is free. |
| Crop | One finger pans both axes; two fingers or a slider zoom 1×–4×; the image is clamped so the circle is never empty. A **live 40 px preview** in the footer is the commitment moment — it shows the result at list size, where a face is hardest to read. Desktop takes mouse drag and wheel. *Use photo* writes image and crop together; cancel writes nothing. |
| Re-editing | "Change photo / Adjust crop / Remove" in a sheet under the avatar on the person page, and in the form's Photo card. Both edit the same fields. |
| Storage | `avatarImageId` + `avatarCrop {x, y, scale}`; `bannerImageId` + `bannerCropX`. The crop is a transform over the original, never a second file. |
| Faces on the list | Yes. Row anatomy unchanged: avatar fixed at 40, name truncates or wraps, the cadence pill keeps its column at every text scale. |
| Desktop | The banner spans the detail pane edge to edge; avatar, name and text keep the centred reading column. |
| Privacy | The agent never receives either image, the crop, or the fact that a photo exists. The sheet and the form each say so in one line, in the words the Reach card already uses. |
| Not doing | No face detection, no generated portraits. The crop is the user's hand. |

## Corrections to the design, from the code

The board was written against the inventory, not the source. Five claims do not
survive contact with it, and two of them make the work *smaller*:

1. **`spacing.step1` is `2.0`.** The design proposes a new `border.ring` token
   because "spacing has no step below 4". It does — `step1: 2.0`, `step2: 4.0`.
   The 2 px ring is already a token. Only the 3 px ring at size 80 is not; see
   Tokens below.
2. **Picking 2b deletes two of the five proposed tokens.** `scrim.photoFade` is
   2a-only and `SurfaceAlphas.backdrop` is 2c-only. 2b needs `scrim.photoTop`
   and `glass.photoNeutral`, nothing else.
3. **"Height grows 200 → 220" does not describe this app.** The shipped hero is
   `topPadding + kToolbarHeight (56) + bandExtent (spacing.step12 = 96)`. The
   mock's 200 px is 44 px of status bar plus 156, which *is* the shipped
   geometry within 4 px. **2b changes no height on either viewport** — it
   repaints the band, it does not grow it.
4. **`GlassStrip` does not "carry its own literals for the same reason".** It
   derives its fill from the theme surface with private alpha constants and
   hardcodes neither black nor white. `glass.photoNeutral` is a genuinely
   theme-independent departure and must be approved as one, not waved through
   as precedent.
5. **`bannerCropX` is not a reuse.** The `0…1` horizontal offset exists on
   `EventData`, not `RelationshipData`. It is a new field modelled on an
   existing one.

And one conflict the design could not have known about:

6. **`ImportedContact` discards contact photos on purpose.** Its doc: *"Photos,
   addresses, organizations, notes and birthdays are read from the OS but
   discarded here … the less of the address book Lotti holds, the less there is
   to leak (ADR 0037)."* The design's "Use the photo from Contacts" switch
   reverses that. See increment E — it is a decision for the product owner, not
   for the increment.

## Data model

`coverArtId` is **removed**, not migrated. The design proposes renaming it to
`bannerImageId`; that would be right if anything had ever written it. Nothing
has — no writer, no reader, no seed, on this device or any peer — so there is no
payload anywhere carrying the key, and `fromJson` ignores unknown keys in any
case. Removing it and adding four honest fields is the smaller change and leaves
no field whose name lies about its meaning.

```dart
/// Which part of the source image the circular avatar shows. Normalised to
/// the source, so the same crop survives a re-render at any size.
@freezed
abstract class AvatarCrop with _$AvatarCrop {
  const factory AvatarCrop({
    @Default(0.5) double x,      // 0…1, centre of the visible circle
    @Default(0.5) double y,      // 0…1
    @Default(1.0) double scale,  // 1.0 (image covers the circle) … 4.0
  }) = _AvatarCrop;
}

// RelationshipData gains:
String? avatarImageId,
AvatarCrop? avatarCrop,          // null means "unset", i.e. the default framing
String? bannerImageId,
@Default(0.5) double bannerCropX,
// and loses:
// String? coverArtId,
```

Both ids are `JournalImage` ids and both images are ordinary linked image
entries, so they sync as files exactly like a task's cover art — which is why
every surface needs the "arriving" state.

## Increments (one pull request each)

### A · The data model and a picker that returns an id

No visible change; everything downstream depends on it.

- `AvatarCrop`, the four `RelationshipData` fields, `coverArtId` removed.
  Clamp on write: `x`/`y` to `0…1`, `scale` to `1…4`, `bannerCropX` to `0…1` —
  the `updateEventCover` precedent, so a malformed synced value cannot persist.
- **`JournalRepository._clearCoverArtReferences` learns about relationships.**
  It is `if (entity is Task)` today, so deleting an image behind a person's
  avatar would leave a dangling id. Clear `avatarImageId`/`bannerImageId` (and
  the crop with the avatar) the same way.
- **A single-image pick that returns what it created.** `importImageAssets` and
  `importImagePickerFiles` are `Future<void>`; setting an avatar needs the new
  entry's id. Both already thread an `onCreated(JournalEntity)` hook for the
  analysis trigger — build `pickSingleImage({linkedId, categoryId}) →
  Future<String?>` on that hook (`wechat_assets_picker` with `maxAssets: 1` on
  mobile, `file_selector`'s `openFile` on desktop), rather than a second import
  path with its own conversion and EXIF handling.
- Tests: model round-trip and the clamps as property tests (`glados`, the
  pattern `people_list_model_test` already uses); repository cleanup with the
  fix reverted to prove the regression test bites; the picker returning the id
  and returning `null` on cancel.

### B · `PersonaAvatar` learns a photograph

- `PersonaAvatar` gains `imageId` and `crop` beside `initial`/`id`/`accent`/
  `size`, and renders the four states. Ring width from size; the accent is
  unchanged, so a person's colour is identical with and without a face.
- **Extract the image surface rather than duplicating it.** `CoverArtThumbnail`
  already watches the file (`FileWatcherMixin`), paints the ThumbHash while the
  bytes are missing, and repaints when they land. Lift that into one widget
  parameterised by shape and crop; `CoverArtThumbnail` becomes its square host
  and `PersonaAvatar` its circular one. Two copies of a filesystem watcher is
  the outcome to avoid here.
- Lands the face on all three existing call sites at once — People row, person
  hero, import review — because they all already go through `PersonaAvatar`.
- Tests: one file per widget; all four states; ring width per size; the crop
  transform; and the no-photo case asserted to render exactly what it renders
  today.

### C · The hero banner (2b)

`_PersonHeroDelegate` is private to `person_header.dart`, so this is one file.

- The delegate gains `bannerImageId` and `bannerCropX`. Geometry:

  | Band | Extent |
  |---|---|
  | Photo strip | `maxExtent − washBarExtent`, from the top |
  | Wash bar | `washBarExtent` = `kToolbarHeight` (56), at the bottom |

  The bar is exactly one toolbar tall — it mirrors the bar above it, which is
  the reason to prefer it over `step10` (64) and lose 8 px of photograph.
- `scrim.photoTop` over the photo strip only: black at 42 % fading to nothing
  by 70 % of the strip's height.
- Glass actions switch to `glass.photoNeutral` whenever `bannerImageId` is set.
- **Collapse.** The wash bar folds away first; at `minExtent` the pinned toolbar
  sits on the photo strip — inside the scrim's strong region, which is exactly
  what the scrim exists for, so the swapped-in name stays legible over an
  arbitrary picture. The avatar keeps its existing `bandOpen` fade.
- **Arriving:** ThumbHash under the same scrim; with none, the wash exactly as
  today.
- Desktop needs no work: the hero is already laid out at full pane width while
  content uses `contentInset`, so "banner spans the pane, text keeps the
  column" falls out of the existing structure.
- Tests: geometry per state; the scrim present only with a banner; collapse
  legibility; and **a test that no banner produces the same widget tree as
  today**, so the default path cannot drift.

### D · Choosing and cropping

The increment the ask is really about.

- **The crop surface.** Pan, zoom and clamp are pure functions over
  `(imageSize, viewportSize, crop)` — write them as such, property-test them
  (the circle is never empty at any scale in `1…4` for any offset), and let the
  widget be a thin gesture host over them. The 40 px live preview reads the
  same functions, so preview and result cannot disagree.
- **The avatar sheet** on the person page: Choose from library · Adjust crop ·
  Remove photo, under the privacy line.
- **The Photo card** in the person form: Face and Banner, "Drag to reposition"
  for the banner, the same privacy line. It is a fourth card above Who.
- **"Take photo" is deferred.** The design lists it; the app has no photo
  capture — `camera` is a dependency but only the desktop QR scanner uses it,
  so this is a new permission story on five platforms. Ship library-picking
  first and add capture as its own increment if it is still wanted.
- New labels in all 12 catalogs (`app_en_GB.arb` per the localization concept),
  informal register, Romanian formal.
- Tests: the geometry functions as property tests; the sheet and the card as
  widget tests; cancel writing nothing asserted against the repository mock.

### E · Import review — the colour fix, and a question

- **Ship the bug fix regardless.** The import review derives the persona accent
  from `draft.contact.id` while every other surface uses `relationship.id`, so
  a person visibly changes colour the moment they are imported. Derive it from
  the relationship id the import is about to create. This is independent of
  photographs and should not wait for them.
- **The contact photo needs a decision before it is built.** `ImportedContact`
  discards OS photos on purpose, citing ADR 0037. Adding a
  "Use the photo from Contacts" switch means either amending that ADR or
  declining the design here. Two defensible answers:
  - *Decline* — the user picks a photo like any other, and import stays as
    narrow as it is. Costs one design affordance, changes no ADR.
  - *Amend* — photo bytes enter `ImportedContact` (as `Uint8List`, so it stays
    plugin-free and testable in the pure-Dart VM), behind an on-by-default,
    per-person switch, written only on confirm. Costs an ADR amendment and a
    privacy-policy line.

  **Recommendation: decline for now**, ship the colour fix, and revisit with
  the ADR open rather than folding a privacy reversal into a UI increment.

## Tokens — flagged, not invented

Per the design-system rule, none of these are created without approval:

| Token | Value | Needed by |
|---|---|---|
| `scrim.photoTop` | black `0.42` → `0` over the top 70 % of the photo strip; theme-independent | C |
| `glass.photoNeutral` | black `0.45` fill, `#FFF` glyph, whenever glass sits on a photograph | C |
| Avatar ring at 80 | 3 px. `spacing.step1` (2.0) covers the 40 and 48 sizes; **3 px has no token** | B |

For the third, the cheapest honest answer is to use `step1` (2 px) at all three
sizes and drop the 3 px variant — the ring reads at 80 either way, and it costs
no new token. Confirm before building.

## Testing and evidence

- One test file per source file, extended in the increment that changes it.
- Every pure rule — the clamps, the crop geometry, the ring width — is a
  property test, not a table of examples.
- **The screenshot suite is already the before/after machine.**
  `people_inventory_screenshots_test.dart` captured all 38 "before" frames from
  the same fixtures; each increment adds its new states and re-runs
  `make people_inventory_screenshots` for the "after" half of the pair.
  Increment B alone should add the four avatar states, and C the banner, its
  arriving state and its collapsed state.
- Changelog fragments for B, C, D and E (all user-visible); none for A.

## Deliberately not in scope

- **Events and projects leak dangling cover-art ids too** — the same
  `if (entity is Task)` defect increment A fixes for relationships. Same four
  lines, different feature; worth its own small PR rather than smuggling two
  features' fixes into this one.
- Face detection, generated portraits, remote avatar services, a URL field.
- Any change to check-ins, cadence, the agent card or the chat.
