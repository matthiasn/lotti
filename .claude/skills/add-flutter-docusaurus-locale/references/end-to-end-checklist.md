# End-to-end locale checklist

Use this as a discovery checklist; update only surfaces the project actually
uses.

## Flutter localization

- canonical and target ARB key parity;
- `@@locale`, descriptions, placeholder metadata, ICU plural/select branches;
- `l10n.yaml`, `pubspec.yaml`, generator outputs, and missing-translation file;
- generated delegate `supportedLocales` after regeneration;
- manual language override, persisted preferences, and fallback behavior;
- locale-aware dates, numbers, pluralization, and text direction.

## Native platforms

- iOS and macOS `CFBundleLocalizations` or localized resources;
- Android `res/values-*`, locale config XML, or build-time resource generation;
- desktop packaging/store metadata if language lists are explicit;
- web manifest or HTML language metadata when the Flutter web app ships.

## Docusaurus

- `i18n.locales` and `localeConfigs` including `label`, `htmlLang`, and direction;
- `code.json`, docs plugin `current.json`, navbar, and footer translations;
- every canonical `.md`/`.mdx` path in the target docs plugin tree;
- localized titles, descriptions, alt text, callouts, and user-facing props;
- search tokenization/stemming support and browser-language routing;
- edit links, canonical URLs, sitemap, 404, version selector, and release aliases.

## Screenshots and fixtures

- locale allowlists in registries, scripts, and CI matrices;
- target-locale app fixture text not already sourced from ARB;
- required mobile/desktop and light/dark variants;
- checksum/dimension manifests and external media repository paths;
- alt text and screenshot references on every translated page.

## Quality review

- tone/register follows product guidance;
- UI vocabulary matches the target ARB in the actual screen context;
- no accidental canonical-language paragraphs or untranslated navigation;
- long strings do not clip, wrap controls unpredictably, or break fixed layouts;
- bidirectional layout is reviewed when adding an RTL language;
- contributor docs and public supported-language lists match reality.
