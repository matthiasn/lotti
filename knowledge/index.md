---
okf_version: "0.2"
---

# Lotti Knowledge Bundle

The architecture of the Lotti app, as it actually runs. Every concept here is
derived from the code it describes and carries the provenance to trace it back to
that code.

Product-level descriptions of what each feature does for a user stay in the
feature's own `README.md` under `lib/`; those READMEs link here for the runtime
detail. See [How this bundle is maintained](conventions/knowledge-bundle.md)
before editing anything.

# Start here

Working on a subsystem, in order:

1. **[`AGENTS.md`](../AGENTS.md)** — how this repository expects work to be done.
   Read it first; it is binding.
2. **The feature's `README.md`** under `lib/features/<name>/` — what the feature
   does and what it owns. One page, no runtime detail.
3. **The concept here** — how it actually works: flows, state machines,
   invariants, the classes that matter, the gotchas. Start at the feature's
   `index.md` when it has one and read only the parts you need.
4. **The [convention](conventions/) that governs what you are about to do** —
   before writing a test, adding a user-visible string, or touching visual code.
   [Testing](conventions/testing.md) for the test harness and the vacuous-pass
   traps (with [`test/README.md`](../test/README.md) for fake time),
   [localization](conventions/localization.md) for ARB catalogues and register,
   [code style](conventions/code-style.md) and
   [the design system](features/design_system/) for tokens instead of literals.
   These are rules, not descriptions: skipping them means rework.
5. **[`docs/adr/`](../docs/adr)** — why it was decided this way, when a concept
   cites an ADR and you need the reasoning rather than the mechanism.

Then, while you work: **verify any claim you are about to depend on against the
source.** These concepts are agent-written maps of a moving codebase, and a map
is not the territory. When you change behaviour, update the concept in the same
change and run `make knowledge_check`.

# Which authority wins

These answer different questions, so they do not sit in one ranking. Match the
question to its authority first:

| Question | Authority |
|----------|-----------|
| **How should this work be done?** | The user's instructions, then [`AGENTS.md`](../AGENTS.md). |
| **What does the app actually do today?** | The source code — then a concept here as its description, then an ADR or git history as a record of how it got that way. |

Within that second row the order is strict: **the code outranks the prose.** If a
concept contradicts the code, the concept is the defect — fix it in the same
change rather than working around it or, worse, "fixing" the code to match the
prose.

The split matters in one direction especially. `AGENTS.md` governs process, so a
*descriptive* claim that has drifted into it — a count, a file list, a version —
carries no more weight than any other stale prose, and **less** than the code it
describes. Treat it as a pointer to check, not a fact to trust.

Two caveats on the concepts themselves. One past its `stale_after` is not wrong by
definition, but it has not been re-read recently — and it **fails the build**, with
a warning for the fortnight beforehand. And no concept here carries a `verified`
entry yet, so treat every one of them as agent-generated until it does.

# Where the code is documented

Every module under `lib/features/` has a `README.md` that links to its concept, and
so do [`lib/services/`](../lib/services/README.md) and
[`lib/widgets/`](../lib/widgets/README.md) — start there. For the trees with no
README, this is the way in:

| Code | Concept | Covers |
|------|---------|--------|
| [`lib/database/`](../lib/database) | [Persistence layer](architecture/persistence.md) | the whole tree |
| [`lib/beamer/`](../lib/beamer) | [Navigation and app shell](architecture/navigation.md) | the whole tree |
| [`lib/classes/`](../lib/classes) | [Domain concepts](domain/) | the entity unions; not every class |
| [`lib/features/goals/`](../lib/features/goals) | [Goal agents — deterministic runtime](features/goals.md) | Phase A: signal reading, evaluation, registers, escalation; entities/vocabulary live in `lib/classes` |
| [`lib/l10n/`](../lib/l10n) | [Localization](conventions/localization.md) | the ARB workflow |
| [`lib/logic/signals/`](../lib/logic/signals) | [Signals — shared journal series](architecture/signals.md) | the whole directory: day bucketing, `SignalReader`, `HabitRuleEvaluator` |
| [`lib/widgets/day_indicators/`](../lib/widgets/day_indicators) | [Day indicators — shared day-mark model and cells](architecture/day-indicators.md) | `DayMark`/`DayMarkState`/`DayVerdict`, `DayMarkCell`, `DayMarkStrip`, `DayTrack` |
| [`lib/logic/`](../lib/logic) | [Persistence layer](architecture/persistence.md) | **almost nothing** — `PersistenceLogic` appears only as a node in the write-path diagram. The import paths and the rest of the tree are undocumented; read the code |
| [`lib/themes/`](../lib/themes) | [Tokens and theming](features/design_system/tokens-and-theming.md) | **`theme_overrides.dart` only**, as the token-injection seam |
| [`lib/utils/`](../lib/utils) | — | nothing; small helpers, read the code |
| [`test/`](../test) | [Testing conventions](conventions/testing.md) + [`test/README.md`](../test/README.md) | the whole tree |
| [`tool/okf/`](../tool/okf) | [How this bundle is maintained](conventions/knowledge-bundle.md) | the whole tree |

Where a row says "only", the concept describes that seam rather than the
directory. Treat the rest of those trees as undocumented and read the code.

# Architecture

* [Architecture concepts](architecture/) - cross-cutting runtime structure: bootstrap, persistence, navigation, security, release.

# Domain

* [Domain concepts](domain/) - the entities the whole app is built on.

# Features

* [Feature concepts](features/) - one concept tree per module under `lib/features`.

# Conventions

* [Convention concepts](conventions/) - the rules this repository holds itself to.

# History

* [Update log](log.md) - when this bundle gained, lost or reorganised a concept.
