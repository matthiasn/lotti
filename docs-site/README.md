# Lotti Manual

The manual is a static Docusaurus site kept in the application repository. One
source tree represents the current manual; Git release tags preserve historical
source without copying every page into version folders.

## Local development

From the repository root:

```bash
make manual_deps
make manual_start
```

`manual_start` serves the English authoring locale. Use the production build to
review the complete locale matrix and browser-language routing:

```bash
make manual_check
make manual_serve
```

The local English root is `/manual/development/`; German, French, Spanish,
Czech, and Romanian are available at `/manual/development/de/`,
`/manual/development/fr/`, `/manual/development/es/`,
`/manual/development/cs/`, and `/manual/development/ro/`. The navbar selector
preserves the current page, and a browser using one of those languages that
visits the unqualified manual root is redirected to that language unless the
reader has explicitly chosen a language before.

Run the complete manual check with:

```bash
make manual_check
```

The production build defaults to `/manual/development/`. Override
`MANUAL_SITE_URL`, `MANUAL_ROOT_PATH`, `MANUAL_BASE_URL`, and `MANUAL_VERSION`
when composing a release deployment.

## GitHub Pages

The published development manual lives at:

`https://matthiasn.github.io/lotti/manual/development/`

The repository root and `/lotti/manual/` redirect to that version. On every
matching push to `main`, GitHub Actions validates and builds the site, assembles
the repo-prefixed Pages tree, uploads it as a Pages artifact, and deploys it.
Generated Docusaurus output is never committed: it exists only in the Actions
runner and the immutable Pages deployment artifact.

The initial Pages deployment publishes `development`. Version promotion will
assemble immutable release artifacts into the same Pages snapshot; manually
building another version already works, but it does not replace the live
development snapshot during this first publishing phase.

Run the same production build locally with:

```bash
MANUAL_SITE_URL=https://matthiasn.github.io \
MANUAL_ROOT_PATH=/lotti/manual \
MANUAL_BASE_URL=/lotti/manual/development/ \
MANUAL_VERSION=development \
npm run check
```

Then assemble the exact Pages directory shape into a disposable folder:

```bash
npm run pages:assemble -- \
  --build-root build \
  --output-root /tmp/lotti-manual-pages \
  --pages-prefix lotti \
  --version development
```

## Screenshot workflow

Generated screenshots belong in the sibling `../lotti-docs` repository. The
registry reuses deterministic feature screenshot harnesses:

```bash
make manual_screenshots
```

That command captures all registered English, German, French, Spanish, Czech,
and Romanian mobile/desktop and light/dark PNG inputs into an ignored staging
directory,
converts them to canonical WebP paths, and writes a checksum/dimension manifest under
`../lotti-docs/manual/screenshots/development/`.

CI runs this same full pipeline on every manual-relevant push to `main`, nightly
at 02:23 UTC, and on demand. Main-branch captures fast-forward a normal commit
to `lotti-docs/main`; pull requests only validate the site and never publish
generated media.

When only a new or changed case needs publishing, pass its IDs to the manifest
builder so the existing catalog remains untouched. For example:

```bash
npm run manifest -- --locales en,de --cases onboarding/api-key,onboarding/success
```

Use `--skip-manifest` only to prepare an incomplete locale catalog before a
subsequent complete manifest run; it converts the selected cases but deliberately
does not write a partial manifest.

Use `--manifest-only` after a complete catalog already exists when metadata must
be refreshed without recompressing any image files.

English media keeps the established
`development/<case>/<viewport>-<theme>.webp` path. Localized media lives at
`development/<locale>/<case>/<viewport>-<theme>.webp`. Visible deterministic
demo copy that does not come from the app ARB files must use
`manualScreenshotText(en: …, de: …, fr: …, es: …, cs: …, ro: …)` so all six
catalogs show the
same scenario in the selected language.

Add a screenshot by extending `metadata/screenshot-cases.json`, reusing or
adding an opt-in Flutter screenshot test, then referencing its stable case ID
from MDX with `ManualScreenshot`. Direct one-off app images are rejected: every
displayed app screenshot must have the complete four-variant matrix in every
manual locale.

## Release model

For app version `1.0.0`, a release build must check out the app's `1.0.0` tag and
build with:

```bash
MANUAL_VERSION=1.0.0 \
MANUAL_SITE_URL=https://matthiasn.github.io \
MANUAL_ROOT_PATH=/lotti/manual \
MANUAL_BASE_URL=/lotti/manual/1.0.0/ \
npm run build
```

`metadata/releases.json` drives cross-version links and records which publicly
distributed App Store version should receive the `latest` alias. The current
GitHub Pages workflow publishes the development snapshot; the first App Store
release needs the companion tagged-release job to assemble the immutable
versioned Pages snapshot and media catalog. No `versioned_docs` directory is
allowed.
