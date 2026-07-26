---
type: Convention
title: Localization
description: "Every user-visible string comes from an ARB catalog, in an informal register, with Romanian as the deliberate exception."
resource: ../../lib/l10n
tags: [convention, l10n, arb, translation]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:30:00Z }
stale_after: 2027-01-31
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

`AGENTS.md` names a **subset** as the required edit set (`cs`, `de`, `es`, `fr`,
`ro`), so a new label added per that instruction leaves five catalogs untouched
and reliant on `missing_translations.txt` to surface the gap. That is the
instruction as written, not an inference — worth knowing before assuming a new
string reaches every locale.

`app_en_GB.arb` gets an entry only when the spelling differs from US English.

Access is through `context.messages.labelName`.

After adding labels, run `make l10n` to regenerate and `make sort_arb_files` to
keep the catalogs consistently sorted. **Never edit the generated
`app_localizations_*.dart` files** — edit the ARB source and regenerate.

# It applies to the corners too

The rule includes debug and QA-only actions. It matters most in
*Settings → Advanced → Maintenance*, whose onboarding preview and animation
gallery rows are **real app UI** and would otherwise be an English island inside
another locale. See [settings](../features/settings/).

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
without migrating a single record. See [events](../features/events/).
