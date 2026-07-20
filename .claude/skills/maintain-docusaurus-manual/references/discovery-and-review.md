# Discovery and review

Use this reference when a manual has more than a simple `docs/` tree.

## Repository discovery

Search for:

- `docusaurus.config.*`, `sidebars.*`, `package.json`, and site-local README files;
- `i18n/*/docusaurus-plugin-content-docs/*` locale trees;
- custom MDX components for screenshots, callouts, release badges, or fallbacks;
- manifests named `features`, `surfaces`, `coverage`, `screenshots`, or `releases`;
- build, validation, smoke, link-check, and deployment commands in CI and Makefiles;
- app localization catalogs used as the terminology authority;
- deterministic screenshot tests and generated-media repositories.

## Accuracy review

For each changed page, verify:

1. Entry point: route, menu, button, keyboard path, or prerequisite.
2. State: loading, empty, configured, error, permission, and platform variants.
3. Actions: what each control changes and whether the change persists or syncs.
4. Boundaries: unsupported platforms, optional dependencies, privacy, and cost.
5. Vocabulary: visible labels match the selected locale's product strings.
6. Evidence: screenshots show production UI and the described state.

## Translation review

- Keep frontmatter slugs and explicit IDs stable unless localized URLs are a
  deliberate product decision.
- Preserve MDX imports, JSX component names, prop names, code, paths, URLs, and
  placeholder syntax.
- Translate titles, descriptions, alt text, prose, table text, and user-facing
  component props.
- Check tone and grammatical agreement in context. Do not validate translations
  by dictionary equivalence alone.
- Search for accidental canonical-language paragraphs after translation.

## Release and routing review

Confirm the production base URL, default locale URL, non-default locale prefix,
version selector, canonical links, sitemap, 404 behavior, and browser-language
routing. When releases are built from application tags, do not create copied
version directories unless the repository explicitly uses Docusaurus versioning.
