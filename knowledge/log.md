# Knowledge Bundle Update Log

## 2026-08-05
* **Addition**: New architecture concept
  [Profiles and demo mode](architecture/profiles-and-demo-mode.md) — the
  registry, the guest-world isolation contract, capability-gated sync, and the
  in-app switch — alongside [ADR 0049](../docs/adr/0049-profile-scoped-storage-and-demo-mode.md)
  for the storage-scoping decision.
* **Addition**: New feature concept [Demo mode](features/demo.md) — the seed
  manifest lifecycle, exit copy-over closure semantics and v1 exclusions, the
  real-AI nudge, and the fixture-ownership rule that keeps the manual's
  screenshot suites pixel-identical.

## 2026-07-29
* **Removal**: Removed the Character animation concept after its unused
  implementation was deleted, so the bundle no longer describes or links to a
  feature that is absent from the repository.
* **Correction**: Clarified that explicit sync bridge calls await every
  single-flight rerun coalesced onto the active pass, while attachment downloads
  retain their independent queue and drain point.
* **Correction**: Documented the bootstrap ordering contract for freshly
  decrypted attachment descriptors: they enter the bounded attachment worker
  pool before queue classification drops the non-payload event.

## 2026-07-26
* **Enforcement**: The metadata that makes drift detectable now fails the build
  instead of being reported and ignored — a missing or empty `title`,
  `description`, `resource`, `tags`, `status`, `generated`, `stale_after` or
  `sources`, a source set that never leaves the bundle, an unclosed fenced block,
  and a `stale_after` that has passed (with a warning for the fortnight before).
  What stays advisory is the narrow set OKF is deliberately permissive about, plus
  the `Attested Computation` fields nothing here uses. An unrecognised CLI flag is
  rejected rather than ignored.
* **Enforcement**: Mermaid is parsed in CI by mermaid itself
  ([`tool/okf/check_mermaid.mjs`](../tool/okf/check_mermaid.mjs), 15 tests), since
  there is no Dart parser. It accepts every CommonMark fence form, treats a
  four-space-indented fence as the literal it is, and inspects the built diagram —
  a `;` in an unquoted label parses clean while rendering phantom nodes. Three
  diagrams that never rendered and one closing fence with prose welded to it were
  repaired. `make knowledge_check` runs the validator and this together.
* **Reorganisation**: Collapsed 23 feature directories holding a single
  sub-200-line concept into one file each, and moved the projection kernel under
  the agents tree. 24 index files gone, concept count unchanged.
* **Update**: Staggered `stale_after` by subsystem — 15 review dates instead of
  one shared cliff, at most eleven concepts each.
* **Fix**: Corrected roughly thirty claims against the code. The load-bearing ones,
  in their final form: the `private` gate is reached **three** ways and nine of the
  ten query-bearing mixins use one, while **single-entity journal reads** skip
  filtering; `PROPAGATED::` is **additive**, so matching the bare token alone is
  complete, and the wake deferral it enables is opt-in per subscription;
  `DerivedAgentState` **is** on the wake critical path via
  `AgentSyncService.reconciledAgentState`, while UI and service reads stay on the
  raw cache; CI runs `very_good test`
  with its optimizer on, so a leak reaches other files **in the same shard**;
  `TaskStatus` has **seven** variants; an error reaches **two to four** files
  including the PII-safe `error-safe-<date>.log`; and the build-runner
  `--build-filter` trap **does** show in `git status`, which is the only signal
  there is.
* **Fix**: Recomputed every `sources[].last_modified` from `git log` — 162 of 229
  were written as "about today" rather than asked of history, some off by six
  weeks. All 238 match now.
* **Creation**: Documented what had no home: the `private` visibility gate, the
  `UpdateNotifications` routing-key vocabulary and its `PROPAGATED::` semantics,
  `DerivedAgentState` with the shadow comparison, the error-log mirrors including
  the PII-safe sink, the slow-query second tier, `TaskStatus` and the fact that
  nothing constrains its transitions, and which nine of `lib/widgets/`'s sixteen
  groups the shared-widgets concept omits.
* **Creation**: Added [screenshots](conventions/screenshots.md) — where captured
  images live (the sibling `lotti-docs` repo, never here), its three destinations
  and their lifecycles, and the before/after pair a UI pull request carries. The
  practice held ~1,100 files across 37 topics and was documented nowhere.
* **Update**: Gave [the root index](index.md) a reading order, an authority
  hierarchy, and a code-to-concept map for the shared trees under `lib/`; added
  diagrams to seven concepts, so 69 of 89 carry at least one.

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
