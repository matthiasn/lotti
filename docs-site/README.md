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

Run the complete manual check with:

```bash
make manual_check
```

The production build defaults to `/manual/development/`. Override
`MANUAL_SITE_URL`, `MANUAL_ROOT_PATH`, `MANUAL_BASE_URL`, and `MANUAL_VERSION`
when composing a release deployment.

## Screenshot workflow

Generated screenshots belong in the sibling `../lotti-docs` repository. The
registry reuses deterministic feature screenshot harnesses:

```bash
make manual_screenshots
```

That command captures all registered mobile/desktop and light/dark PNG inputs
into an ignored staging directory, converts them to canonical WebP paths, and
writes a checksum/dimension manifest under
`../lotti-docs/manual/screenshots/development/`.

Add a screenshot by extending `metadata/screenshot-cases.json`, reusing or
adding an opt-in Flutter screenshot test, then referencing its stable case ID
from MDX with `ManualScreenshot`. Direct one-off app images are rejected: every
displayed app screenshot must have the complete four-variant matrix.

## Release model

For app version `1.0.0`, CI checks out the app's `1.0.0` tag and builds with:

```bash
MANUAL_VERSION=1.0.0 \
MANUAL_BASE_URL=/manual/1.0.0/ \
npm run build
```

The result is published as an immutable directory. `metadata/releases.json`
drives cross-version links and records which publicly distributed App Store
version should receive the `latest` alias. No `versioned_docs` directory is
allowed.
