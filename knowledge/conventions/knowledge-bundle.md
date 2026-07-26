---
type: Convention
title: How this bundle is maintained
description: The README/knowledge/ADR split, the frontmatter every concept carries, and what the validator enforces.
resource: ../../knowledge
tags: [convention, documentation, okf, process]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T09:30:00Z }
stale_after: 2027-01-26
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
| [`docs/adr/`](../../docs/adr) | **Why was it decided this way, and when?** One decision, at one point in time, not rewritten afterwards. | "ADR 0022: time analysis queries julianday over epoch ints." |

The rule is that **no fact is written twice.** A README that starts explaining
provider routing or wake scheduling has drifted into the bundle's territory;
move it and link. A concept that opens by explaining what a task is for has
drifted into the README's territory. A concept that argues for a decision rather
than describing what runs belongs in an ADR — concepts *cite* ADRs, because an
ADR is frozen at its date while a concept tracks today's code.

The same rule binds `AGENTS.md`. When a repository instruction and a concept
would state the same fact, the instruction links the concept instead of repeating
it — a copy in `AGENTS.md` is loaded into every agent's context and is the copy
nobody remembers to update.

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
stale_after: 2027-01-25       # from the volatility table below
sources:
  - id: speech-repo
    resource: ../../lib/features/speech/repository/audio_recorder_repository.dart
    title: AudioRecorderRepository
    last_modified: 2026-07-14
---
```

Every one of those keys is required here, and a missing or malformed one is a
build failure — see [what the validator checks](#what-the-validator-checks).

- **`type`** is one of `Architecture`, `Domain Model`, `Feature Module` or
  `Convention`. It is the only key OKF itself requires.
- **`resource`** is the *subject* of the concept: the directory or file it
  describes, as a bundle-relative path. One per concept.
- **`tags`** are lowercase search keys — the feature name, the subsystem, the
  nouns someone would grep for. They are not a taxonomy; nothing dispatches on
  them.
- **`generated.by`** follows the OKF actor convention: `<producer>/<version>`
  for a tool, `human:<id>` for a person. Be honest — if an agent wrote it, say
  so. **`generated.at`** is a full ISO 8601 timestamp, bumped whenever the prose
  is rewritten.
- **`verified`** is *not* set by whoever wrote the concept. It records an
  independent confirmation against the code, and a `human:<id>` entry is what
  raises the concept to the human-reviewed trust tier. Adding
  `verified: { by: human:you, at: ... }` to your own freshly-generated text
  defeats the point of having the field. No concept in this bundle carries one
  yet, so treat every concept as agent-written until it does.
- **`sources[].resource`** points at the code the concept was derived from,
  as a repo-relative path. The validator resolves these, so a source that moves
  or disappears fails the build. At least one source must point *outside* the
  bundle — a concept sourced only from sibling concepts is grounded in nothing
  the drift check can pull on.
- **`sources[].id`** is a short slug, unique within the concept, that footnote
  attribution joins on. **`sources[].title`** names the thing in prose.
- **`sources[].last_modified`** is the day that source was last changed, as
  `YYYY-MM-DD` — `git log -1 --format=%ad --date=short <path>` is where to get
  it. It is a record of what the concept was written against, not a promise
  about now: when it trails the file's real history by a lot, the concept was
  written against an older shape of the code.
- **`stale_after`** is an absolute date. A concept past it is not wrong by
  definition, but it is due for a re-read, and the validator says so. Pick the
  window from how fast the subject changes:

  | Subject | Window |
  |---------|--------|
  | `agents`, `ai`, `daily_os_next`, `sync` — under active development | ~3 months |
  | Other features, architecture, conventions | ~6 months |
  | Domain models and settled exploratory work | ~12 months |

  A single shared date across the bundle is the failure mode to avoid: it
  expires everything on one day and tells a reader nothing about which concepts
  actually move.

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
3. Bump `generated.at` on any concept you rewrote, and push `stale_after` out by
   the window its subject earns.
4. Add a line to [`knowledge/log.md`](../log.md) for a structural change — a new
   concept, a removed one, a reorganisation. Not for routine edits.
5. Run `make okf_check`.

**If a concept contradicts the code, the concept is the defect.** Fix it in the
same change — you are the last person who will hold both halves in mind at once.
Never edit the prose to match a belief about the code you have not checked: the
value of this bundle is that every sentence in it was true of a real file at a
knowable date.

# What the validator checks

The rules live in [`tool/okf/okf_validator.dart`](../../tool/okf/okf_validator.dart);
[`validate.dart`](../../tool/okf/validate.dart) is the CLI that walks the tree and
hands it over. Together they implement OKF v0.2 §11 plus this repo's house rules.

The split between the two severities is deliberate. **An error is something the
author did**; a warning is either a case OKF is intentionally permissive about,
or a signal nobody's edit caused.

**Errors** — these fail CI.

Spec conformance:

- A concept with no parseable YAML frontmatter, or frontmatter that is not a
  mapping.
- A concept with a missing or empty `type`.
- Frontmatter in a non-root `index.md`, or anything but `okf_version` in the
  root one.
- Frontmatter in a `log.md`, or a `##` heading that is not `YYYY-MM-DD`.
- Any reference leaving the bundle that does not resolve in the repository,
  including one that climbs past the repository root.

House rules — OKF grades these `SHOULD`, this repo does not:

- A missing or empty `title`, `description`, `status`, `generated`,
  `stale_after` or `sources`.
- A `status` outside `draft`, `stable`, `deprecated`; a `title` or `description`
  that is not a non-empty string.
- A `generated` that is not a `{ by, at }` mapping, a missing `generated.by`, an
  actor outside the convention, or a datetime that is malformed or names an
  impossible instant.
- A `verified` entry that is not `{ by, at }`, or is missing `by`.
- A `stale_after` that is not an absolute `YYYY-MM-DD` day.
- A `sources` that is null, not a list, or empty; an entry that is not a mapping;
  a missing or non-string `resource`; a duplicate `id`; a `last_modified` that is
  not `YYYY-MM-DD`.
- **A source set that never leaves the bundle.** At least one entry must cite
  code, a URL or a §5.1 scope descriptor, because the anti-drift check can only
  pull on a reference that points outward.
- A root `index.md` that declares no `okf_version`, or declares one this
  validator does not implement.
- **A fenced block that never closes on a line of its own.** CommonMark accepts a
  closing fence only when nothing else is on the line, so ```` ``` and then
  prose ```` leaves the block open and renders the rest of the page as code. This
  shipped once, in a mermaid diagram, and the link scanner did not notice because
  it is deliberately looser about where a block ends.

**Warnings** — reported, not fatal:

- A bundle-internal link with no target yet. OKF §6.1 says a link to
  not-yet-written knowledge is legitimate, so this one stays advisory on
  purpose.
- A concept whose `stale_after` has passed. The calendar caused it, not the
  change under review; failing an unrelated PR for it would only teach people to
  push the date out without re-reading the code.
- An `index.md` with no heading to group its entries under, a `log.md` with no
  dated entries, or a bundle with no root `index.md`.
- An `Attested Computation` missing `runtime` or a `# Computation` section. No
  concept here uses that type yet.

Run `dart run tool/okf/validate.dart --warnings-as-errors` to treat everything
as fatal. `make okf_check` does not, so that an expired concept or a forward
link never blocks an unrelated change.

# Diagrams

Use Mermaid generously, and **diagram the lifecycle when the code has one** —
prefer `stateDiagram-v2`, and never draw a state the code does not implement.
A diagram earns its place by carrying what prose cannot: an ordering, a fork, a
band of stability. A box-per-paragraph restatement does not.

**The validator does not parse Mermaid**, so a syntactically broken diagram
reaches the reader as an error box. Three did. Two traps account for all of them:

- **`;` is a statement separator**, in every diagram type. A semicolon inside a
  label ends the statement there and the remainder parses as garbage. Use a
  comma.
- **A second `:` breaks a `stateDiagram-v2` transition label.** `x := y` reads as
  a new label boundary. Say "becomes" instead.

To check every block for real, parse them with Mermaid itself:

```bash
npm install mermaid jsdom   # in a scratch directory, not the repo
```

then load each ```` ```mermaid ```` block from `knowledge/` and call
`mermaid.parse` on it under jsdom. That catches what CI currently cannot.

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

Below that size it stays **one file**, `features/<name>.md`, and no `index.md` of
its own. An index that lists a single document is not disclosure, it is a hop:
the reader pays a file read to be told where the file is. Split a feature when
there is something to choose between, not on principle.

A submodule large enough to earn a concept of its own lives **inside its
feature's directory** — `features/agents/projection.md`, not a sibling of
`agents/` — so the directory layout keeps matching `lib/features/`.
