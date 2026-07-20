---
name: add-flutter-docusaurus-locale
description: Add, complete, or audit a locale across a Flutter application's ARB catalogs and a localized Docusaurus manual, including generated localization code, locale selectors, native platform declarations, translated MDX, screenshot fixtures, tests, and parity validation. Use when introducing a new language, finishing an incomplete app or manual translation, aligning manual terminology with UI strings, or reviewing whether a locale is production-ready end to end.
---

# Add a Flutter and Docusaurus Locale

Treat a locale as an end-to-end product capability, not merely a translated ARB
file. Preserve message contracts and wire the locale through app runtime,
platform metadata, manual routing, screenshots, tests, and release validation.

## Build the locale inventory

1. Read repository instructions and localization/manual contributor guides.
2. Identify the canonical ARB, all locale ARBs, `l10n.yaml`, generation and
   sorting commands, localization access conventions, and missing-translation
   report.
3. Find every locale allowlist: app delegates/controllers, settings UI, native
   platform metadata, Docusaurus config, screenshot registries, CI matrices,
   and documentation.
4. Inspect one recently added locale in version history as a completeness map,
   but verify every location against current code.
5. Read [references/end-to-end-checklist.md](references/end-to-end-checklist.md)
   for platform and manual integration surfaces.

## Translate the Flutter catalog

1. Copy the complete key set from the canonical ARB, including required
   metadata and `@@locale` conventions.
2. Translate user-visible messages in context. Preserve ICU syntax, placeholder
   names, escaping, line breaks with semantic meaning, and product names.
3. Use the project's tone and register. Keep terminology consistent across
   related screens; inspect call sites when a source message is ambiguous.
4. Do not translate internal identifiers, URLs, format skeletons, or values the
   framework treats as syntax.
5. Add locale-specific canonical metadata only where the generator or project
   requires it.
6. Run the generator and catalog sorter. Never hand-edit generated Dart files.

## Wire the app and platforms

- Add the locale to runtime choices and language-override state.
- Update visible language names using localized strings where the UI requires
  them.
- Add native supported-language declarations for every shipped platform that
  maintains an explicit list.
- Update screenshot locale helpers and deterministic visible fixture copy.
- Add behavior-focused tests for locale parsing, selection, persistence,
  delegates, and any locale-specific formatting or fallback behavior.

Do not infer that generated `supportedLocales` completes native registration.

## Translate and wire the Docusaurus manual

1. Add the locale to Docusaurus `i18n.localeConfigs`, navigation labels, footer
   labels, and any search or routing configuration.
2. Create the standard docs plugin translation files and a complete localized
   page tree matching the canonical docs paths.
3. Reuse terms from the target ARB for buttons, settings, statuses, and feature
   names. Translate the surrounding explanation naturally.
4. Preserve MDX imports, components, props, links, code, identifiers, and
   screenshot case IDs.
5. Add the locale to screenshot registries and produce every required theme and
   viewport variant using the project's deterministic harness.
6. Update contributor documentation and public language lists that users see.

## Audit and validate

Run the bundled contract audit before project-specific generation:

```bash
python3 <skill-dir>/scripts/audit_locale.py \
  --template-arb path/to/app_en.arb \
  --target-arb path/to/app_xx.arb \
  --source-docs path/to/docs \
  --target-docs path/to/i18n/xx/docusaurus-plugin-content-docs/current
```

The audit fails on missing/extra ARB keys, placeholder drift, and manual page
path mismatch. Identical translated page bodies are warnings unless
`--fail-identical` is passed.

Then run, in repository order:

1. localization generation and ARB sorting;
2. targeted localization, locale-selection, screenshot-helper, and manual tests;
3. formatter and static analysis with zero diagnostics;
4. the full manual typecheck, validation, tests, production build, and smoke test;
5. focused Flutter tests required by the repository;
6. rendered review of representative long strings and every translated manual
   route.

Do not report the locale complete while generated output is stale, translation
gaps remain, or required checks fail.
