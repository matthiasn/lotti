---
name: release
description: Cut a Lotti release — assemble the changelog.d/ fragments into CHANGELOG.md and the Flathub metainfo, bump the version, open the release PR, then tag. Use when asked to cut or prepare a release, assemble the changelog, publish a new version, or work out what is unreleased.
---

# Cut a release

Release notes are written per change as **fragments** in `changelog.d/`, one new
file per pull request, and assembled once per release. A release is therefore a
small, boring, self-contained pull request: it turns the fragments into prose in
two files, moves the version, and deletes what it consumed.

**This is the only change allowed to touch `CHANGELOG.md`,
`flatpak/com.matthiasn.lotti.metainfo.xml`, or the `version:` line in
`pubspec.yaml`.** That rule is the whole point — those three files are written at
the top by everything, so as long as exactly one pull request per release writes
them, nothing can conflict. If you are here for any other reason, you are in the
wrong skill; write a fragment instead (`changelog.d/README.md`).

## Before you start

```bash
git checkout main && git pull
ls changelog.d/[0-9]*.md       # the work queue; README.md is not a fragment
fvm dart run tool/changelog/validate.dart --strict
```

`--strict` rather than `make changelog_check`: the house-style warnings the
author-facing check only prints — an entry with no bold headline, a paragraph
pasted as one long line — are about to become published prose, so here they
block.

- Work from an up-to-date `main`. A release assembled on a stale branch drops
  whatever merged in the meantime.
- If `changelog.d/` holds nothing but its README, there is nothing to release.
  Say so and stop.
- Fix any malformed fragment here, in the release branch. It is cheaper than
  sending the author back.
- A fragment describing something that was reverted before it shipped gets
  deleted, not published.

**Ask before committing, pushing or tagging.** Every step below writes files;
the git operations are the user's call, always.

## 1. Read every fragment

Read them all before writing anything. You are producing one coherent set of
release notes, not a concatenation: two fragments may describe two halves of the
same user-visible change and should be merged into one entry, and a later
fragment may supersede an earlier one.

## 2. Choose the version

```bash
grep -m1 '^version:' pubspec.yaml     # e.g. version: 1.0.13+4352
```

- **Bug fixes alone:** keep the semantic version unchanged and increment only
  the build number (`1.0.21+4362` → `1.0.21+4363`). A fix-only release appends
  its notes to the current top changelog section and metainfo release block; it
  must not create a duplicate `## [1.0.21]` heading or `<release
  version="1.0.21">` block.
- **User-facing additions or changes:** increment the minor version, reset the
  patch component to zero, and increment the build number (`1.0.21+4362` →
  `1.1.0+4363`). Any publishable `Added`, `Changed`, `Deprecated`, or `Removed`
  entry makes this a user-facing release. Do not use patch-version bumps.
- **Build number:** always previous + 1. It only has to be unique and increasing
  per tag — every release lane triggers on tag push, not on merges to `main` —
  so it moves once per release, not once per pull request.

If the user named a version, use it. Otherwise propose one from what the
fragments contain and confirm it.

## 3. Assemble the CHANGELOG section

For a user-facing release, insert one new section at the top of `CHANGELOG.md`,
directly under the Keep a Changelog preamble and above the previous version:

```markdown
## [1.1.0]
### Added
- **...**

### Changed
- **...**

### Fixed
- **...**
```

- **One section per type, in this order**: Added, Changed, Deprecated, Removed,
  Fixed, Security. Skip the ones with no entries. Never repeat a heading inside
  a version — older sections do, because entries used to be appended one PR at a
  time; assembling from fragments is what fixes that.
- **The version heading carries no date.** That is the file's existing shape.
- Keep each entry's wording as the fragment wrote it, minus edits for
  duplication, house voice, or an entry that reads oddly next to its neighbours.
- Wrap at about 78 columns, continuation lines indented two spaces.

For a fix-only build release, add the new bullets to the current top semantic
version instead. Reuse its existing `### Fixed` heading, or create that heading
in the normal section order if it does not have one. Never create a second
version section or a second `### Fixed` heading.

## 4. Write the Flathub release block

For a user-facing release, add one `<release>` to
`flatpak/com.matthiasn.lotti.metainfo.xml`, as the **first** child of
`<releases>` — newest first:

```xml
<release version="1.1.0" date="2026-08-25">
  <description>
    <p>Fixed: ...</p>
  </description>
</release>
```

This is the same prose, mechanically transformed. AppStream renders `<p>` as
plain text: markdown does not survive it, and an unescaped `&` breaks the build.

For a fix-only build release, append the new `Fixed:` paragraphs to the
description of the existing first `<release>` block and update that block's
date to the day the build is cut. Do not create a duplicate release block for
the unchanged semantic version.

| In `CHANGELOG.md` | In the metainfo |
|---|---|
| one `- ` bullet | one `<p>`, same order as the section |
| the `### Fixed` heading above it | the prefix `Fixed: ` on every paragraph in that section |
| `- **Bold headline.** Detail…` | `Fixed: bold headline. Detail…` — bold markers dropped, first letter lowercased unless it is a proper noun (`Settings`, `Flathub`) |
| hard-wrapped over several lines | one long line |
| `—` or `–` | ` - ` |
| `` `code` `` or a glyph like `•••` | plain words a user recognises — `"..."`, `the "Location with the name CEST doesn't exist" error` |
| `&`, `<`, `>` | `&amp;`, `&lt;`, `&gt;` |

Worked example, from 1.0.13:

```markdown
- **Daily habit reminders arrived hours late on iPhone, iPad and Android.** The
  app could not work out which timezone the device was in, quietly settled for
  UTC, and then built the reminder's time of day in UTC — so an 08:00 habit
  reminder rang at 10:00 in Central European Summer Time.
```

```xml
<p>Fixed: daily habit reminders arrived hours late on iPhone, iPad and Android. The app could not work out which timezone the device was in, quietly settled for UTC, and then built the reminder's time of day in UTC - so an 08:00 habit reminder rang at 10:00 in Central European Summer Time.</p>
```

The `date` is the day the release is cut, `YYYY-MM-DD`.

## 5. Bump the version

One line in `pubspec.yaml`:

```yaml
version: 1.1.0+4363
```

## 6. Delete the fragments you consumed

```bash
git rm changelog.d/[0-9]*.md       # fragments start with their date; README.md does not
```

Everything you just published goes. `changelog.d/` holding only its README is
what "nothing unreleased" looks like; git history keeps the originals.

## 7. Verify

```bash
make changelog_check                                     # versions now agree
xmllint --noout flatpak/com.matthiasn.lotti.metainfo.xml # if available
git status --short
```

`git status` must show exactly four kinds of change and nothing else:
`CHANGELOG.md`, the metainfo, `pubspec.yaml`, and deleted fragments. A release
PR that also carries code is a release PR that can conflict.

Re-read the assembled section once as a user would. It is the text that reaches
Flathub, the GitHub release and the app's What's New — it is read far more often
than it is written.

## 8. Open the release pull request

Use the semantic version in the title for a user-facing release:

```
chore(release): 1.1.0
```

Use the full version and build for a fix-only release so it is distinguishable
from the release that first introduced that semantic version:

```
chore(release): 1.0.21+4363
```

Body: the entries assembled for this release, grouped under their release
headings, so review reads the new notes rather than the diff. For a fix-only
release, label the body with the full version and build even though the
changelog heading remains the unchanged semantic version. No screenshots —
nothing visual changed.

## 9. Tag, after it merges

```bash
git checkout main && git pull
make tag_push        # tags 1.1.0+4363 from pubspec.yaml and pushes it
```

`make tag_push` reads the version with `yq`; install it (`brew install yq`) or tag
by hand with the exact `version+build` string if the target reports it missing.

The tag is what ships. Pushing it triggers, in parallel: macOS and iOS
TestFlight, the Android release, the Linux GitHub release, the macOS signed
`.dmg`, and the Flathub submission PR against `flathub/com.matthiasn.lotti` —
which is why the metainfo has to be right *before* the tag, not after.

Confirm with the user before tagging. Watch the lanes; `docs/macos-release.md`
and `docs/flatpak-flathub-recovery.md` cover the two that fail in interesting
ways.

## 10. Downstream, and out of scope here

The app's **What's New** modal reads from the separate `matthiasn/lotti-docs`
repository (`whats-new/`), not from this one. Publishing there is an editorial
step in that repo — mention it once the release is tagged; do not attempt it
from here.

## Gotchas

- **The metainfo lagging a version behind is invisible until Flathub ships it.**
  `make changelog_check` fails on exactly that, which is why it runs in CI on
  every push rather than only at release time.
- **Tags carry the build number** (`1.0.14+4353`), and every release lane keys
  on tag push. Re-tagging the same build number to fix a mistake will not give
  you a fresh TestFlight build; bump the build number and cut again.
- **Do not fold anything else into the release PR** — not a "quick fix", not a
  dependency bump. The moment it carries code it can conflict, and the reason
  this flow exists is gone.
