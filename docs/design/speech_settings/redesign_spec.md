# Settings -> Speech page — design spec (v1, for panel review)

Settings page for on-device text-to-speech. MUST reuse the entity-definition
design language (the redesigned category/label settings): `SettingsFormSection`
cards (quiet overline title + optional description above a
`background.level02` card with a `decorative.level01` hairline, `radii.m`,
`cardPadding`, `cardItemSpacing`), design-system list rows, and tokens for all
spacing / type / color. No bespoke surfaces.

Shared headerless `SpeechSettingsBody` rendered by both the mobile page
(`SliverBoxAdapterPage` chrome) and the desktop Settings-v2 detail panel —
same as how `ThemingBody` / category bodies are shared.

## Layout

    SPEECH                                     (page title / breadcrumb)

    Voice                                      (SettingsFormSection overline)
    Choose the voice that reads summaries
    +-------------------------------------------------+   card: level02 + hairline
    |  FEMALE                                         |   group label (caption, medium)
    |   Female 1                       (>)            |   row: label + preview button
    |   Female 2                  (check) (>)         |   selected: leading accent check
    |   ...                                           |
    |  MALE                                           |
    |   Male 1                         (>)            |
    +-------------------------------------------------+

    Model
    On-device speech model
    +-------------------------------------------------+
    |   Supertonic 3   [Recommended]   Downloads once |   selected by default
    +-------------------------------------------------+

    Reading speed
    How fast summaries are read
    +-------------------------------------------------+
    |  0.5x  0.75x  [1.0x]  1.25x  1.5x  1.75x  2x    |  segmented; current highlighted
    +-------------------------------------------------+

## Components & behaviour
- **Voice section:** the 10 Supertonic voices grouped FEMALE (F1-F5) / MALE
  (M1-M5). Each voice is a selectable row showing "Female N" / "Male N" (gender
  word localized, number from the id) plus a **preview** button that speaks a
  short sample in that voice. Selection shown by a leading accent check icon
  AND the row's selected state — never color alone. Default selection is a
  female voice.
- **Model section:** one selectable row per model; Supertonic 3 carries a
  "Recommended" badge and a "Downloads once" hint (first-run Hugging Face
  fetch). Selected row marked with the same accent check.
- **Reading-speed section:** a segmented control over 0.5x-2x
  (0.5/0.75/1.0/1.25/1.5/1.75/2.0); the active step is highlighted and labelled
  with its value.

## Accessibility targets
- Every row / preview button / speed segment is a >=44x44 hit target.
- Selection conveyed by icon + semantics ("selected"), not color alone
  (deuteranopia-safe).
- Preview button: semantics label "Preview Female 2 voice"; while previewing,
  it shows a stop affordance and announces state.
- Section titles + field labels use the SettingsFormSection type ramp
  (subtitle2 medium for section, high-emphasis for field labels); all via
  `tokens.typography`. No raw font sizes.
- Contrast: accent check + selected-row background meet WCAG 2.2 AA in light +
  dark.
- Dynamic Type: rows grow / wrap; the speed segmented control wraps to two rows
  rather than truncating on large text.
