---
type: Convention
title: Screenshots
description: How generated screenshots leave this repository for R2, and why a UI pull request carries an immutable before/after pair rather than one picture of the new thing.
resource: ../../test/test_utils/screenshot_harness.dart
tags: [convention, screenshots, review, pull-request, r2]
status: stable
generated: { by: claude-code/opus-5, at: 2026-08-01T12:10:00Z }
stale_after: 2027-02-01
sources:
  - id: harness
    resource: ../../test/test_utils/screenshot_harness.dart
    title: In-app screenshot harness
    last_modified: 2026-06-16
  - id: makefile
    resource: ../../Makefile
    title: manual_screenshots targets and their staging directories
    last_modified: 2026-07-31
  - id: gitignore
    resource: ../../.gitignore
    title: The `screenshots` ignore rule
    last_modified: 2026-07-24
  - id: pr-publisher
    resource: ../../tool/pr_screenshot_publish.py
    title: Immutable PR screenshot publisher
    last_modified: 2026-08-05
---

# Images do not live in this repository

`assets/` holds what the *app* ships — icons, tutorial media, design-system
exports. **Everything captured for humans to look at leaves this repository.**
The generated manual catalog and pull-request review evidence publish to the
Cloudflare R2 bucket that also hosts the tutorial videos. Pull-request images
use commit-addressed public URLs:

```markdown
![Ontology viewer after](https://pub-3df7bcf4b8ca493fa6acea182d69d9c7.r2.dev/pr-screenshots/ontology-viewer-redesign/71a1db255fb0ba913b5aa65578787c72c6302033/after/ontology_viewer_desktop_after.png)
```

That split keeps a Flutter checkout from carrying megabytes of PNGs that change
every time a surface is redesigned, and it is why `README.md` embeds remote
images rather than local ones.

The enforcement is thin, so know it: `.gitignore` ignores any directory named
`screenshots`, which is exactly the harness's default output directory. Capture
lands somewhere ignored by default — but an image saved anywhere else **will**
be committed if you `git add` it.

# Two destinations, two lifecycles

Both live in the R2 bucket. **No image belongs in a git repository** — not this
one, and not a docs repository either. Which prefix an image belongs under
follows from who regenerates it:

| Destination | Contents | Lifecycle |
|-------------|----------|-----------|
| R2 bucket, `manual/screenshots/<version>/<case-id>/` | The **generated** manual catalog — `mobile-light`, `mobile-dark`, `desktop-light`, `desktop-dark` per case, plus `manifest.json` | Produced by `make manual_screenshots` and published by the `manual.yml` CI lane; never hand-edited or renamed. `development/` is refreshed with deletion (retired cases disappear), numbered release prefixes are immutable — publishing refuses to overwrite an existing manifest. The app `README.md` embeds from this catalog too, so its screenshots age with the app rather than with whoever last remembered to retake them |
| R2 bucket, `pr-screenshots/<topic-slug>/<app-commit>/` | **Review evidence** for a pull request | Published from an external capture directory by `make pr_screenshots_publish`. Objects are immutable: an identical retry is a no-op, while changed pixels require a new filename or commit prefix |

`make manual_screenshots` stages captures and the materialized catalog under
the gitignored `build/manual_capture/` and `build/manual_media/` directories;
only the CI publish step talks to R2, using the `R2_*` repository secrets.

It is a loop over two smaller targets, and CI uses those directly rather than
the loop: `manual_screenshots_shard` captures **one** locale and converts only
that locale to WebP, and `manual_screenshots_manifest` writes and validates the
manifest over whatever complete media tree exists. CI runs one shard job per
locale and merges them, because a locale takes about twelve minutes and the
full catalog does not fit in a single job's timeout — nightly and on dispatch
only, four at a time, because eleven runners per merge is more than a catalog
that rarely changes is worth. **A UI change therefore ships before its manual
media does**; dispatch the workflow when a screenshot needs to be current
sooner.

Whether the harness still *runs* is checked earlier and separately:
`manual-capture-check.yml` captures one locale on any pull request touching
`lib/`, `assets/`, a harness, or a registered screenshot test. It publishes
nothing — it exists because these suites are opt-in, so no other *pull
request* lane executes them and a UI change would otherwise only be found to
have broken the catalog by the nightly capture.

It defaults to **German**, not the authoring locale: every other locale falls
back to English, so a rendering that only breaks once a translation is
involved stays green there. That is not hypothetical — a proposal row whose
quotation marks come from the locale (`„…“` in German and Czech, `"…"` in
English) passed English and failed the other ten. Override with the
`MANUAL_CHECK_LOCALE` repository variable. Run a single locale the same way CI
does when iterating on one language:

```bash
make manual_screenshots_shard MANUAL_LOCALE=de
```

# A UI pull request shows before *and* after

**One picture of the new thing is not review evidence.** A reviewer cannot tell
an improvement from a regression without the state it replaced, and the author is
the only person who still has that state cheaply to hand.

So a UI pull request carries a pair, per surface and per relevant variant
(mobile/desktop, light/dark where the change touches theming):

```text
pr-screenshots/<topic-slug>/
├── before/
│   └── <surface>_<mobile|desktop>_<light|dark>.png
└── after/
    └── <surface>_<mobile|desktop>_<light|dark>.png
```

Matching filenames on both sides are what make the pair readable — a reviewer
should be able to flip between two images of the same name and see only the
change.

**Capture `before/` first, from the base commit**, before the change exists.
Reconstructing it afterwards means stashing work and re-running the harness, which
is the step people skip; that is why the pairs go missing.

Publish the pair from its external staging directory after the app commit exists:

```bash
make pr_screenshots_publish \
  PR_SCREENSHOT_SOURCE=/tmp/lotti-pr-screenshots/<topic-slug> \
  PR_SCREENSHOT_TOPIC=<topic-slug> \
  PR_SCREENSHOT_COMMIT=$(git rev-parse HEAD) \
  PR_SCREENSHOT_ENV=/path/to/lotti/.env
```

The command requires `boto3` and the same five `R2_*` values as tutorial-video
publishing. It records a SHA-256 on every object and refuses to overwrite a key
whose content differs. Published objects have `image/png` and
`Cache-Control: public,max-age=31536000,immutable`; that one year is the client
cache lifetime, not object expiration. The R2 object remains until explicitly
deleted by a bucket lifecycle or maintainer.

Link the printed public URLs from the pull-request body. A contributor without
R2 credentials should attach images through GitHub's own upload instead. What
is not acceptable is committing generated screenshots to this repository,
overwriting a published review object, or omitting the before state.

# The pair is the contract

`before/` + `after/` with **matching filenames** is what new work produces.
Older captures elsewhere in the project's history used other shapes — a single
`after/`, files loose in a topic directory, one-off `baseline/` or `current/`
subdirectories. Read those as the convention arriving after the practice, not
as licence: they are not the R2 contract for new work.

# Related

* [Platform targets, CI and release](../architecture/platform-and-release.md) - the `manual.yml` lane that rebuilds the docs site.
* [Testing conventions](testing.md) - the harness is a widget test, so the same fake-time and determinism rules apply.
