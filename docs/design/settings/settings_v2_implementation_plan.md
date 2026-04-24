# Settings A2 — Tree-Nav + Detail Pane Implementation

## Context

The spec `docs/design/settings/design_spec.md` defines a two-column desktop Settings surface: an expanding tree-nav on the left, a detail pane on the right, with a 56 dp header carrying title + breadcrumbs above both. Today's Settings (`SettingsRootPage` + `SettingsColumnStackView`) uses a horizontal column-stack that drills deeper by appending columns. A2 replaces that model on desktop with a single expanding tree whose state is one `List<String> path`. The change is driven by: (a) simpler mental model — the tree is always navigable without horizontal scrolling; (b) cleaner deep-link semantics — path derives everything; (c) room to grow — a registry of panel components replaces ad-hoc column resolvers.

Scope decisions confirmed with the user:
- **Coexistence**: Build behind a new `enableSettingsTreeFlag`. Zero dependencies on old code (per CLAUDE.md). Old stack remains default-on; remove it in a follow-up release after the flag flips.
- **MVP coverage**: All 12 existing top-level sections wired up in v1, respecting existing per-section feature flags.
- **Dynamic lists** (Categories, Labels, Habits, Dashboards, Measurables, AI Profiles, Agent Templates/Souls/Instances): each is a **leaf** in the tree; the detail-pane panel embeds the existing list-plus-detail UI. Item ids are panel-local, NOT tree nodes.
- **URL & breakpoint**: Keep Beamer path-based routing (`/settings/sync/backfill`, no URL fragments). Keep the existing 960 dp `kDesktopBreakpoint`.

Desktop-only for v1; mobile keeps the existing `SettingsPage` push-navigation flow.

---

## Architecture Overview

```
lib/features/settings/ui/pages/settings_root_page.dart
          │ (unchanged except: one flag branch)
          ▼
 SettingsV2Page ─────────────────────────────────────
   ├─ Header (title + caption + DesignSystemBreadcrumbs)
   ├─ Row
   │   ├─ SettingsTreeView ──► ref.watch(settingsTreePathProvider)
   │   ├─ SettingsTreeResizeHandle ──► ref.watch(settingsTreeNavWidthProvider)
   │   └─ SettingsDetailPane ──► AnimatedSwitcher(EmptyRoot|CategoryEmpty|LeafPanel)
   └─ _SettingsTreeUrlSync (invisible bridge widget)
        ├─ ValueListenableBuilder ← NavService.desktopSelectedSettingsRoute
        │     → notifier.syncFromUrl(...)          (URL → tree)
        └─ ref.listen(settingsTreePathProvider)
              → Beamer.beamToReplacementNamed(...) (tree → URL)
              guarded by `_programmaticBeam` flag to break the loop
```

Single source of truth for navigation state: `SettingsTreePath` notifier (Riverpod). Beamer URL is derived from `path` via a stateless `SettingsTreeIndex`. Existing `NavService.desktopSelectedSettingsRoute` stays the canonical external signal — no new Beamer location needed.

---

## File Structure (new code)

```
lib/features/settings_v2/
├── README.md                                       # Mermaid diagrams (§9)
├── domain/
│   ├── settings_node.dart                          # SettingsNode, NodeBadge, NodeTone
│   ├── settings_tree_data.dart                     # buildSettingsTree(...) — flag-aware
│   └── settings_tree_index.dart                    # ancestors, findById, path↔URL helpers
├── state/
│   ├── settings_tree_controller.dart               # @Riverpod path notifier + click rules
│   ├── settings_tree_width_controller.dart         # @Riverpod width notifier (persistent)
│   └── settings_tree_data_provider.dart            # @Riverpod tree + index, flag-reactive
└── ui/
    ├── pages/settings_v2_page.dart
    ├── header/
    │   ├── settings_v2_header.dart                 # 56 dp bar
    │   └── settings_v2_breadcrumbs.dart            # adapter → DesignSystemBreadcrumbs
    ├── tree/
    │   ├── settings_tree_view.dart                 # FocusScope + keyboard shortcuts
    │   ├── settings_tree_node_widget.dart          # recursive row + AnimatedSize block
    │   ├── settings_tree_row.dart                  # rail/tile/text/badge/chevron
    │   ├── settings_tree_children_container.dart   # dashed rail, left padding
    │   └── settings_tree_resize_handle.dart        # 6 dp hit, dbl-click + keyboard
    ├── detail/
    │   ├── settings_detail_pane.dart               # AnimatedSwitcher dispatcher
    │   ├── empty_root.dart
    │   ├── category_empty.dart
    │   ├── leaf_panel.dart                         # max-width 720, local header
    │   ├── default_panel.dart
    │   └── panel_registry.dart                     # {panel_id → WidgetBuilder}
    ├── panels/                                     # thin bridges around existing pages
    │   └── *.dart                                  # one per panel id, listed in §4
    └── widgets/
        ├── settings_tree_active_rail.dart
        ├── settings_tree_icon_tile.dart
        └── settings_tree_badge.dart
```

Corresponding test tree: `test/features/settings_v2/...` mirroring source paths (one test per source).

---

## 1 · State Design

### `SettingsTreePath` (`state/settings_tree_controller.dart`)

```dart
@Riverpod(keepAlive: true)
class SettingsTreePath extends _$SettingsTreePath {
  @override
  List<String> build() => const [];

  /// Applies the four click rules from spec §3.
  void onNodeTap(String nodeId, int depth, {required bool hasChildren});

  /// Called by the URL-sync bridge when Beamer's path changes externally.
  void syncFromUrl(String beamPath, Map<String, String> pathParameters);

  /// Used by breadcrumb chips.
  void truncateTo(int depth);
}
```

### `SettingsTreeNavWidth` (`state/settings_tree_width_controller.dart`)

Exact mirror of `PaneWidthController` (`lib/features/design_system/state/pane_width_controller.dart`) including 300 ms debounce and boot-time load — but with its **own** storage key so it cannot collide with the shared `listPaneWidth`:

```dart
const settingsTreeNavWidthKey = 'SETTINGS_TREE_NAV_WIDTH';
const defaultSettingsTreeNavWidth = 340.0;
const minSettingsTreeNavWidth     = 280.0;
const maxSettingsTreeNavWidth     = 480.0;

@Riverpod(keepAlive: true)
class SettingsTreeNavWidth extends _$SettingsTreeNavWidth {
  @override double build();
  void updateBy(double delta);    // drag: clamp + debounce persist
  void setTo(double width);       // keyboard: 8 / 32 dp steps
  void resetToDefault();          // dbl-click / Home key
}
```

### `settingsTreeData` + `settingsTreeIndex` (`state/settings_tree_data_provider.dart`)

```dart
@Riverpod(keepAlive: true)
List<SettingsNode> settingsTreeData(Ref ref) {
  final agents     = ref.watch(configFlagProvider(enableAgentsFlag)).value ?? false;
  final habits     = ref.watch(configFlagProvider(enableHabitsPageFlag)).value ?? false;
  final dashboards = ref.watch(configFlagProvider(enableDashboardsPageFlag)).value ?? false;
  final matrix     = ref.watch(configFlagProvider(enableMatrixFlag)).value ?? false;
  final whatsNew   = ref.watch(configFlagProvider(enableWhatsNewFlag)).value ?? false;
  return buildSettingsTree(
    enableAgents: agents, enableHabits: habits, enableDashboards: dashboards,
    enableMatrix: matrix, enableWhatsNew: whatsNew);
}

@Riverpod(keepAlive: true)
SettingsTreeIndex settingsTreeIndex(Ref ref) =>
    SettingsTreeIndex.build(ref.watch(settingsTreeDataProvider));
```

Feature-flag API verified at `lib/features/settings/ui/pages/settings_page.dart:24-32`. A new constant `enableSettingsTreeFlag` is added to the flag registry and surfaced in `FlagsPage`.

### URL ↔ Path sync mechanics

A small `_SettingsTreeUrlSync` `ConsumerStatefulWidget` mounted invisibly inside `SettingsV2Page`:

- On `NavService.desktopSelectedSettingsRoute` change (`ValueListenableBuilder`): if `!_programmaticBeam`, call `ref.read(settingsTreePathProvider.notifier).syncFromUrl(...)`.
- On `ref.listen(settingsTreePathProvider)`: compute new beam URL via `SettingsTreeIndex.pathToBeamUrl`. If it differs from the current Beamer location, set `_programmaticBeam = true`, call `context.beamToReplacementNamed(newUrl)`, then clear the flag on the next microtask.

This is the only Beamer touch-point — no new `BeamLocation`, no new `pathPatterns`.

---

## 2 · Tree Data (`buildSettingsTree`)

Cross-referenced against `lib/beamer/locations/settings_location.dart:51-94` for URL completeness and `lib/features/settings/ui/pages/settings_page.dart:36-139` for display order. IDs use the spec's slash convention.

| id | title | children? | panel | URL |
|---|---|---|---|---|
| `whats-new` | What's New | — | `whats-new` | (modal today; v2 treats as in-pane panel — no new route) |
| `ai` | AI | ✓ | — | `/settings/ai` |
| `ai/profiles` | Inference Profiles | — | `ai-profiles` | `/settings/ai/profiles` |
| `agents` | Agents | ✓ | — | `/settings/agents` |
| `agents/templates` | Templates | — | `agents-templates` | `/settings/agents/templates/:templateId` |
| `agents/souls` | Souls | — | `agents-souls` | `/settings/agents/souls/:soulId` |
| `agents/instances` | Instances | — | `agents-instances` | `/settings/agents/instances/:agentId` |
| `habits` | Habits | — | `habits` | `/settings/habits` (+ `:habitId`) |
| `categories` | Categories | — | `categories` | `/settings/categories` (+ `:id`) |
| `labels` | Labels | — | `labels` | `/settings/labels` (+ `:id`) |
| `sync` | Sync | ✓ | — | `/settings/sync` |
| `sync/backfill` | Backfill | — | `sync-backfill` | `/settings/sync/backfill` |
| `sync/stats` | Stats | — | `sync-stats` | `/settings/sync/stats` |
| `sync/outbox` | Outbox | — | `sync-outbox` | `/settings/sync/outbox` |
| `sync/matrix-maintenance` | Matrix Maintenance | — | `sync-matrix-maintenance` | `/settings/sync/matrix/maintenance` |
| `dashboards` | Dashboards | — | `dashboards` | `/settings/dashboards` (+ `:id`) |
| `measurables` | Measurables | — | `measurables` | `/settings/measurables` (+ `:id`) |
| `theming` | Theming | — | `theming` | `/settings/theming` |
| `flags` | Feature Flags | — | `flags` | `/settings/flags` |
| `advanced` | Advanced | ✓ | — | `/settings/advanced` |
| `advanced/logging` | Logging | — | `advanced-logging` | `/settings/advanced/logging_domains` |
| `advanced/conflicts` | Conflicts | — | `advanced-conflicts` | `/settings/advanced/conflicts` (+ `:id`) |
| `advanced/maintenance` | Maintenance | — | `advanced-maintenance` | `/settings/advanced/maintenance` (see note below) |
| `advanced/about` | About | — | `advanced-about` | `/settings/advanced/about` |

Explicitly **excluded** from v1: `/settings/projects/...` (projects live in the primary sidebar, not Settings), `/settings/health_import` (mobile-only, not in desktop `settings_page.dart`), `*/create` modal variants (handled inside their panels).

**Pre-requisite cleanup — `/settings/advanced/maintenance` consistency**: the live codebase already uses `/settings/advanced/maintenance` everywhere that matters (`advanced_settings_page.dart:38` navigates to it; `settings_column_stack.dart:555` and `settings_location.dart:488` both match on `advanced/maintenance`). The sole anomaly is the stale `pathPatterns` entry at `lib/beamer/locations/settings_location.dart:93` which still declares `/settings/maintenance`. Fix that in PR 1 alongside `test/beamer/locations/settings_location_test.dart:141`:
- Change the pattern to `/settings/advanced/maintenance`.
- Drop `/settings/maintenance` entirely — grep shows no callers outside those two test/location lines.
- Update the tree-node URL table above accordingly.
This is a single-line fix that removes a lurking mismatch and lets the v2 tree point at the canonical URL without alias plumbing.

`SettingsTreeIndex.beamUrlToPath` is a greedy longest-prefix match against the flat set of known node ids; unknown segments (UUIDs like a category id) are treated as panel-local and don't mutate the tree path.

---

## 3 · Tree-Row Widget

Uses `context.designTokens` — no hard-coded colors, radii, spacing, or type styles.

- **Anatomy** (left → right): `SettingsTreeActiveRail` (3 dp, `AnimatedOpacity` 200 ms), `SettingsTreeIconTile` (36×36, `radii.s`, glyph via `IconData`), title + desc column (`typography.styles.subtitle.subtitle2` + `typography.styles.others.caption`), optional `SettingsTreeBadge` (info / teal / error tone), chevron (`RotationTransition` 0 → ¼ turn, 220 ms `Cubic(0.2, 0, 0, 1)`).
- **State**: hover tracked via `MouseRegion` + local `setState`; dim / open / selected derived from a single `ref.watch(settingsTreePathProvider)`. Dim = `AnimatedOpacity` to 0.42 wrapped in `Transform.scale(0.995)` over 220 ms `Curves.ease`.
- **Children container**: `AnimatedSize(duration: 260 ms, curve: Curves.easeOutExpo)` + `AnimatedOpacity` per spec §7.
- **Keyboard**: tree-level `FocusScope` + `Shortcuts`/`Actions` mapping ↑↓←→ / Enter / Space to intents that mutate either focus (visible-flat-list of rows) or path state per spec §3 keyboard rules.
- **Semantics**: `Semantics(button: true, selected: onActivePath, expanded: hasChildren ? isOpen : null, label: '${title}, level ${depth + 1}')`.
- **Reduced motion**: `MediaQuery.of(context).disableAnimations` replaces animated widgets with their instant variants.

---

## 4 · Resize Handle

`SettingsTreeResizeHandle` — new widget (the existing `ResizableDivider` at `lib/features/design_system/components/navigation/resizable_divider.dart` doesn't support dbl-click reset or keyboard focus, and the visual spec differs: 2 dp bar in `interactive.enabled @ 40 %` on hover, 100 % on drag).

- 6 dp wide hit target, `MouseRegion(cursor: SystemMouseCursors.resizeColumn)`, bar centered on the column's right divider.
- Drag: `onHorizontalDragUpdate` mutates a local `ValueNotifier<double>` consumed by a `ValueListenableBuilder` around the tree's sizing `SizedBox` (so the tree contents don't rebuild per frame). On `onHorizontalDragEnd`, flush the final value to `settingsTreeNavWidthProvider.notifier.setTo(...)`.
- Double-click → `resetToDefault()`. Arrow keys: ±8 dp; Shift+Arrow: ±32 dp; Home → reset.
- Below `kDesktopBreakpoint` (960 dp): `SettingsV2Page` short-circuits to the mobile `SettingsPage` entirely, so the handle never renders.

---

## 5 · Detail Pane & Panel Registry

```dart
// settings_detail_pane.dart
final focused = path.isEmpty ? null : index.findById(path.last);
final child = focused == null
    ? const EmptyRoot()
    : focused.children != null
        ? CategoryEmpty(node: focused)
        : LeafPanel(node: focused);
return AnimatedSwitcher(
  duration: const Duration(milliseconds: 180),
  transitionBuilder: (c, a) => FadeTransition(opacity: a, child: c),
  child: KeyedSubtree(key: ValueKey(focused?.id ?? 'empty'), child: child),
);
```

`LeafPanel` wrapper: `ConstrainedBox(minWidth: 560, maxWidth: 720)` → column of (1) small local breadcrumbs from `SettingsTreeIndex.ancestors`, (2) `Heading 3` title, (3) optional actions row, (4) `spacing.step6` gap, (5) panel from `kSettingsPanels[node.panel]` or `DefaultPanel`.

**Panel registry**: a `Map<String, WidgetBuilder>` with entries for every `panel` id above — `flags`, `theming`, `sync-backfill`, `sync-stats`, `sync-outbox`, `sync-matrix-maintenance`, `advanced-logging`, `advanced-about`, `advanced-maintenance`, `advanced-conflicts`, `categories`, `labels`, `habits`, `dashboards`, `measurables`, `ai`, `ai-profiles`, `agents`, `agents-templates`, `agents-souls`, `agents-instances`, `whats-new`. Unknown ids → `DefaultPanel` (icon + desc + "Open {title}" CTA).

**Bridge pattern for embedding existing pages**: current pages wrap themselves in `SliverBoxAdapterPage` (a full Scaffold). The v2 panel can't nest that. For each target, extract a body widget (e.g. `BackfillSettingsBody`) from the existing page file. The mobile `BackfillSettingsPage` keeps working as a thin Scaffold wrapper around the extracted body. The v2 `SyncBackfillPanel` imports and renders `BackfillSettingsBody` directly. Same pattern for Flags, Theming, Advanced/*, Sync/*.

**Dynamic lists** (Categories, Labels, Habits, …): panel composes the existing list widget + inline detail. Item selection still calls `context.beamToNamed('/settings/categories/$id')` — `syncFromUrl` treats the UUID as panel-local and leaves `path = ['categories']` unchanged. No tree re-mount on item swap.

**Special cases**:
- `AgentSettingsPage` uses its own tabs and adds bottom-nav padding. Introduce an `embedded: true` constructor flag on it (and any similar pages) to skip the bottom-nav offset when hosted inside `LeafPanel`.
- `SettingsV2Page` wraps the whole area in a `Scaffold` so `ScaffoldMessenger.of(context)` calls from embedded bodies still work.

---

## 6 · Beamer Integration

**Flag branch at the only entry point**:

```dart
// lib/features/settings/ui/pages/settings_root_page.dart
if (!isDesktopLayout(context)) return const SettingsPage();
final enableV2 = ref.watch(configFlagProvider(enableSettingsTreeFlag)).value ?? false;
if (enableV2) return const SettingsV2Page();
// ...existing legacy body unchanged...
```

No new route patterns, no changes to `SettingsLocation`. Both v1 and v2 read the same `desktopSelectedSettingsRoute` ValueNotifier (`lib/services/nav_service.dart`); v2 writes back via `context.beamToReplacementNamed` through the `_SettingsTreeUrlSync` bridge described in §1.

Deep-link test: loading `/settings/sync/backfill` with the flag on seeds tree `path = ['sync', 'sync/backfill']` and renders `SyncBackfillPanel` in the detail pane.

---

## 7 · Test Plan

All tests use `makeTestableWidget` / `setUpTestGetIt` / `tearDownTestGetIt` from `test/widget_test_utils.dart`, and centralized mocks from `test/mocks/mocks.dart`. One test file per source file.

**Unit** (`test/features/settings_v2/domain/`, `state/`):
- `settings_tree_index_test.dart`: round-trip every URL in `settings_location.dart:51-94` through `beamUrlToPath` → `pathToBeamUrl`. Unknown segments (uuids). `ancestors` correctness.
- `settings_tree_data_test.dart`: flag-off variants hide the right nodes; stable IDs.
- `settings_tree_controller_test.dart`: the four click rules; `truncateTo`; `syncFromUrl` idempotence.
- `settings_tree_width_controller_test.dart`: clamp, debounce, persist (mirror `pane_width_controller_test.dart`).

**Widget** (`test/features/settings_v2/ui/`):
- `settings_tree_row_test.dart`: hover, active-path rail, dim 42 %, reduced-motion path.
- `settings_tree_view_test.dart`: keyboard arrow traversal, enter activation, visible-flat-list derivation.
- `settings_tree_resize_handle_test.dart`: drag, dbl-click, ±8 / ±32 dp keyboard steps, Home reset.
- `settings_detail_pane_test.dart`: empty / branch / leaf dispatch; fade cross-switch.
- `leaf_panel_test.dart`: crumbs from ancestors; 720 dp max; registry hit; unknown id → DefaultPanel.
- `settings_v2_header_test.dart`: breadcrumb click calls `truncateTo(depth)`; hairline present.
- `settings_v2_page_test.dart`: URL `/settings/sync/backfill` → tree path; tree click → single `beamToReplacementNamed` call (no loop).

**Theme**: `settings_tree_row_theme_test.dart` — render under `dsTokensLight` and `dsTokensDark`, assert rendered colors equal expected tokens (no hard-coded colors leak).

**Accessibility**: `tester.getSemantics` assertions for `button`, `selected`, `expanded`, and label; `disableAnimations: true` path.

---

## 8 · Critical Files

**To modify** (one branch point only):
- `lib/features/settings/ui/pages/settings_root_page.dart` — add flag branch returning `SettingsV2Page`.
- `lib/utils/consts.dart` (or wherever flag constants live — verify) — add `enableSettingsTreeFlag`.
- Each target embedded page (e.g. `lib/features/sync/ui/backfill_settings_page.dart`, `lib/features/settings/ui/pages/flags_page.dart`, …) — extract body widget, keep old page as thin wrapper.

**To reference (read-only)**:
- `docs/design/settings/design_spec.md` — spec.
- `lib/beamer/locations/settings_location.dart:51-94` — canonical URL patterns to mirror in `SettingsTreeIndex`.
- `lib/services/nav_service.dart` — `desktopSelectedSettingsRoute` ValueNotifier.
- `lib/features/design_system/state/pane_width_controller.dart` — template for `SettingsTreeNavWidth`.
- `lib/features/design_system/components/breadcrumbs/design_system_breadcrumbs.dart` — reuse for the header.
- `lib/features/design_system/components/navigation/resizable_divider.dart` — reference pattern (not reused verbatim).
- `lib/features/design_system/theme/design_tokens.dart` — `context.designTokens` extension.

---

## 9 · CHANGELOG & README

- Add entry under the **current `pubspec.yaml` version** (not `[Unreleased]`): `### Added — Settings V2: tree-nav + detail-pane settings surface behind the enable_settings_tree flag (desktop only).`
- Update `flatpak/com.matthiasn.lotti.metainfo.xml` alongside the CHANGELOG.
- Create `lib/features/settings_v2/README.md` with three Mermaid diagrams:
  1. `stateDiagram-v2` for tree-path invariants (click rules).
  2. `sequenceDiagram` for URL ↔ tree sync including the `_programmaticBeam` guard.
  3. Flowchart for panel resolution (`EmptyRoot` → `CategoryEmpty` → `LeafPanel` → registry hit / `DefaultPanel`).

---

## 10 · Risk Register

| # | Risk | Mitigation |
|---|---|---|
| 1 | Beamer ↔ notifier feedback loop (tree click fires URL change which fires `syncFromUrl`). | `_programmaticBeam` guard flag on `_SettingsTreeUrlSync`, plus early-return when the candidate URL equals the current one. Covered by `settings_v2_page_test.dart`. |
| 2 | Embedded pages assume a `Scaffold` ancestor (snackbars, `ScaffoldMessenger`). | `SettingsV2Page` wraps the whole area in a `Scaffold`. Body-extraction preserves the scaffold API for the mobile wrapper. |
| 3 | `AgentSettingsPage` carries its own tabs and bottom-nav padding; embedding leaves dead space. | Add an `embedded: true` flag on the page that drops the bottom-nav offset — cleaner than masking. |
| 4 | Dynamic-list panels' `beamToNamed` for item selection races with our `beamToReplacementNamed`. | `SettingsTreeIndex.beamUrlToPath` treats unknown segments as panel-local; the tree path is unchanged by item-id swaps. Round-trip tests cover `/settings/categories/<uuid>`. |
| 5 | Users dragged the shared `listPaneWidth` and expect that setting to apply to v2. | Deliberately independent keys. Documented in README. Migrate key in a future PR if UX feedback demands it. |

---

## 11 · Implementation Order

Suggested incremental PR sequence. Each PR must ship analyzer-green, all tests passing, with tests for the newly added code.

1. **Foundations**: `SettingsNode`, tree data, `SettingsTreeIndex`, `enableSettingsTreeFlag` registered in the flags registry + surfaced in `FlagsPage`. Unit tests for the index. No UI.
2. **State**: `SettingsTreePath` + `SettingsTreeNavWidth` notifiers with tests. Still no UI wiring.
3. **Chrome**: `SettingsV2Page` scaffold (header + empty tree + empty detail), resize handle wired to the width provider, flag branch added to `SettingsRootPage`. Legacy still default.
4. **Tree UI**: row anatomy widgets, animations, keyboard traversal, semantics.
5. **Detail core**: `SettingsDetailPane`, `EmptyRoot`, `CategoryEmpty`, `LeafPanel` wrapper, `DefaultPanel`, registry scaffolding.
6. **URL sync**: `_SettingsTreeUrlSync` bridge + integration tests.
7. **Leaf panels, batch 1** (simple): `flags`, `theming`, `advanced-about`, `advanced-maintenance`, `advanced-logging`, `sync-backfill`, `sync-stats`, `sync-outbox`, `sync-matrix-maintenance`. Body-extract each.
8. **Leaf panels, batch 2** (dynamic lists): `categories`, `labels`, `habits`, `dashboards`, `measurables`, `advanced-conflicts`.
9. **AI + Agents**: `ai`, `ai-profiles`, `agents`, `agents-templates`, `agents-souls`, `agents-instances` (heaviest embedding work; may need the `embedded: true` flag on `AgentSettingsPage`).
10. **Polish**: `whats-new` panel, reduced-motion sweep, light/dark token regression tests, CHANGELOG + README with Mermaid diagrams.

After the flag has been default-on for a full release cycle with no regressions, a cleanup PR removes the legacy branch in `settings_root_page.dart`, `settings_column_stack.dart`, `_resolve*` helpers, and the flag itself.

---

## 12 · Verification (end-to-end)

For each PR:
- `dart-mcp.analyze_files` green on the whole project.
- `fvm dart format .` run.
- `dart-mcp.run_tests` green on the new/changed test files; full suite green before PR merge.

Manual desktop smoke test (after PRs 3 + 6):
- Launch with flag on.
- Window ≥ 960 dp → see tree + detail pane; header shows "Settings" + caption.
- Click `Sync` → row opens, children animate in, breadcrumbs show `Sync`.
- Click `Sync ▸ Backfill` → Backfill panel renders; URL becomes `/settings/sync/backfill`.
- Reload the window at that URL → tree auto-expands Sync + selects Backfill.
- Drag the handle → tree width changes fluidly, persists across reload.
- Shrink window below 960 dp → mobile `SettingsPage` takes over cleanly.
- Toggle reduced motion in OS settings → expand/collapse is instant, dim transitions off.
- Toggle light/dark → no hard-coded colors leak.
