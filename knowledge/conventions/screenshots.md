---
type: Convention
title: Screenshots
description: Where captured images live — never in this repository — and why a UI pull request carries a before/after pair rather than one picture of the new thing.
resource: ../../test/test_utils/screenshot_harness.dart
tags: [convention, screenshots, review, pull-request, lotti-docs]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T18:00:00Z }
stale_after: 2027-01-18
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
  - id: lotti-docs
    resource: https://github.com/matthiasn/lotti-docs
    title: lotti-docs — the media repository
    last_modified: 2026-07-26
---

# Images do not live in this repository

`assets/` holds what the *app* ships — icons, tutorial media, design-system
exports. **Everything captured for humans to look at leaves this repository.**
The generated manual catalog is published to the Cloudflare R2 bucket that
also hosts the tutorial videos; hand-picked release imagery and pull-request
review evidence go to the sibling
[`lotti-docs`](https://github.com/matthiasn/lotti-docs) repository and are
referenced from here by raw URL:

```markdown
![Task details on macOS](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.998/task_details_screenshot_macos.png)
```

That split keeps a Flutter checkout from carrying megabytes of PNGs that change
every time a surface is redesigned, and it is why `README.md` and
`GETTING_STARTED.md` embed remote images rather than local ones.

The enforcement is thin, so know it: `.gitignore` ignores any directory named
`screenshots`, which is exactly the harness's default output directory. Capture
lands somewhere ignored by default — but an image saved anywhere else **will**
be committed if you `git add` it.

# Three destinations, three lifecycles

Which home an image belongs in follows from who regenerates it:

| Destination | Contents | Lifecycle |
|-------------|----------|-----------|
| R2 bucket, `manual/screenshots/<version>/<case-id>/` | The **generated** manual catalog — `mobile-light`, `mobile-dark`, `desktop-light`, `desktop-dark` per case, plus `manifest.json` | Produced by `make manual_screenshots` and published by the `manual.yml` CI lane; never hand-edited or renamed. `development/` is refreshed with deletion (retired cases disappear), numbered release prefixes are immutable — publishing refuses to overwrite an existing manifest. The app `README.md` embeds from this catalog too, so its screenshots age with the app rather than with whoever last remembered to retake them |
| `lotti-docs`: `images/<app-version>/` | Hand-picked shots for release communication and the README | Written once per release, then left alone |
| `lotti-docs`: `pr-screenshots/<topic-slug>/` | **Review evidence** for a pull request | Written by hand while the work is in review; kept afterwards as the record of what reviewers saw |

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
sooner. Run a single locale the same way CI does when iterating on one
language:

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

Then link the raw URLs from the pull-request body. A maintainer with push access
to `lotti-docs` commits them there; **an outside contributor cannot**, and should
attach the images to the pull request through GitHub's own upload instead. Both
are acceptable evidence — what is not acceptable is committing them to this
repository, or omitting the before.

# Honest state of the existing tree

`pr-screenshots/` holds about 1,100 files across roughly 37 topics, and it is
**not** uniform: 24 topics have an `after/` while only 14 have a `before/`, some
put files directly in the topic directory, and one-off subdirectory names
(`baseline/`, `current/`, `reference/`, `variants/`) appear where a pair was not
the shape of the question.

Read that as the convention arriving after the practice rather than as licence.
The `before/` + `after/` pair above is what new work should produce; the older
shapes are history, and `lotti-docs`'s own README documents only the generated
manual catalog, not this tree.

# Related

* [Platform targets, CI and release](../architecture/platform-and-release.md) - the `manual.yml` lane that rebuilds the docs site.
* [Testing conventions](testing.md) - the harness is a widget test, so the same fake-time and determinism rules apply.
