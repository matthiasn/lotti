---
type: Convention
title: How this bundle is maintained
description: The README/knowledge/ADR split, the frontmatter every concept carries, and what the validator enforces.
resource: ../../knowledge
tags: [convention, documentation, okf, process]
status: stable
generated: { by: claude-code/fable-5, at: 2026-07-29T01:20:00Z }
stale_after: 2027-01-18
sources:
  - id: okf-spec
    resource: https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md
    title: Open Knowledge Format v0.2 specification
    last_modified: 2026-07-25
  - id: validator
    resource: ../../tool/okf/okf_validator.dart
    title: Conformance validator
    last_modified: 2026-07-26
  - id: mermaid-gate
    resource: ../../tool/okf/check_mermaid.mjs
    title: Mermaid parse gate
    last_modified: 2026-07-29
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

The rule is **one authoritative home per fact.** A README that starts explaining
provider routing or wake scheduling has drifted into the bundle's territory;
move it and link. A concept that opens by explaining what a task is for has
drifted into the README's territory. A concept that argues for a decision rather
than describing what runs belongs in an ADR — concepts *cite* ADRs, because an
ADR is frozen at its date while a concept tracks today's code.

**A short operational summary may repeat a fact, and must link to its home.**
`AGENTS.md` is loaded into every agent's context, so a guardrail that has to fire
before anyone thinks to open a concept — *use informal register*, *tokens are
mandatory* — earns its place there. What must never live in a summary is the
**detail that drifts**: an enumerated list, a count, a table, a value. That is the
distinction between a guardrail and a stale copy, and it is why the twelve ARB
catalogues are named in
[localization](localization.md) while `AGENTS.md` only says *all of them, and here
is where they are listed*.

Applied to this bundle: if you find yourself updating the same sentence in two
files, one of them is the home and the other should have been a link.

Feature READMEs stay short — roughly 40 to 100 lines — and end with a link to
their concept.

# Frontmatter every concept carries

Every key below is **required** — a missing or empty one fails the build. The
comments mark how far the check goes, because presence and correctness are not
the same thing:

```yaml
---
type: Feature Module          # must be a non-empty string; no allowlist (see below)
title: Speech                 # must be a non-empty string
description: One sentence.    # must be a non-empty string. Shown in index listings.
resource: ../../lib/features/speech    # non-empty; must resolve if it leaves the bundle
tags: [speech, audio]         # must be a non-empty list; values unchecked
status: stable                # must be draft | stable | deprecated
generated: { by: claude-code/opus-5, at: 2026-07-25T22:30:00Z }
                              # `by` must match the actor convention, `at` a real ISO 8601 instant
stale_after: 2027-01-25       # must be a real YYYY-MM-DD day, and must not have passed
sources:                      # must be a non-empty list; one entry must leave the bundle
  - id: speech-repo           # must be unique within the concept
    resource: ../../lib/features/speech/repository/audio_recorder_repository.dart
                              # required per entry; must resolve in the repo
    title: AudioRecorderRepository   # unchecked
    last_modified: 2026-07-14 # must be a real YYYY-MM-DD day if present
---
```

- **`type`** is `Architecture`, `Domain Model`, `Feature Module` or `Convention`
  in this bundle. It is the only key OKF itself requires, and the validator only
  requires it to be a non-empty string: **the four names are convention, not an
  enforced allowlist.** OKF defines others, and the validator has extra checks for
  `Attested Computation` (§10.2) should anyone introduce one. Pick a fifth name
  only with a reason, since nothing will stop you.
- **`resource`** is the *subject* of the concept: the directory or file it
  describes, as a bundle-relative path. One per concept. A concept whose subject
  genuinely is the whole repository — release pipelines, security posture — names the
  repository root rather than omitting the key. **`../..` is only correct from a
  concept one directory deep** (`architecture/`, `domain/`, `conventions/`); from
  `features/agents/` it is `../../..`. Count the hops.
- **`tags`** are lowercase search keys — the feature name, the subsystem, the
  nouns someone would grep for. They are not a taxonomy; nothing dispatches on
  them. Required, but the values are free-form and unchecked.
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
  as a repo-relative path. At least one source must point *outside* the bundle —
  a concept sourced only from sibling concepts is grounded in nothing the drift
  check can pull on. **Where it points decides the severity**: a source outside
  the bundle that no longer resolves is an error, while one pointing at a
  bundle-internal path that does not exist is only a warning, because §6.1 allows
  a pointer to knowledge not written yet.
- **`sources[].id`** is a short slug, unique within the concept, that footnote
  attribution joins on. **`sources[].title`** names the thing in prose.
- **`sources[].last_modified`** is the day that source was last changed, as
  `YYYY-MM-DD` — `git log -1 --format=%ad --date=short -- <path>` is where to get
  it. It is a record of what the concept was written against, not a promise
  about now: when it trails the file's real history by a lot, the concept was
  written against an older shape of the code.
- **`stale_after`** is an absolute date, and **passing it fails the build** — it
  is a commitment to re-read by, not a hint. Pick the window from how fast the
  subject changes:

  | Subject | Window |
  |---------|--------|
  | `agents`, `ai`, `daily_os_next`, `sync` — under active development | ~3 months |
  | Other features, architecture, conventions | ~6 months |
  | Domain models, and exploratory work that has settled | ~12 months |

  A concept whose `status` is `draft` is **not** settled by definition, whatever
  its subject — it takes the ~6-month window until it earns `stable`.

  Then **use the date its siblings already carry.** For a concept inside a
  directory that is the subsystem's date: re-reading all of `sync/` in one sitting
  is far cheaper than seven separate visits. The 23 single-file features have no
  subsystem to inherit from, so they are batched **alphabetically** in three groups
  (`ai_chat`…`habits`, `insights`…`ratings`, `settings`…`whats_new`) — arbitrary,
  but stable and easy to extend. Never invent a new date.

  Across subsystems the dates are **staggered a week apart**, so the reminders
  arrive as a trickle of coherent batches. Two failure modes to avoid: a single
  shared date, which expires the bundle in one burst and says nothing about what
  actually moves, and a per-file date, which turns one afternoon of re-reading
  into fifteen interruptions.

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
   concept, a removed one, a reorganisation. Not for routine edits. **A date's entry
   records the net outcome**: if a later change the same day reverses an earlier
   claim, rewrite the entry rather than appending a contradiction, or the log ends up
   asserting both.
5. Run `make knowledge_check`.

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

- A missing or empty `title`, `description`, `resource`, `tags`, `status`,
  `generated`, `stale_after` or `sources`.
- A `status` outside `draft`, `stable`, `deprecated`; a `title` or `description`
  that is not a non-empty string. **`type` is checked for non-emptiness against no
  allowlist**, and `tags` only for being a non-empty list — the tag values
  themselves are never checked.
- A `generated` that is not a `{ by, at }` mapping, a missing `generated.by`, a
  missing `at`, or a datetime that is malformed or names an impossible instant.
- A `verified` entry that is not `{ by, at }`, is missing `by`, or carries an `at`
  that is missing or malformed.
- An actor outside the `<producer>/<version>` / `human:<id>` / `process:<id>`
  convention — in `generated.by`, in a `verified` entry's `by`, or in the optional
  `sources[].author`. **`verified` takes either shape**: a single `{ by, at }`
  mapping, as in the template above, or a list of them for more than one
  confirmation. The validator treats a bare mapping as a one-element list, which is
  why its messages say `verified[]`.
- A root `index.md` whose frontmatter will not parse, or is not a mapping.
- A `stale_after` that is not an absolute `YYYY-MM-DD` day.
- A `sources` that is null, not a list, or empty; an entry that is not a mapping;
  a missing or non-string `resource`; a duplicate `id`; a `last_modified` that is
  not `YYYY-MM-DD`.
- **A source set that never leaves the bundle.** At least one entry must cite
  code, a URL or a §5.1 scope descriptor, because the anti-drift check can only
  pull on a reference that points outward.
- A root `index.md` that declares no `okf_version`, or declares one this
  validator does not implement.
- **A concept whose `stale_after` has passed.** The date is a commitment to
  re-read by, so `make knowledge_check` and CI both stop on it. Clearing it means
  re-reading the concept against the code — or deciding, deliberately, to move the
  date. **Fourteen days out it starts warning**, so a batch coming due is never
  first heard about as a red push.
- **A fenced block that never closes on a line of its own.** CommonMark accepts a
  closing fence only when nothing else is on the line, so ```` ``` and then
  prose ```` leaves the block open and renders the rest of the page as code. This
  shipped once, in a mermaid diagram, and the link scanner did not notice because
  it is deliberately looser about where a block ends.

**Warnings** — reported, not fatal:

- A bundle-internal reference with no target yet — a body link, a
  `sources[].resource`, or the top-level `resource`. OKF §6.1 says a pointer to
  not-yet-written knowledge is legitimate, so this stays advisory on purpose.
  **Only references that leave the bundle are errors.**
- An `index.md` with no heading to group its entries under, a `log.md` with no
  dated entries, or a bundle with no root `index.md`.
- An `Attested Computation` missing `runtime`, missing both a `computation` path
  and a `# Computation` section, or carrying a `computation` that is not a path.
  No concept here uses that type yet.

`dart run tool/okf/validate.dart --warnings-as-errors` treats everything as fatal,
which is useful locally before a PR. CI does not pass it, because it would also
reject the forward links §6.1 permits. An unrecognised flag is rejected rather
than ignored — a near-miss like `--warnings-as-error` used to run non-strict and
report a clean bundle that had never been checked strictly.

# Diagrams

Use Mermaid generously, and **diagram the lifecycle when the code has one** —
prefer `stateDiagram-v2`, and never draw a state the code does not implement.
A diagram earns its place by carrying what prose cannot: an ordering, a fork, a
band of stability. A box-per-paragraph restatement does not.

**The Dart validator cannot parse Mermaid** — there is no Dart parser — so
`make knowledge_check` runs Mermaid itself under jsdom, and the `mermaid` CI job
does the same on every push. Before that existed, three broken diagrams shipped.
One trap accounts for all three:

**`;` terminates a statement, in every diagram type.** A semicolon inside a label
ends the statement there, and everything after it is reparsed as a *new*
statement. **Use a comma.** What happens next depends on the diagram, and the
quiet case is the dangerous one:

| Where | `A --> B: x; y` becomes |
|-------|-------------------------|
| `sequenceDiagram` | A parse error — the remainder needs an arrow. Loud, and caught. |
| `stateDiagram-v2`, remainder is a bare word | **A stray state node named `y`**, rendered silently. The parse check passes and the diagram is wrong. |
| `stateDiagram-v2`, remainder has a hyphen | A parse error, because `re-warms` is not a valid state id. |

Do not read `:=` as a second trap — it was blamed once and is fine on its own;
`A --> B: id := joinId` parses. It was the `;` beside it that broke the diagram.

Write the canonical ```` ```mermaid ```` fence. The checker accepts every
CommonMark form — `~~~mermaid`, longer backtick runs, an indent of up to three
spaces — because matching only the canonical one skipped the others *in silence*,
which is the one failure a checker must never have.

**Four spaces of indent is not a fence.** CommonMark reads it as an indented code
block, so that is how to show a mermaid fence as an *example* without either
checker treating it as a diagram.

Two more rules both checkers follow, because getting them wrong hides a broken
diagram rather than reporting one:

- **A closing fence must be a uniform run** of the opener's character, at least as
  long. A mixed `` `~~ `` does not close a ``` block — it used to, which left the
  remainder of a file rendering as code while the check passed.
- **Blockquote containers are stripped to the opener's depth.** `> ```mermaid` is a
  real diagram and its body is unwrapped before parsing, and the marker's trailing
  space is optional — `>flowchart TD` under a `> ` opener is the same container. A
  `>` appearing *inside* a top-level fence stays literal, because stripping
  unconditionally let it masquerade as the close and an unclosed fence validated
  clean. **List-item containers are not modelled**: a fence indented past three
  spaces inside a list item reads as an indented code block, so keep diagrams at the
  top level of a document.

**The gate covers `knowledge/`, `docs/adr/` and `docs/architecture/`.**
`check_mermaid.mjs` takes any number of roots, and `npm run check` passes all
three — 185 blocks. The ADRs were added once two of their diagrams turned out
not to render: concepts cite ADRs rather than restating their decisions, so a
decision record nobody can read is the same defect as a broken concept.

**Implementation plans stay outside it**, and 10 of their diagrams do not
render today. They are working notes rather than the durable map, and some are
historical by design. Widening the gate to `docs/` means fixing those first —
tracked separately, not assumed.

**`make knowledge_check` is the one target to run after touching `knowledge/`.**
It runs the Dart validator and the Mermaid parse together, because two targets
meant the second one got skipped. `make okf_check` and `make mermaid_check`
remain for running half of it deliberately. The Mermaid half lives in
[`tool/okf/check_mermaid.mjs`](../../tool/okf/check_mermaid.mjs) with its own
pinned `package.json`, so it needs Node but nothing from the Flutter toolchain.

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
