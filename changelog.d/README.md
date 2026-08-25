# Unreleased notes

**One pull request, one new file in this folder. Nothing else.**

`CHANGELOG.md`, `flatpak/com.matthiasn.lotti.metainfo.xml` and the `version:`
line in `pubspec.yaml` are all written at the top, in the same few lines, by
every change that lands. Git merges edits made in different places; it cannot
merge two rewrites of the same lines. So the first PR to merge left every other
open PR conflicted — over release prose, not over code.

A fragment is a file that did not exist before, named after your change. Two of
those cannot conflict. The three shared files are written exactly once per
release, by the release, which is the only change allowed to touch them.

## Write one

Name it `YYYY-MM-DD-short-slug.md` — today's date, then a lower-kebab slug of
the change:

```
changelog.d/2026-08-25-habit-reminder-timezone.md
```

Inside, write the entry exactly as it should read in `CHANGELOG.md`:

```markdown
### Fixed
- **Daily habit reminders arrived hours late on iPhone and Android.** The app
  could not work out which timezone the device was in, quietly settled for UTC,
  and then built the reminder's time of day in UTC — so an 08:00 habit reminder
  rang at 10:00 in Central European Summer Time. Reminders now use the zone the
  device is actually in.
```

That is the whole file. The release pastes it in as it stands.

- **Sections** are `### Added`, `### Changed`, `### Deprecated`, `### Removed`,
  `### Fixed` and `### Security`. Use as many as your change needs, in one file.
- **Every entry opens with a bold headline sentence**, then the detail: what was
  wrong or missing, what it does now, and what a user will notice. Written for
  someone who does not know the code and will read it in the app's What's New.
- **Wrap prose at about 78 columns**, the way `CHANGELOG.md` does. Continuation
  lines are indented by two spaces.
- **No version heading.** `## [1.0.14]` is the release's job, not yours.

## Skip one

Fragments are for what a user would actually notice. No fragment for dependency
bumps with no behaviour change, internal refactors, test-only changes, build and
CI tweaks, or documentation. Nor for a bug that was introduced and fixed inside
the same unreleased feature — it never reached anyone.

## Check it

```bash
make changelog_check
```

It runs in CI on every push. It also fails when the released version disagrees
across the three shared files, which is how a release that half-landed gets
caught before Flathub ships notes for the wrong version.

## What happens next

At release time the fragments here are assembled into one `## [version]` section
in `CHANGELOG.md` and one `<release>` block in the Flathub metainfo, the version
is bumped, and these files are deleted — in a single release pull request. The
runbook for that is [`.agents/skills/release/SKILL.md`](../.agents/skills/release/SKILL.md).

Whatever is sitting in this folder is, by definition, what has not shipped yet.
