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

The local English root is `/manual/development/`; German is available at
`/manual/development/de/`. The navbar selector preserves the current page, and
a German browser visiting the unqualified manual root is redirected to German
unless the reader has explicitly chosen a language before.

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

That command captures all registered English and German mobile/desktop and
light/dark PNG inputs into an ignored staging directory, converts them to
canonical WebP paths, and writes a checksum/dimension manifest under
`../lotti-docs/manual/screenshots/development/`.

English media keeps the established
`development/<case>/<viewport>-<theme>.webp` path. German media lives at
`development/de/<case>/<viewport>-<theme>.webp`. Visible deterministic demo
copy that does not come from the app ARB files must use
`manualScreenshotText(en: …, de: …)` so the two catalogs show the same scenario
in the selected language.

Add a screenshot by extending `metadata/screenshot-cases.json`, reusing or
adding an opt-in Flutter screenshot test, then referencing its stable case ID
from MDX with `ManualScreenshot`. Direct one-off app images are rejected: every
displayed app screenshot must have the complete four-variant matrix in every
manual locale.

## Release model

For app version `1.0.0`, CI checks out the app's `1.0.0` tag and builds with:

```bash
MANUAL_VERSION=1.0.0 \
MANUAL_SITE_URL=https://matthiasn.github.io \
MANUAL_ROOT_PATH=/lotti/manual \
MANUAL_BASE_URL=/lotti/manual/1.0.0/ \
npm run build
```

The result is published as an immutable directory. `metadata/releases.json`
drives cross-version links and records which publicly distributed App Store
version should receive the `latest` alias. No `versioned_docs` directory is
allowed.
