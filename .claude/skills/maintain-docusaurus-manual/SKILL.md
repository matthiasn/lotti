---
name: maintain-docusaurus-manual
description: Maintain a Docusaurus product manual whose prose, navigation, localized page trees, screenshots, coverage metadata, and release build must stay aligned with the application. Use when adding or revising manual pages, documenting a product change, updating translated MDX, repairing locale parity, adding registered screenshots, auditing stale documentation, or validating a multilingual Docusaurus site before publication.
---

# Maintain a Docusaurus Manual

Treat the running product and source code as authoritative. Keep documentation,
translations, navigation, screenshots, inventories, and generated site behavior
consistent in the same change.

## Discover the project contract

1. Read the repository instructions and the manual's own contributor guide.
2. Locate the Docusaurus config, source docs, localized docs, sidebar, package
   scripts, validation scripts, screenshot registry, coverage inventory, and CI.
3. Identify the canonical locale, supported locales, URL/version scheme, and
   whether localized pages may fall back or must have exact path parity.
4. Locate app strings or another terminology source before translating UI names.
5. Read [references/discovery-and-review.md](references/discovery-and-review.md)
   when the repository has custom inventories, generated screenshots, or
   versioned publishing.

Do not assume conventional paths when the repository declares its own.

## Update the manual

1. Verify the current product behavior from implementation and focused tests.
2. Update the canonical page with concrete, task-oriented prose. Describe only
   controls, states, limitations, and workflows that exist.
3. Preserve stable frontmatter identifiers, component calls, links, anchors,
   admonitions, and code unless the change intentionally modifies them.
4. Add new pages to navigation and every repository-owned coverage or surface
   inventory.
5. Update every published locale required by the project. Translate meaning,
   not sentence shape; preserve product terminology from the localized app.
6. Record questionable product wording separately unless changing UI copy is
   explicitly in scope.

## Handle screenshots as evidence

- Prefer the repository's deterministic screenshot harness and registry.
- Capture the real production widget or route with representative state.
- Keep required locale, viewport, and theme variants complete.
- Reference screenshots through the site's component or registry rather than
  hard-coded media URLs when such an abstraction exists.
- Keep generated media outside the source repository when that is the declared
  architecture.

If the task is only a one-off application screenshot, use the repository's
screenshot skill instead of extending the manual pipeline.

## Validate in increasing scope

1. Run the bundled parity audit when the site uses standard Docusaurus locale
   trees:

   ```bash
   python3 <skill-dir>/scripts/audit_docusaurus_locales.py \
     --site-root path/to/site
   ```

   Pass `--fail-identical` only when identical localized page bodies are
   forbidden. Treat its default identical-page output as a review warning.

2. Run focused repository validators and tests for touched metadata or helpers.
3. Run type checking, link/content validation, unit tests, and the production
   Docusaurus build through repository scripts.
4. Smoke-test built routes, locale switching, assets, search, and base URLs.
5. Review the rendered page at representative widths and in every changed
   locale. A successful build does not prove prose accuracy or layout quality.

Do not claim completion while required checks fail. Report any validation that
could not run and why.
