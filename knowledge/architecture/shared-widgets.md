---
type: Architecture
title: Shared widgets
description: "The widgets that belong to no single feature — app-bar chrome, modal presentation, selection primitives and settings scaffolding."
resource: ../../lib/widgets
tags: [widgets, shared, modals, selection]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:45:00Z }
stale_after: 2027-01-31
sources:
  - id: src
    resource: ../../lib/widgets
    title: Shared widgets source
    last_modified: 2026-07-25
---

`lib/widgets/` holds the reusable widgets that belong to no single feature.
Anything with a token-backed visual identity lives in
[the design system](../features/design_system/) instead; what remains here is
composition and app-shell chrome.

# What lives here

| Group | Contents |
|-------|----------|
| `app_bar/` | Back and glass action buttons, the sliver settings header, title bars |
| `modal/` | `ModalUtils` over `wolt_modal_sheet`, the confirmation modal, and small list/card animation widgets |
| `selection/` | Reusable selection-modal primitives and the unified toggle family |
| `settings/` | The settings page grid and detail scaffold every editor sits on |
| `picker/` | `EntityPickerSheet`, shared by categories and labels |
| `nav_bar/` | The bottom navigation shell and its FAB clearance wrapper |
| `misc/` | The sidebar activity summary and similar cross-feature pieces |

**Buttons are not here.** They all come from `DesignSystemButton` and its
relatives.

# Modal presentation is centralized

`ModalUtils` is the **only public export** of `lib/widgets/modal/`, and it is how
every adaptive sheet in the app is presented: a draggable bottom sheet on narrow
layouts, a centred dialog on wide ones, from one call.

Centralizing it is what makes the responsive contract consistent — a feature that
built its own sheet would have to re-derive the breakpoint, the insets, the barrier
behaviour and the glass footer treatment, and would drift.

The same helper backs the single-page pickers, the multi-page settings flows, and
the Daily OS planning modal's side-panel variant.

# Selection primitives exist to stop duplication

The selection widgets were extracted because several modals — AI modality
selection, the Gemini thinking-mode picker, and others — had each grown their own
option row with slightly different padding, selection markers and semantics.

They now share one option anatomy, which is also what
`DesignSystemSelectionRow` builds on. See
[component contracts](../features/design_system/component-contracts.md).

# The bottom-nav shell is app-level

`DesignSystemBottomNavigationBar` and its FAB clearance wrapper live here rather
than in the design system, because the shell is **an app-level overlay docked flush
to the screen edge**, not a `Scaffold.bottomNavigationBar`. Its height contract —
and the clearance any screen-level FAB must respect — is documented in
[component contracts](../features/design_system/component-contracts.md).
