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
4. **[`docs/adr/`](../docs/adr)** — why it was decided this way, when a concept
   cites an ADR and you need the reasoning rather than the mechanism.
5. **[`test/README.md`](../test/README.md)** — before writing a test, always.

Then, while you work: **verify any claim you are about to depend on against the
source.** These concepts are agent-written maps of a moving codebase, and a map
is not the territory. When you change behaviour, update the concept in the same
change and run `make okf_check`.

# Which authority wins

When two of these disagree, the one higher up is right:

| Rank | Source | Why |
|------|--------|-----|
| 1 | `AGENTS.md` and the user's instructions | They say what to do, not what is. |
| 2 | **The current source code** | It is what runs. Nothing here outranks it. |
| 3 | A concept in this bundle | A derived description, true as of its `generated.at`. |
| 4 | An ADR, a `log.md` entry, git history | A record of a past decision, deliberately not updated. |

So: **if a concept contradicts the code, the concept is the defect** — fix it in
the same change rather than working around it or, worse, "fixing" the code to
match the prose. A concept past its `stale_after` is not wrong by definition, but
it has not been re-read recently; `make okf_check` reports it. And no concept
here carries a `verified` entry yet, so treat every one of them as
agent-generated until it does.

# Where the code is documented

Every module under `lib/features/` has a `README.md` that links to its concept,
so start there. The shared trees have no README, and are documented here:

| Code | Concept |
|------|---------|
| [`lib/database/`](../lib/database) | [Persistence layer](architecture/persistence.md) |
| [`lib/logic/`](../lib/logic) | [Persistence layer](architecture/persistence.md) — `PersistenceLogic` and the import paths |
| [`lib/services/`](../lib/services) | [Bootstrap and DI](architecture/bootstrap-and-di.md), and [Logging](architecture/logging-and-diagnostics.md) for `LoggingService` |
| [`lib/beamer/`](../lib/beamer) | [Navigation and app shell](architecture/navigation.md) |
| [`lib/classes/`](../lib/classes) | [Domain concepts](domain/) |
| [`lib/widgets/`](../lib/widgets) | [Shared widgets](architecture/shared-widgets.md) |
| [`lib/themes/`](../lib/themes) | [Tokens and theming](features/design_system/tokens-and-theming.md) |
| [`lib/l10n/`](../lib/l10n) | [Localization](conventions/localization.md) |
| [`test/`](../test) | [Testing conventions](conventions/testing.md) |
| [`tool/okf/`](../tool/okf) | [How this bundle is maintained](conventions/knowledge-bundle.md) |

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
