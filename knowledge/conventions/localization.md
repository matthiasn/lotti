---
type: Convention
title: Localization
description: "Every user-visible string comes from an ARB catalog, in an informal register, with Romanian as the deliberate exception."
resource: ../../lib/l10n
tags: [convention, l10n, arb, translation]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T10:00:00Z }
stale_after: 2027-01-18
sources:
  - id: l10n
    resource: ../../lib/l10n
    title: ARB catalogs and generated localizations
    last_modified: 2026-07-25
  - id: config
    resource: ../../l10n.yaml
    title: Localization generation config
    last_modified: 2026-07-25
---

# The rule

**All user-visible label text MUST be localized** through the ARB files in
`lib/l10n/`. Never hardcode a string a user will see.

There are **twelve** catalogs: `app_en.arb` (primary) plus `cs`, `da`, `de`,
`en_GB`, `es`, `fr`, `it`, `nl`, `pt`, `ro`, `sv` — matching
`AppLocalizations.supportedLocales`.

**A new label goes into every one of them.** All twelve are shipped locales, so a
label added to a subset is a visible English island for the users of the rest.
Translate as you add; do not leave the gap for someone else to find later.

`app_en_GB.arb` is the one exception, and only in one direction: it gets an entry
when the spelling differs from US English, and nothing when it does not.

`missing_translations.txt` is the backstop that reports what slipped through, not
the plan.

Access is through `context.messages.labelName`.

After adding labels, run `make l10n` to regenerate and `make sort_arb_files` to
keep the catalogs consistently sorted. **Never edit the generated
`app_localizations_*.dart` files** — edit the ARB source and regenerate.

# It applies to the corners too

The rule includes debug and QA-only actions. It matters most in
*Settings → Advanced → Maintenance*, whose onboarding preview and animation
gallery rows are **real app UI** and would otherwise be an English island inside
another locale. See [settings](../features/settings.md).

# Register: informal

The app addresses users **informally**:

| Language | Uses | Not |
|----------|------|-----|
| German | du / deine | Sie / Ihre |
| French | tu / tes | vous / vos |
| Spanish | tú / tus | usted / sus |

**Romanian is the deliberate exception** — it uses the formal `dvs.` register
consistently.

`missing_translations.txt` records gaps, and `make l10n` prints them.

# Where dates and numbers are localized instead

Persisted values stay **locale-neutral**: a due date is a `DateTime`, a status is
an enum. Localization happens at the presentation boundary — for example
`DateFormat.yMMMd` in the active locale for a due-date chip, and localized status
labels resolved when an event renders.

That split is what lets a language change update every surface immediately
without migrating a single record. See [events](../features/events.md).
