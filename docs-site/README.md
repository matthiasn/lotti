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

The local English root is `/manual/development/`; German, French, Italian,
Spanish, Czech, Romanian, Portuguese, Danish, and Swedish are available at
`/manual/development/de/`, `/manual/development/fr/`,
`/manual/development/it/`, `/manual/development/es/`,
`/manual/development/cs/`, `/manual/development/ro/`, and
`/manual/development/pt/`, `/manual/development/da/`, and
`/manual/development/sv/`. The navbar selector
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

The repository root and `/lotti/manual/` redirect to the latest published
release, or to `development` before the first one. On every matching push to
`main`, GitHub Actions validates and builds the site, uploads the built tree
to the R2 site-snapshot store (`manual-site/<version>/`), mirrors the whole
store into one repo-prefixed Pages tree, and deploys it. Generated Docusaurus
output is never committed: it exists only in the Actions runner, the R2
store, and the Pages deployment artifact.

Publishing a release manual is a `workflow_dispatch` of the Manual workflow
with `manual_version: X.Y.Z` and `deploy: true`, leaving `publish_media` and
`capture_screenshots` at their default of on: the run resolves the newest
app tag of that marketing version, builds the site and screenshot catalog
from that tag, uploads both to their immutable R2 prefixes (existing release
snapshots are never overwritten, and a release site never deploys without a
screenshot catalog captured from the same commit), and redeploys Pages with
every version side by side. Each deploy also writes a live `manual/releases.json` next to the
version directories; the version dropdown fetches it at runtime, so even old
immutable snapshots list releases published after them.

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

Generated screenshots are published to the Cloudflare R2 bucket that also
hosts the tutorial videos, under one versioned prefix per manual version
(`manual/screenshots/<version>/…`). The `development` prefix is mutable and
synced with deletion so retired cases disappear; release prefixes are
immutable — publishing refuses to overwrite an existing manifest. The registry
reuses deterministic feature screenshot harnesses:

```bash
make manual_screenshots
```

That command captures all registered locales (English, German, French,
Italian, Spanish, Czech, Dutch, Romanian, Portuguese, Danish, and Swedish) at
mobile/desktop sizes in light/dark as PNG inputs into a gitignored staging
directory (`build/manual_capture/`), converts them to canonical WebP paths,
and writes a checksum/dimension manifest under
`build/manual_media/development/`.

CI runs the same pipeline on every manual-relevant push to `main`, nightly at
02:23 UTC, and on demand — but **one job per locale**, because a locale takes
about twelve minutes and the whole catalog does not fit in a single job. Each
shard runs the two targets the loop above is made of:

```bash
make manual_screenshots_shard MANUAL_LOCALE=de   # capture + convert one locale
make manual_screenshots_manifest                 # manifest over the merged tree
```

A following job merges every locale's slice, writes the manifest across all of
them, and validates the complete matrix before publishing — so an incomplete
capture cannot reach the bucket. Main-branch runs then sync the materialized
catalog to R2 (uploading `manifest.json` last, so readers never resolve cases
whose media has not landed); pull requests only validate the site and never
publish generated media. The site resolves media from the bucket's public URL;
override it at build time with `MANUAL_MEDIA_BASE_URL`.

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
`manualScreenshotText(en: …, de: …, fr: …, it: …, es: …, cs: …, nl: …, ro: …,
pt: …, da: …, sv: …)` so all eleven catalogs show the
same scenario in the selected language.

Add a screenshot by extending `metadata/screenshot-cases.json`, reusing or
adding an opt-in Flutter screenshot test, then referencing its stable case ID
from MDX with `ManualScreenshot`. Direct one-off app images are rejected: every
displayed app screenshot must have the complete four-variant matrix in every
manual locale.

## Dependency advisories

CI gates production dependencies with `npm run audit:gate`
(`scripts/audit-gate.mjs`) rather than `npm audit --audit-level=high`
directly. Same data and same threshold, with one addition: advisories listed
in `audit-allowlist.json` are reported and skipped instead of failing.

That exists because `npm audit` cannot express *"this advisory has no
reachable fix"*. When an advisory's vulnerable range covers every published
version of a transitive package, the audit fails on every branch indefinitely
and no dependency change clears it — including the bump `npm audit fix
--force` suggests. Failing forever teaches people to ignore the gate; a
blanket `|| true` removes it. The allowlist keeps it meaningful:

- An entry waives **one GHSA id**, not a package or a severity level.
- Every entry needs a `reason` explaining why no fix is reachable, and an
  `expires` date. Past that date the gate fails on the entry itself, so a
  waiver cannot quietly become permanent.
- Anything else at high or above still fails, including a new advisory on an
  already-waived package.
- Severity is judged per advisory root, not on npm's rolled-up parent
  severity, so a moderate root never needs a waiver just because something
  high sits elsewhere under the same parent.

Before extending an expiry, re-check whether upstream has adopted a patched
version. `tests/audit-gate.test.mjs` covers the logic against fixture reports
and asserts the committed allowlist is justified, dated, and not expired.

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

`metadata/releases.json` is only the build-time fallback catalog baked into
each snapshot; the authoritative list is derived from the R2 site-snapshot
store on every deploy and served as `manual/releases.json`, which the version
dropdown fetches at runtime. No `versioned_docs` directory is allowed.
