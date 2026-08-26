# The filled icon font

Lucide is stroke-only by design: every glyph is one consistent 2px outline, and
the set ships no filled variants at all. That is the right default and it is
most of why the app looks coherent now.

It costs one thing. Material let a *toggle* show its on-state as the same glyph,
filled — a starred entry, a flagged one, the selected tab. Migrating to Lucide
turned each of those into `state ? X : X`, a no-op. Most of those sites also
change colour, so they degraded rather than broke; `entry_detail_header`'s flag
did not, and a flagged entry became indistinguishable from an unflagged one.

So this builds a very small font of filled counterparts, generated from
**Lucide's own SVG geometry** with the silhouette filled. Same shapes, same
optical weight, no second icon family — and only for glyphs that actually
toggle, plus the timer's stop control (see the table).

## Rebuilding

```sh
cd tool/icons/filled_font
npm install
npm run build
cp dist/LottiFilled.ttf ../../../assets/fonts/LottiFilled/LottiFilled.ttf
```

The rebuilt `.ttf` will not checksum-match the committed one — `svgtofont`
stamps a build timestamp into the binary. Compare `dist/LottiFilled.svg`
instead: the glyph names, codepoints and outline paths are what must match,
and those are reproducible.

Then update the codepoints in
`lib/features/design_system/theme/icon_tokens_filled.dart` from `dist/LottiFilled.svg`
— `svgtofont` assigns them alphabetically from `0xea01`, so **adding a glyph
renumbers the ones after it**. Check every constant, not just the new one.

## What is in here, and what is deliberately not

`svg/` holds the filled sources. Each is the upstream Lucide SVG with
`fill="none"` swapped for `fill="currentColor"`.

Only glyphs whose outline is a **single closed silhouette** work this way:

| Glyph | Why it is here |
|---|---|
| `star`, `bookmark`, `heart`, `circle`, `folder`, `moon` | one closed path; fills cleanly |
| `square` | not a toggle: the timer's stop control. Outlined it read as an empty checkbox on the red pill. (`circle` doubles as the timer's full-size record mark for continue.) |
| `flag` | needed a correction — see below |

`flag`'s outline draws its pole as an open run (`M4 22V4…`), and filling the
path closes that run into the banner, so the pole disappeared and the two
states no longer shared a silhouette. The source here re-adds the pole as a
solid `<rect>` matching the outline's 2px stroke and rounded cap.

Excluded on purpose:

- `book` fills to a featureless rounded square — its spine is an inner stroke.
- `list`, `chartColumn`, `users`, `listFilter`, `map`, `image`, `calendar`,
  `leaf`, `sun` are built from open strokes or inner detail. Filling them
  produces a blob, not a filled icon.

Those toggles carry their state in colour or in a changed label instead, which
their components already did. Do not add a glyph here without rendering it
first — `test/features/design_system/theme/icon_tokens_filled_test.dart` pins
the codepoints, but only your eyes can tell you the shape is right.
