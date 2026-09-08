# People — a photo and a banner for a person

A design handover for Claude Design. Read
[`INVENTORY.md`](INVENTORY.md) first: it is what the feature looks like today,
and the [screenshot bundle](SCREENSHOTS.md) is the evidence for it.

## The ask, in the product owner's words

> I did quite a bit of work on the check-in with people, which works quite
> nicely. And what I would want is to be able to select a photo of the person.
> So I see right away what am I being reminded of, or who am I checking in
> with. And for that it would be good to have both a photo and a banner image
> — probably something with the person, or something that reminds me of the
> person — kind of similar to how you'd have an avatar image and a banner image
> in LinkedIn or Facebook. Adding some kind of user experience for the image,
> which for the avatar especially should be the possibility to crop the image.
> I think LinkedIn probably does something similar, where you select which part
> of the image is the actual face, and then crop it to that for the display.

## Why this is worth designing rather than just building

Recognition is the point. The People tab is a *reminder* surface — its job is
to tell you at a glance who is drifting. Today every person on that list is a
coloured circle with a letter in it, and five people is already enough for the
letters to stop reading as faces. A photograph does in one glance what the row
does in three tokens.

There is a second, quieter reason. The person page's hero is currently a flat
teal wash, and the design that produced it recorded "**no imagery**" as a
deliberate decision — because there was nothing to put there. There is now.

## What we are asking for

A design covering, at minimum:

1. **The avatar** — a photograph of the person, wherever `PersonaAvatar` is
   drawn today (list row 40 px, import review 48 px, person hero 80 px), and
   anywhere new that earns it.
2. **The banner** — a wide image behind the person-page hero, and what happens
   to the eyebrow, the wrapping name, the teal one-liner and the four glass
   actions that currently sit on that wash. Contrast over a photograph is the
   whole problem here.
3. **The crop experience**, and this is the part the ask is really about:
   choosing *which part of the image is the face*. Nothing in the app does
   this today — `EventData.coverArtCropX` is a single normalized horizontal
   offset, which frames a wide crop and cannot frame a circle. Expect to
   design pan in both axes plus zoom, a circular mask preview, and a
   commitment moment.
4. **Where the images are chosen from** — the person form has no image field at
   all today, and the person page's kebab has no image action. Both are
   plausible homes; so is the avatar itself as a tap target.
5. **The fallback**, which is not optional. Most people will have no photo for
   a long time, and some will never have one. The persona accent has to keep
   working beside photographs without the list looking half-finished.

## Constraints that are not up for negotiation

- **Design-system tokens only.** Colours, spacing, radii, typography,
  elevation come from the exported token set. If a scrim or a gradient over a
  banner needs a token that does not exist, *flag it* — the previous handover
  did exactly that for the tinted sentiment washes and it was the right call.
- **Both themes, both viewports.** Every surface here exists at 402 pt phone
  and 1440 pt desktop, in light and dark. The bundle carries the key surfaces
  in all four.
- **Offline and on-device.** No remote avatar service, no gravatar, no URL
  field. An image is a `JournalImage` on disk that syncs as a file through the
  user's own encrypted rooms.
- **The image arrives late.** On a second device the entity syncs before the
  file does. `CoverArtThumbnail` already solves this with a ThumbHash
  placeholder and a filesystem watcher; whatever is designed must have a
  defined appearance in the "id known, bytes not here yet" state.
- **Privacy is explicit here.** Contact channels are excluded from AI context
  by ADR 0041 §5. A photograph is new personal data on the same page; say
  whether the agent may see it. The safe default is no.
- **Nothing may regress the truthful pill.** The list's job is honesty about
  who is overdue. A photo must not push the cadence pill off the row at large
  text scales.

## Questions the design should answer

1. Does the banner replace the teal wash or sit under it? What is the minimum
   contrast treatment that keeps the name and the four glass actions legible
   over an arbitrary user photograph?
2. Does the avatar keep its accent ring / tint when there is a photo, so the
   person's identity colour survives?
3. Is the crop chosen once at pick time, or re-editable later? Where does
   "change photo" live?
4. What does the banner do on the desktop detail pane, which is 880 pt of
   centred column inside a wider pane?
5. Does a photo appear on the People *list* row, or only on the person page?
   (A list of faces is the strongest version of the ask — and the riskiest for
   row density.)
6. What does the import review show — the OS contact's own photo, if there is
   one, or nothing until the user picks?
7. What happens to `RelationshipData.coverArtId`, which already exists and
   means "cover art"? Is the banner that field, or do a person's two images
   want two fields with better names?

## What is deliberately not being asked

- No AI-generated portraits. `CoverArtSkillModal` exists for tasks; this is a
  photograph of a real person and generating one is the wrong instinct.
- No face detection. "Select which part of the image is the face" is a manual
  gesture in the ask, and manual is fine.
- No change to check-ins, cadence, the agent card or the chat.

## The bundle

`screenshots/` — 38 PNGs at device sizes with production fonts and tokens,
listed in [`SCREENSHOTS.md`](SCREENSHOTS.md). Fixtures are the fictional
penguin crew from `test/test_data`; no real person appears anywhere.
Regenerate with `make people_inventory_screenshots`.
