# Knowledge Bundle Update Log

## 2026-07-26
* **Fix**: Recomputed every `sources[].last_modified` from `git log` — 162 of 229
  had been written as "about today" rather than asked of history, some off by six
  weeks. The field now records what each concept was actually written against.
* **Fix**: Corrected fourteen claims that contradicted the code, across habits,
  the knowledge-graph PoC, settings, sync, persistence, the journal entity, task
  relationships, the CI story and the build-runner trap. Four `lib/` READMEs were
  wrong too, and `memory-and-compaction`'s subject pointed at a directory holding
  one unrelated file.
* **Creation**: Documented the slow-query capture's **second tier** — the 200 ms
  threshold that also captures `EXPLAIN QUERY PLAN` and writes a separate
  `super_slow_queries` file, which is the one worth reading first.
* **Creation**: Documented three things the bundle had no home for — the
  `private` visibility gate every `JournalDb` read routes through (a filter, not
  a protection), `TaskStatus`'s five states and the fact that *nothing* constrains
  their transitions, and which nine of `lib/widgets/`'s sixteen groups the
  shared-widgets concept does not cover.
* **Update**: Added diagrams to the seven concepts whose subject has a shape
  prose cannot carry — the `JournalEntity` union, the `linked_entries` row, the
  projection kernel's permutation invariance, the idle gate's state machine, the
  wake prompt's stability bands, dashboard item dispatch, and theming's
  arrival-based sync. 69 of 88 concepts now carry at least one.
* **Fix**: Repaired three Mermaid diagrams that did not parse and one closing
  fence with prose welded to it, which had been rendering the tail of a concept
  as code. The validator now fails on an unclosed fence; Mermaid syntax itself
  still needs the out-of-band parse check documented in the convention.
* **Update**: Raised the house-rule metadata checks from warnings to errors, so
  a concept missing a description, a freshness date or code provenance now fails
  CI rather than being reported and ignored. What stays a warning is what OKF is
  deliberately permissive about — a link to knowledge not written yet — plus a
  concept whose `stale_after` has passed, which is now reported.
* **Update**: Gave [the root index](index.md) a reading order, an authority
  hierarchy and a code-to-concept map for the shared trees under `lib/` that have
  no README of their own.
* **Reorganisation**: Collapsed 23 feature directories that held a single
  sub-200-line concept into one file each — `features/categories/overview.md`
  became `features/categories.md`. An index listing one document is a hop, not
  progressive disclosure. The count of concepts is unchanged; 24 index files are
  gone.
* **Reorganisation**: Moved the projection kernel from `features/agents_projection/`
  to [`features/agents/projection.md`](features/agents/projection.md). It
  documents `lib/features/agents/projection`, so it was a sibling of the feature
  that owns it rather than a part of it.
* **Update**: Differentiated `stale_after` by how fast each subject moves —
  three months for `agents`, `ai`, `daily_os_next` and `sync`, twelve for domain
  models and settled exploratory work, six for everything else. One shared date
  expired the whole bundle on a single day and said nothing about which concepts
  actually change.
* **Update**: Split the overlapping settings prose — `settings_v2` owns the tree
  and the argument for having one, `settings` owns the shell that renders it —
  and dropped the drift-prone inventory counts from the reserved `index.md`
  files, which carry no freshness metadata of their own.

## 2026-07-25
* **Initialization**: Established the OKF v0.2 bundle at `knowledge/`, with the
  conformance validator in `tool/okf/`, the `make okf_check` target, a CI
  workflow, and the maintenance rules in
  [How this bundle is maintained](conventions/knowledge-bundle.md).
* **Creation**: Mapped the cross-cutting runtime in
  [architecture](architecture/) — overview, bootstrap and dependency injection,
  persistence, navigation, security and privacy, logging, platform and release,
  shared widgets.
* **Creation**: Mapped the [domain model](domain/) — the `JournalEntity` union
  and its `Metadata` envelope, entry links, and entity definitions.
* **Migration**: Moved the architecture out of all 40 feature READMEs under
  `lib/` into [feature concepts](features/), leaving each README as a product
  description that links here. 19,269 README lines became 1,654; the
  architecture they carried became 88 concepts.
* **Creation**: Recorded the repository's own rules as
  [conventions](conventions/) — testing, localization, code style.
* **Update**: Moved `lib/features/sync/current_architecture.md` to
  `docs/architecture/sync_current_architecture.md`; an investigation log is not
  product documentation.
