---
type: Convention
title: Screenshots
description: How generated screenshots leave this repository for R2, how the store listings are captured on a device, and why a UI pull request carries an immutable before/after pair rather than one picture of the new thing.
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
  - id: store-capture
    resource: ../../tool/store_screenshots/android.sh
    title: Play Store listing capture on an Android emulator
    last_modified: 2026-08-26
  - id: store-capture-ios
    resource: ../../tool/store_screenshots/ios.sh
    title: App Store listing capture on iOS simulators
    last_modified: 2026-08-28
  - id: store-test
    resource: ../../integration_test/store_screenshots_test.dart
    title: The screens the store listing shows, driven on the device
    last_modified: 2026-08-28
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

Both live in the R2 bucket. **No *captured* image belongs in a git
repository** — not this one, and not a docs repository either. (What `assets/`
ships is a different thing: icons, tutorial media and design-system exports are
part of the app, not evidence of it.) Which prefix a capture belongs under
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

# Store listing screenshots come from a phone

The store listings — Play Store and App Store — are the one place a screenshot
must come from the platform it advertises: a widget-test capture at a phone size
is the right shape but not the real thing — no device fonts, no device image
decoding, no platform text input. `integration_test/store_screenshots_test.dart`
therefore runs on a device under `flutter drive`, booting the production app
shell on the tutorial harness with the penguin world seeded in full (habits,
time records, notes, links) and *no demo-mode banner*, then walks the screens
that say what the app is. One driven test, two drivers:

| Platform | Script | Where it runs | What the script does that the test cannot |
|----------|--------|---------------|--------------------------------------------|
| Android | `tool/store_screenshots/android.sh` (`make store_screenshots_android`) | an emulator, booted from `LOTTI_AVD` if none is attached; CI in `store-screenshots-android.yml` | pins the window to 1080×1920 and turns Private DNS off (below) |
| iOS | `tool/store_screenshots/ios.sh` (`make store_screenshots_ios`) | the simulators named in `LOTTI_IOS_DEVICES`, booted if they are not; CI in `store-screenshots-ios.yml` | dresses the status bar to Apple's 9:41 / full battery / full signal convention, takes every PNG itself with `simctl` (below) and clears the status bar afterwards |

Both run the test once per theme. On Android the driver writes the PNGs the
device captured; on iOS the script writes them, one whole-screen `simctl`
capture per marker, split per device under `build/store_screenshots/ios/<slug>/`.
Both CI lanes run on manual dispatch or on a pull request touching the capture,
and upload the PNGs as an artifact.

Device facts that shape the two scripts:

- **Play rejects a screenshot whose long side is more than twice its short
  side**, and the stock Pixel profiles are 20:9. The Android script pins the
  emulator window to 1080×1920 (9:16, which Play also asks for when it features
  a listing) with `adb shell wm size` and resets it afterwards.
- **App Store Connect's listing sizes are device sizes**, so the iOS script pins
  nothing: the 6.9" iPhone slot takes 1320×2868, which is what an iPhone 17 Pro
  Max simulator renders, and the 13" iPad slot takes 2064×2752, which is what an
  iPad Pro 13-inch renders. The default `LOTTI_IOS_DEVICES` names exactly those
  two — the app is universal (`TARGETED_DEVICE_FAMILY = 1,2`), so the iPad set
  is required, not optional.
- **The test runs on the device, whose environment is not the host's.** Theme
  and locale arrive as `--dart-define`s, not environment variables; the
  driver, which does run on the host, still writes to `LOTTI_SCREENSHOT_DIR`.
  And there is no `curl` on a phone, so the fixture media comes down through
  `package:http` instead of the widget-test downloader.
- **Android renders Flutter into a `SurfaceView`, which a screenshot cannot
  read**; the test swaps in an `ImageView` for the run
  (`convertFlutterSurfaceToImage`).
- **The iOS plugin's screenshot is the Flutter view alone** — no status bar,
  a blank band under the notch — and its bytes reach the driver only after the
  run, in a batch, so nothing host-side can be timed off them. On a simulator
  the test therefore announces each capture point on stdout
  (`LOTTI_STORE_CAPTURE <name> <ack-dir>`) and **waits** — the script streams
  the drive output, takes the whole screen with `simctl io screenshot` on the
  marker (status bar and its override included), flattens it, then touches
  `<ack-dir>/<name>.done`, and only then does the test move on. The ack
  directory is inside the app's sandbox, which on a simulator is a plain host
  directory. A handshake rather than a fixed hold, because a cold CI runner
  took over ten seconds per frame and every capture drifted one screen late.
  The driver, told the UDID through `LOTTI_SIMULATOR_UDID`, leaves the
  device-side bytes unwritten and fails the run if the host's file is missing.
- **App Store Connect rejects a PNG with an alpha channel**, and says so with
  the same "dimensions should be …" message it uses for a wrong size.
  `simctl` always writes RGBA, so the script flattens each capture to opaque
  RGB with `tool/store_screenshots/strip_alpha.py` (standard library only, so
  a stock runner needs no pip step; the sRGB profile chunk is kept).
- **The Android emulator's DNS fails silently under Private DNS.** Android's
  opportunistic DNS-over-TLS "validates" against the emulator's virtual
  resolver at 10.0.2.3 and then answers nothing: ICMP works, no hostname
  resolves, and the fixture media never arrives. The script turns
  `private_dns_mode` off on the guest before driving; plain DNS through the
  same resolver is fine.

The output is a listing asset, not review evidence: it is uploaded to the
Play Console and App Store Connect by hand and does not go to R2.

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

**Fixtures are never the user's own data.** A capture harness populates its
surface from `test/test_data` and the penguin demo world — never from a habit,
task, goal, note or description seen in a maintainer's own app, database or bug
screenshot. Everything captured here is published to a public bucket and
embedded in a public pull request, so a real entry in a fixture is a real entry
on the internet. Read every string in a scratch harness before running it, and
every image before publishing it.

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

Other shapes exist in the project's history — a single `after/`, files loose in
a topic directory, one-off `baseline/` or `current/` subdirectories. They are
historical exceptions, predating this convention. **None of them is valid for a
new publication.**

# Related

* [Platform targets, CI and release](../architecture/platform-and-release.md) - the `manual.yml` lane that rebuilds the docs site.
* [Testing conventions](testing.md) - the harness is a widget test, so the same fake-time and determinism rules apply.
