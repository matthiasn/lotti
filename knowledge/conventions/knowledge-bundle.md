---
type: Convention
title: How this bundle is maintained
description: The README/knowledge split, the frontmatter every concept carries, and what the validator enforces.
resource: ../../knowledge
tags: [convention, documentation, okf, process]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: okf-spec
    resource: https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md
    title: Open Knowledge Format v0.2 specification
    last_modified: 2026-07-25
  - id: validator
    resource: ../../tool/okf/okf_validator.dart
    title: Conformance validator
    last_modified: 2026-07-26
  - id: agents-md
    resource: ../../AGENTS.md
    title: Repository guidelines
    last_modified: 2026-07-26
---

# One fact, one home

Documentation in this repository is split by *audience*, not by convenience:

| Where | Answers | Example |
|-------|---------|---------|
| `lib/features/<x>/README.md` | **What does this feature do, and what does it own?** Product behaviour, scope boundary, where the code sits. | "Speech captures audio, plays it back, and keeps transcripts and per-category dictionaries." |
| `knowledge/features/<x>*.md` | **How does it actually work at runtime?** Flows, state machines, invariants, key classes, gotchas. | "Recording writes to disk first; transcription is a separate AI-side call with no realtime path." |

The rule is that **no fact is written twice.** A README that starts explaining
provider routing or wake scheduling has drifted into the bundle's territory;
move it and link. A concept that opens by explaining what a task is for has
drifted into the README's territory.

Feature READMEs stay short — roughly 40 to 100 lines — and end with a link to
their concept.

# Frontmatter every concept carries

```yaml
---
type: Feature Module          # Architecture | Domain Model | Feature Module | Convention
title: Speech
description: One sentence. Shown in index listings and search snippets.
resource: ../../lib/features/speech    # the code this concept describes
tags: [speech, audio, transcription]
status: stable                # draft | stable | deprecated
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
stale_after: 2027-01-31
sources:
  - id: speech-repo
    resource: ../../lib/features/speech/repository/audio_recorder_repository.dart
    title: AudioRecorderRepository
    last_modified: 2026-07-14
---
```

- **`generated.by`** follows the OKF actor convention: `<producer>/<version>`
  for a tool, `human:<id>` for a person. Be honest — if an agent wrote it, say
  so.
- **`verified`** is *not* set by whoever wrote the concept. It records an
  independent confirmation against the code, and a `human:<id>` entry is what
  raises the concept to the human-reviewed trust tier. Adding
  `verified: { by: human:you, at: ... }` to your own freshly-generated text
  defeats the point of having the field.
- **`sources[].resource`** points at the code the concept was derived from,
  as a repo-relative path. The validator resolves these, so a source that moves
  or disappears fails the build.
- **`stale_after`** is an absolute date. A concept past it is not wrong by
  definition, but it is due for a re-read.

# The rule that keeps it honest

Every markdown link and every `sources[].resource` that points outside the
bundle must resolve to a real file or directory in the repository. The
validator treats a dangling code pointer as an **error**, not a warning.

This is the mechanism that makes the bundle self-correcting: when someone
renames `lib/features/foo/bar.dart`, CI fails on the concept that still cites
it, and the person doing the rename is the one holding the context needed to
fix the prose.

Links *inside* the bundle are warnings only — OKF §6.1 says a link to
not-yet-written knowledge is legitimate.

# When you change code

1. Update the feature's concept in `knowledge/` if runtime behaviour changed.
2. Update the feature `README.md` if the product behaviour or ownership changed.
3. Bump `generated.at` on any concept you rewrote, and push `stale_after` out.
4. Add a line to [`knowledge/log.md`](../log.md) for a structural change — a new
   concept, a removed one, a reorganisation. Not for routine edits.
5. Run `make okf_check`.

# What the validator checks

`tool/okf/validate.dart` implements OKF v0.2 §11 plus this repo's house rules.

**Errors** — these fail CI:

- A concept with no parseable YAML frontmatter, or frontmatter that is not a
  mapping.
- A concept with a missing or empty `type`.
- Frontmatter in a non-root `index.md`, or anything but `okf_version` in the
  root one.
- Frontmatter in a `log.md`, or a date heading that is not `YYYY-MM-DD`.
- Any reference leaving the bundle that does not resolve in the repository.

**Warnings** — reported, not fatal:

- Missing `title`, `description`, `status` or `generated`.
- An actor that does not match the convention, a malformed date, an invalid
  `status`, a duplicate `sources[].id`.
- A bundle-internal link with no target yet.

Run `dart run tool/okf/validate.dart --warnings-as-errors` to treat everything
as fatal, which is useful before opening a PR.

# Structure

```
knowledge/
  index.md              root listing, declares okf_version
  log.md                structural history
  architecture/         cross-cutting runtime — no single feature owns these
  domain/               the entities everything else moves around
  features/             one concept per lib/features module; a directory when large
  conventions/          rules this repository holds itself to
```

A feature gets a **directory** rather than a single file once its knowledge
exceeds a couple of hundred lines. When it does, add an `index.md` listing the
parts — that is what makes progressive disclosure work for an agent that should
not read 2,000 lines to answer one question.
