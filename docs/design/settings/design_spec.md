# Settings · A2 — Tree-nav + Detail Pane

**Handoff spec for a Flutter coding agent.** Two-column settings surface: left column is a pure-navigation expanding tree; right column shows the detail for whatever leaf is currently selected. No modal/drill-down, no third column, no inline leaf panels.

Token references in this doc point at the Lotti design system (`tokens.json`). Every color, size, spacing, radius, and type style below is an existing token — don't hard-code values. Where a CSS-ish idea is mentioned (e.g. "grid-template-rows"), treat it as conceptual; the actual implementation is Flutter widgets (`AnimatedSize`, `AnimatedContainer`, `ExpansionTile`-style custom widget, etc.).

---

## 1 · Frame

```
┌────────────── App window ──────────────┐
│ Product sidebar │ Settings page        │
│ (global nav)    │ ┌── Header ────────┐ │
│                 │ │ Title+breadcrumbs│ │
│                 │ ├───────┬──────────┤ │
│                 │ │ Tree  │ Detail   │ │
│                 │ │ nav   │ pane     │ │
│                 │ │       │          │ │
│                 │ └───────┴──────────┘ │
└────────────────────────────────────────┘
```

- **Product sidebar** (global): unchanged from the rest of Lotti — Tasks / Projects / DailyOS / Insights / Logbook / Settings.
- **Settings page** fills the remaining viewport and splits into three stacked regions:
  1. Page header (fixed height, **56 dp**)
  2. Body, split horizontally into **tree nav** (left) and **detail pane** (right)
- Minimum content width for this layout: **1040 dp** (sidebar + page). Below that, collapse the product sidebar to icons, or push the tree-nav into a drawer (out of scope for v1 — desktop only).

---

## 2 · Page header

Single row, anchored above both columns.

| Element            | Token / value                                                                 |
|--------------------|-------------------------------------------------------------------------------|
| Container height   | **56 dp**                                                                     |
| Horizontal padding | `spacing.6` (24)                                                              |
| Title              | `typography.Heading 3` — "Settings"                                           |
| Caption (right of title) | `typography.Body Small`, `text.medium-emphasis` — e.g. "Your private agentic swarm, tuned to your rhythms." |
| Breadcrumb row     | `typography.Caption`; last crumb `text.high-emphasis` + semibold, earlier crumbs `text.medium-emphasis` |
| Separator dot      | U+203A `›`, `text.low-emphasis`                                               |
| Bottom divider     | 1 dp line, `decorative.01`                                                    |

Breadcrumbs reflect the **current selection path**, not hover state. Each crumb is a button; tapping it truncates `path` to that depth.

---

## 3 · Tree nav (left column)

### Dimensions

| Property                  | Token / value                        |
|---------------------------|--------------------------------------|
| Width                     | **User-resizable**, default **340 dp**, min **280 dp**, max **480 dp**. Persisted — see §3.1. |
| Scroll                    | Vertical only; scrollbar hidden until hover |
| Right divider             | 1 dp, `decorative.01`                |
| Padding                   | `spacing.4` (12) left/right, `spacing.5` (16) top, `spacing.7` (32) bottom |

### Node model

```dart
class SettingsNode {
  final String id;           // unique, slash path OK: 'sync/backfill'
  final IconAsset icon;      // name from the house icon set
  final String title;
  final String desc;         // one-line description, shown under title
  final List<SettingsNode>? children;
  final NodeBadge? badge;    // {label, tone: info|teal|error}
  final String? panel;       // which detail component to render (leaves only)
}
```

### Single state: `List<String> path`

`path` is an ordered list of node ids from root → current focus.

- `[]` — nothing selected; tree shows all top-level items, detail pane shows empty state.
- `['sync']` — Sync Settings expanded, children visible. Detail pane shows `CategoryEmpty` (because `sync` has children).
- `['sync', 'sync/backfill']` — Sync Settings expanded **and** Backfill sync selected. Detail pane shows Backfill panel.

**Invariant:** at any given depth, at most one node is open. Opening a sibling closes the current open node and everything below.

### 3.1 · Resize handle

Matches the existing pattern used by the Tasks and Projects lists — the left column is draggable, width persists per-surface.

- **Hit target:** 6 dp wide, full column height, overlapping the right divider (right-divider sits at column edge; handle is centered on it).
- **Cursor:** `SystemMouseCursors.resizeColumn` on hover.
- **Visual:**
  - Idle: handle invisible; the 1 dp `decorative.01` divider is the only thing the user sees.
  - Hover (150 ms ease): a 2 dp vertical bar fades in on the divider line, color `interactive.enabled` at 40 %.
  - Dragging: bar solidifies to `interactive.enabled` at 100 %, full height.
- **Drag behavior:**
  - `MouseRegion` + `GestureDetector` with `onHorizontalDrag*` callbacks.
  - Update a local `double width` on every delta, clamped to `[280, 480]`.
  - Do **not** rebuild the tree on every frame — wrap only the sizing `SizedBox`/`Container` in the listenable, or use a `ValueListenableBuilder`.
- **Double-click the handle:** reset to default (**340 dp**).
- **Persistence:** write width to app-level settings storage under key `settings.treeNav.width` (distinct from the Tasks/Projects keys — each surface persists its own width). Debounce writes 300 ms; read once on page mount.
- **Keyboard:** when the handle has focus (Tab-reachable), `← / →` adjust width in **8 dp** steps; `Shift+← / Shift+→` in **32 dp** steps; `Home` resets to default.
- **Reduced motion:** no fade on hover; show the 2 dp bar instantly.
- **Below minimum window width (1040 dp):** freeze resize — clamp to 280 dp and hide the handle until the window grows again.

### Row anatomy

| Property               | Token / value                                                                 |
|------------------------|-------------------------------------------------------------------------------|
| Row height             | **62 dp** (fixed)                                                             |
| Padding                | top/bottom `spacing.5` (16), left `spacing.5` (16), right `spacing.5` (16). Additional 4 dp inset on the left for the active rail. |
| Corner radius          | `borderRadius.m` (12)                                                         |
| Internal gap           | `spacing.4` (12) between icon / text-stack / chevron                           |

Children of a row, left → right:

1. **Active rail** — 3 dp wide, color `interactive.enabled`, vertical inset `spacing.4` (12) top/bottom. Positioned absolutely at the row's left edge. Visible only when `path.contains(node.id)`.
2. **Icon tile** — **36 × 36 dp**, radius `borderRadius.s` (8) — or `10` if you want a slightly softer corner; this is the only value *not* an exact token, so round to `borderRadius.s` (8). Icon glyph 20 dp.
  - On active path: background `surface.selected`, glyph color `interactive.enabled`.
  - Otherwise: background `surface.enabled`, glyph color `text.medium-emphasis`.
3. **Title + description** column. Min-width 0 (let it shrink), both truncate with ellipsis.
  - Title: `typography.Subtitle 2` (14 / 20, SemiBold, +0.25 tracking), color `text.high-emphasis`.
  - Desc: `typography.Caption` (12 / 16, Regular, +0.25 tracking), color `text.medium-emphasis`.
4. **Optional badge** — pill, height 18 dp, horizontal padding `spacing.3` (8), radius `borderRadius.xl` (24). Label `typography.Overline` at 10 dp (smallest case; or use Caption at 11 dp if your type stack doesn't do 10). Tone map:
  - `info` → background `alert.info.default` at 16%, text `alert.info.default`.
  - `teal` → background `surface.selected`, text `interactive.enabled`.
  - `error` → background `alert.error.default` at 16%, text `alert.error.default`.
5. **Chevron** — 18 dp, color `text.low-emphasis`. Rotates 90° clockwise (pointing down) when the row is open. 220 ms, standard-ease (see §7).

### Row states

| State                                                     | Background            | Notes                                                       |
|-----------------------------------------------------------|-----------------------|-------------------------------------------------------------|
| Default                                                   | transparent           | —                                                           |
| Hover (no sibling open at this depth)                     | `surface.hover`       | —                                                           |
| Open (has children, on active path)                       | `surface.enabled`     | Chevron rotated, icon tile uses selected styling, rail visible |
| Dim — a sibling at this depth is open                     | transparent           | Opacity 42 %, scale 0.995. Transition 220 ms. Dims only this level's non-active siblings; ancestors stay full opacity. |
| Selected leaf                                             | `surface.enabled`     | Same as "open" but no expansion; rail visible               |

### Children container (when a row is open)

Animates open/close:

- Flutter: use `AnimatedSize` + `AnimatedOpacity`, or a custom `ClipRect` + `SizeTransition`.
- Duration **260 ms**, curve **`Curves.easeOutExpo`** (design-system "standard" motion).
- Simultaneous opacity 0 → 1 over the same 260 ms.

Inner layout:

| Property     | Token / value                                   |
|--------------|-------------------------------------------------|
| Left padding | `spacing.6` (24)                                |
| Left margin  | `spacing.6` (24) — aligns rail under parent's icon column |
| Top margin   | `spacing.3` (8) — half-step; use 6 dp if you want exact prototype feel |
| Bottom margin| `spacing.3` (8)                                 |
| Left rail    | 1.5 dp **dashed** line, color `interactive.enabled` at 28 % opacity |

Rows recurse: each child is the same tree-row widget at the next depth.

### Click rules

Priority order:

1. Row is **on active path AND has children** (currently open) → collapse. `path = path.sublist(0, depth)`.
2. Row is **off-path AND has children** → open, replacing everything at this depth and below. `path = [...path.sublist(0, depth), node.id]`.
3. Row is a **leaf** → select. `path = [...path.sublist(0, depth), node.id]`. Detail pane reacts.
4. Tapping an already-selected leaf → no-op (don't deselect).

### Keyboard (v1 nice-to-have)

- `↑ / ↓`: move visual focus through the visible flat list of rows (skip hidden collapsed children).
- `→`: if focused row has children and is closed, open it. If already open, move focus to its first child.
- `←`: if focused row is open, close it. If already closed, move focus to its parent row.
- `Enter / Space`: trigger the row's click behavior.

---

## 4 · Detail pane (right column)

### Dimensions

| Property         | Token / value                                          |
|------------------|--------------------------------------------------------|
| Width            | Expanded (fills remaining width)                       |
| Scroll           | Vertical                                               |
| Padding          | top `spacing.5` (16), right `spacing.6` (24), bottom `spacing.7` (32), left `spacing.6` (24) |

### What it shows

Drive off the **last id in `path`**:

```dart
final focused = path.isEmpty ? null : tree.findById(path.last);

if (focused == null)              return const EmptyRoot();
else if (focused.children != null) return CategoryEmpty(node: focused);
else                               return LeafPanel(node: focused);
```

### `EmptyRoot`

Centered, muted.

- **56 × 56** rounded icon tile (radius `borderRadius.m` = 12), background `surface.enabled`, gear glyph 24 dp in `text.medium-emphasis`.
- Headline `typography.Heading 3` / `text.high-emphasis`: "Settings".
- Sub `typography.Body Medium` / `text.medium-emphasis`: "Pick a section on the left to begin."
- Stack gap `spacing.4` (12).

### `CategoryEmpty`

Shown when the selected node has children (user tapped a branch but hasn't yet picked a leaf).

- 56 × 56 icon tile using `node.icon`, same radius/background as EmptyRoot.
- Title (`typography.Heading 3`, `text.high-emphasis`) from `node.title`.
- Desc (`typography.Body Medium`, `text.medium-emphasis`) from `node.desc`.
- Helper line (`typography.Caption`, `text.low-emphasis`): "Pick a sub-setting on the left."

### `LeafPanel`

Wrapper + the concrete component keyed by `node.panel`. Wrapper responsibilities:

- Constrain inner content to **max-width 720 dp** (min 560 dp feels right on wide monitors) and center it so long panels don't stretch on ultrawide displays.
- Render a compact local header: small crumbs line (`typography.Caption`), title (`typography.Heading 3`), then actions row if any. Header → body gap `spacing.6` (24).
- Below that, render the registered panel component.

### Panel registry

```dart
final Map<String, WidgetBuilder> panels = {
  'default':         (_) => const DefaultPanel(),
  'backfill':        (_) => const BackfillPanel(),
  'agents-stats':    (_) => const AgentsStatsPanel(),
  'flags':           (_) => const FlagsPanel(),
  'maintenance':     (_) => const MaintenancePanel(),
  // …add more as real panels land
};
```

Leaves missing a `panel` fall back to `DefaultPanel` (icon + desc + "Open {title}" CTA).

---

## 5 · State & URL

- Single source of truth: `List<String> path` held in app state (Riverpod / Bloc / whatever the app already uses).
- **Derive** open rows, breadcrumbs, and detail-pane content from `path`. Do **not** keep per-row open/closed booleans — they drift.
- Persist `path` to the deep-link URL for desktop-window routing (`lotti://settings#/sync/backfill`). On load, parse the fragment into `path`. On any path change, replace the URL silently.

---

## 6 · Data

Ship the settings tree as a single declarative list (see `SETTINGS_TREE` in the prototype source). List order = display order. Every node needs `id`, `icon`, `title`, `desc`. Optional: `children`, `panel`, `badge`.

Build an index once at boot for O(1) breadcrumb + panel lookup:

```dart
final Map<String, List<SettingsNode>> treeIndex = {};

void indexTree(List<SettingsNode> nodes, [List<SettingsNode> parents = const []]) {
  for (final n in nodes) {
    final p = [...parents, n];
    treeIndex[n.id] = p;
    if (n.children != null) indexTree(n.children!, p);
  }
}
```

---

## 7 · Motion spec

All durations below use the design system's "standard" curve — `Curves.easeOutExpo` in Flutter, or equivalently `Cubic(0.2, 0, 0, 1)`. Shorter UI feedback animations (hover, background swaps) can fall back to `Curves.ease`.

| Thing                         | Duration | Curve                                    |
|-------------------------------|----------|------------------------------------------|
| Row hover background          | 180 ms   | `Curves.ease`                            |
| Row open/close background     | 200 ms   | `Curves.ease`                            |
| Siblings dim in/out           | 220 ms   | `Curves.ease`                            |
| Chevron rotate                | 220 ms   | `Cubic(0.2, 0, 0, 1)`                    |
| Child container open/close    | 260 ms   | `Cubic(0.2, 0, 0, 1)`                    |
| Detail pane swap              | 180 ms   | `Curves.ease` — simple fade / cross-fade |

Respect `MediaQuery.of(context).disableAnimations` (equivalent of `prefers-reduced-motion: reduce`) — skip collapse animation, just show/hide instantly. Same for dim transitions.

---

## 8 · Tokens (from `tokens.json`)

Only the tokens this surface uses. Names match the JSON keys — resolve at build time into your `Tokens` / `AppColors` / `AppTextStyles` Dart class.

### Colors

| Token                         | Purpose                                                    |
|-------------------------------|------------------------------------------------------------|
| `background.01`               | Page background (settings area)                            |
| `background.02`               | Card surfaces (panels inside the detail pane)              |
| `background.03`               | Hover-raised card surface                                  |
| `surface.enabled`             | Icon-tile default background, open-row background         |
| `surface.hover`               | Row hover background                                       |
| `surface.selected`            | Icon-tile background when on active path                   |
| `text.high-emphasis`          | Titles, primary text                                       |
| `text.medium-emphasis`        | Descriptions, secondary text                               |
| `text.low-emphasis`           | Breadcrumb separators, disabled glyphs, chevron            |
| `interactive.enabled`         | Teal accent: active rail, active icon glyph, primary button |
| `interactive.hover`           | Primary-button hover                                        |
| `interactive.pressed`         | Primary-button pressed                                      |
| `text.on-interactive-alert`   | Text color on teal / on alert backgrounds                   |
| `alert.error.default`         | Destructive actions, error badges/dots                      |
| `alert.warning.default`       | Warnings, "Retry" action color                              |
| `alert.info.default`          | Info badges (e.g. "v2.4")                                   |
| `decorative.01`               | Hairline dividers (header bottom, tree-right)               |

Colors resolve per mode (Light / Dark) automatically.

### Typography

| Style              | Use                                   |
|--------------------|---------------------------------------|
| `Heading 3`        | Page title, leaf title, EmptyRoot title |
| `Subtitle 2`       | Tree-row title                        |
| `Body Medium`      | Detail-pane body, empty-state subcopy |
| `Body Small`       | Header caption                        |
| `Caption`          | Tree-row desc, breadcrumb, helper text |
| `Overline`         | Badge label                           |

### Spacing steps (from `spacing.steps`)

| Step     | Value | Used for                                                  |
|----------|-------|-----------------------------------------------------------|
| `1` / `2`| 2 / 4 | Rail insets, hairline offsets                             |
| `3`      | 8     | Badge inner padding, mini-gaps                             |
| `4`      | 12    | Row internal gap, header-to-body spacing in EmptyRoot      |
| `5`      | 16    | Row padding, tree top padding, detail-pane top padding     |
| `6`      | 24    | Page header padding, child-container left offset, detail-pane horizontal padding |
| `7`      | 32    | Detail-pane bottom padding, tree bottom padding            |

### Radii (from `borderRadius.tokens`)

| Token | Value | Used for                                   |
|-------|-------|--------------------------------------------|
| `s`   | 8     | Icon tile                                  |
| `m`   | 12    | Tree row, EmptyRoot icon tile              |
| `l`   | 16    | Detail-pane section cards (reuse existing) |
| `xl`  | 24    | Badge pill                                 |

All panel internals reuse existing Lotti components (Toggle, segmented control, inline buttons) — A2 does not introduce new primitives.

---

## 9 · Accessibility

- Each tree row is a `Semantics` widget with `button: true`, `selected: onActivePath`, and an `ExpandedState` when it has children (use `expanded: true/false`).
- Expose `aria-level`-equivalent via `Semantics(hint: 'level $depth')` or a custom `SemanticsAction` — Flutter's `SemanticsProperties` doesn't have a direct `level` but TalkBack/VoiceOver will announce context from structure.
- The tree container has `Focus` scope; rows are `FocusNode`s managed internally. `Tab` enters the tree once, then arrow keys navigate.
- Detail pane wrapped in `Semantics(liveRegion: true)` so screen readers announce the context switch.
- Contrast: every text/background pair above already passes AA in both modes — verified against `tokens.json`.

---

## 10 · What NOT to do

- Don't slide the detail pane on swap. Fade only.
- Don't expand more than one sibling per depth.
- Don't re-introduce a third column (that's option B, Miller).
- Don't render leaf panels inline inside the tree (option A1).
- Don't drop breadcrumbs — they're the only way to navigate "up one level" without scrolling.
- Don't persist per-row open/closed state. Derive from `path`.
- Don't invent new color / spacing / radius values. If you need one not in `tokens.json`, raise it with design before shipping.

---

## 11 · Test checklist

- [ ] Loading `lotti://settings#/sync/backfill` on a fresh session expands Sync Settings and selects Backfill, with the detail pane rendering Backfill's panel.
- [ ] Tapping an open branch collapses it; URL updates to the parent path.
- [ ] Selecting a sibling of the currently-open branch closes the old branch with animation and opens the new one.
- [ ] Opening a branch whose parent wasn't open still works (direct deep-link): parent opens too.
- [ ] Detail pane correctly falls back to `DefaultPanel` for any leaf without a registered panel.
- [ ] Keyboard: `↑ ↓ ← → Enter` all behave as spec'd (§3 keyboard).
- [ ] Reduced motion disables the collapse animation.
- [ ] Resizing the window down to 1040 dp doesn't break the layout (no horizontal scroll).
- [ ] Screen reader traverses the tree as one widget, announces expanded state and selection.
- [ ] Light / Dark mode both resolve correctly — no hard-coded colors.

---

## 12 · Scope handled elsewhere

- The actual **content** of leaf panels (Backfill, Flags, Maintenance, Agents Stats, etc.) already exists in the Lotti codebase — reuse the existing widgets. A2 defines only the shell + tree behavior; it does not re-spec panel internals.
- Mobile behavior (drawer tree, full-screen detail) is a separate spec — not in A2.
- The "settings landing" with nothing selected (currently `EmptyRoot`) can be upgraded later into a proper dashboard — that's option C (Hub) — out of scope here.
