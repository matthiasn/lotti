---
type: Architecture
title: Shared widgets
description: "The widgets that belong to no single feature — app-bar chrome, modal presentation, selection primitives and settings scaffolding."
resource: ../../lib/widgets
tags: [widgets, shared, modals, selection]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T04:45:00Z }
stale_after: 2027-01-26
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

# Modal presentation is mostly centralized

`ModalUtils` is the **only public export** of `lib/widgets/modal/`, and it is how
most adaptive sheets are presented: a draggable bottom sheet on narrow layouts, a
centred dialog on wide ones, from one call. It backs the single-page pickers and
the multi-page settings flows.

Centralizing it is what keeps the responsive contract consistent — a feature that
builds its own sheet has to re-derive the breakpoint, the insets, the barrier
behaviour and the glass footer treatment, and will drift.

**Two flows own their own Wolt presentation** and are worth knowing about before
assuming a single entry point:

| Flow | Why |
|------|-----|
| [The Daily OS planning modal](../features/daily_os_next/ui-surfaces.md) | Calls `WoltModalSheet.show` directly and picks its responsive type itself, because it needs a right-anchored full-height **side panel** on wide screens rather than a centred dialog. It still borrows `ModalUtils` helpers for the barrier colour and its sliver pages |
| [What's New](../features/whats_new.md) | Invokes Wolt directly for its own presentation |

So the accurate rule is: `ModalUtils` owns the shared styling and navigation
helpers, and a flow may own its presentation when its layout genuinely differs —
but it should still reuse those helpers rather than re-deriving them.

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
