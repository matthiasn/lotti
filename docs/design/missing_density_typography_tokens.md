# Missing density-variant typography tokens

> Status: open follow-up — surfaced while shipping the unified
> `AiSummaryCard`. The card uses the existing
> `tokens.typography.styles.*` styles as the base for every label, but
> repeatedly has to override `height` (line-height) and, in one case,
> `letterSpacing` to hit the spec's tighter rhythm inside the card.
> Those overrides are not in the token set — they are hand-tuned values
> applied via `copyWith`. This document captures the gap so we can
> formalize a `compact` density variant in `tokens.json` instead of
> sprinkling literals through widget code.

## Where the gap appears

The new AI surface ships in a denser layout than most other cards in
the app: a 14px-radius card holds a TLDR header, an inline expandable
report, a proposals list, and an activity footer in a tight vertical
rhythm. To make the lines breathe correctly inside that surface, the
following overrides are applied on top of the base typography tokens:

| widget                                             | base style                                  | override                          |
| -------------------------------------------------- | ------------------------------------------- | --------------------------------- |
| TLDR title ("AI summary")                          | `subtitle.subtitle2`                        | `height: 1.1`                     |
| TLDR body markdown                                 | `body.bodySmall`                            | `height: 1.55`                    |
| Read more / Show less pill label                   | `others.caption`                            | `height: 1`                       |
| Open agent internals pill label                    | `others.caption`                            | `height: 1`                       |
| Proposed changes section title                     | `body.bodySmall`                            | `height: 1.1`                     |
| `N pending` count badge                            | `others.caption`                            | `height: 1.1`                     |
| Confirm all button label                           | `others.caption`                            | `height: 1.1`                     |
| Empty proposals dashed row                         | `others.caption`                            | `height: 1.4`                     |
| `History · N` toggle                               | `others.caption`                            | `height: 1.1`                     |
| Proposal kind chip                                 | `others.caption`                            | `height: 1`, `letterSpacing: 0`   |
| Proposal body row                                  | `body.bodySmall`                            | `height: 1.5`                     |
| Resolved status tag (Confirmed / Dismissed)        | `others.caption`                            | `height: 1`                       |
| Activity footer caption (`N recent actions`)       | `body.bodySmall`                            | `height: 1.2`                     |
| See activity / Hide activity pill label            | `others.caption`                            | `height: 1`                       |
| Activity row primary line                          | `body.bodySmall`                            | `height: 1.35`                    |
| Activity row meta line                             | `others.caption`                            | `height: 1.2`                     |
| RECENT ACTIVITY section label                      | `others.caption`                            | `height: 1`, `letterSpacing: 1.2` |
| Countdown pill                                     | `others.caption`                            | (token defaults — for reference)  |
| Internals panel title                              | `subtitle.subtitle1`                        | (token defaults — for reference)  |
| Internals panel subtitle (agent name)              | `others.caption`                            | (token defaults — for reference)  |

The base font family, weight, and size always come from
`assets/design_system/tokens.json` (extracted from Figma). Only the
**line-height** (and one all-caps letter-spacing) is bypassed.

## Why these overrides exist

The default `Body/Body Small` token in `tokens.json` ships with
`size: 14, lineHeight: 20` (= `height ≈ 1.43`), which is correct for
relaxed body copy in standalone cards but visually loose inside this
card's chrome. The `Others/Caption` token ships with `lineHeight: 16`
on `size: 12` (= `height ≈ 1.33`) which is fine for free-floating
captions but too airy for inline pill labels and dense list rows.

Empirically we settled on roughly two density tiers:

* **Tight (`1.0–1.2`)** — pill button labels, compact section titles,
  resolved-state tags, and the all-caps section header. Effectively
  "label height matches font box."
* **Comfortable-compact (`1.35–1.55`)** — multi-line body text inside
  the card (TLDR, proposal body, activity row first line). Looser than
  the tight tier but still tighter than the default body token's `1.43`
  worth of leading.

These two tiers map cleanly onto a `compact` density branch in the
existing `tokens.typography.styles.*` tree.

## Proposed token additions

Extend `assets/design_system/tokens.json` with a `compact` density
sibling under `typography.styles`. Each existing leaf gets a paired
compact variant with the same `family`, `weight`, `size`, and
`letterSpacing`, but a tighter `lineHeight`. Concretely:

```jsonc
"typography": {
  "styles": {
    // existing styles untouched
    "Body/Body Small":   { "weight": "Regular", "size": 14, "lineHeight": 20, "letterSpacing": 0 },
    "Others/Caption":    { "weight": "Regular", "size": 12, "lineHeight": 16, "letterSpacing": 0.25 },

    // new compact density tier
    "Compact/Title S":           { "weight": "Semi Bold", "size": 14, "lineHeight": 16, "letterSpacing": 0.25 },
    "Compact/Body S":            { "weight": "Regular",  "size": 14, "lineHeight": 21, "letterSpacing": 0 },
    "Compact/Body S Tight":      { "weight": "Regular",  "size": 14, "lineHeight": 17, "letterSpacing": 0 },
    "Compact/Caption":           { "weight": "Regular",  "size": 12, "lineHeight": 14, "letterSpacing": 0 },
    "Compact/Caption Strong":    { "weight": "Semi Bold", "size": 12, "lineHeight": 13, "letterSpacing": 0 },
    "Compact/Caption Caps":      { "weight": "Semi Bold", "size": 12, "lineHeight": 12, "letterSpacing": 1.2 },
    "Compact/Pill":              { "weight": "Medium",    "size": 12, "lineHeight": 12, "letterSpacing": 0 },
    "Compact/Activity Primary":  { "weight": "Regular",  "size": 14, "lineHeight": 19, "letterSpacing": 0 },
    "Compact/Activity Meta":     { "weight": "Regular",  "size": 12, "lineHeight": 14, "letterSpacing": 0 }
  }
}
```

After regeneration via `tool/design_system/generate_tokens.dart`, the
new styles surface as
`tokens.typography.styles.compact.{titleS, bodyS, bodySTight,
caption, captionStrong, captionCaps, pill, activityPrimary,
activityMeta}` and replace every `copyWith(height: ..., letterSpacing:
...)` site listed in the table above.

Notes for the generator:

* The current `_buildTypographyNode` builds groups out of the prefix
  before the `/` in each style key (`Display`, `Heading`, `Subtitle`,
  `Body`, `Others`). A `Compact/` prefix automatically becomes
  `tokens.typography.styles.compact.*` with no generator change
  required.
* The `Compact/Caption Caps` entry's `letterSpacing: 1.2` is the only
  non-default letter-spacing in this batch — it matches the
  `RECENT ACTIVITY` section header.
* `weight: "Medium"` is not currently in the generator's
  `_fontWeightLiteral` switch (it accepts `Bold`, `Semi Bold`,
  `Regular`). Adding `"Medium" -> "FontWeight.w500"` is a one-line
  generator change. If we'd rather keep the generator untouched for
  this round, drop the `Compact/Pill` entry's weight to `Regular` and
  re-skin the pill labels at the call site, or use `Semi Bold` (the
  pills already read fine at `w600`).

## Migration

Once the tokens land:

1. Regenerate `lib/features/design_system/theme/generated/design_tokens.g.dart` via `fvm dart run tool/design_system/generate_tokens.dart`.
2. Replace each `copyWith(height: ..., letterSpacing: ...)` site listed
   above with a direct reference to the appropriate
   `tokens.typography.styles.compact.*` style (still chaining
   `copyWith(color: ...)` for the per-element color).
3. Re-run `make analyze` and `flutter test test/features/agents/ui/`
   to confirm no regressions.

## Out of scope for now

* The `height: 1.55` override on the TLDR markdown block. The card
  spec calls for noticeably looser leading on free-flowing prose than
  on the rest of the card; this is closer to a deliberate body-copy
  tier than a density variant. We can either add a single
  `Compact/Body S Loose` (`lineHeight: 22`) or — preferably — bake
  this into a future `prose` density rather than `compact`.
* Whitespace tokens for the card's internal padding scale (4 / 6 / 10
  / 12 / 14 px). Those are tracked separately under the existing
  spacing-token discussion in the AI card handoff README; they are
  *not* part of this typography gap.
