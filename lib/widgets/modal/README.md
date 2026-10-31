# Modal components

The app's modal-presentation utilities, built on `wolt_modal_sheet`, plus a few
animation widgets for interactive list and card items.

`ModalUtils` is the **only** public export. Every adaptive sheet in the app is
presented through it: a draggable bottom sheet on narrow layouts, a centred dialog
on wide ones, from one call. `ModalUtils.showWoltModal` is the single place that
calls `WoltModalSheet.show`; an architecture test fails on any other.

Beside it, imported by path:

- `showConfirmationModal` — every yes/no question (delete, roll back, discard).
- `ConfirmationProgressModal` — a confirm that then runs an operation with
  progress.
- `showModalActionSheet` — a list of actions in a bottom sheet.
- `showSideSheetPane` — a full-height panel beside the page.
- `ModalEscapeScope` — Escape for a modal route whose content hosts a
  `Scaffold`; every Wolt sheet already has one.
- `OverlayEscapeScope` — Escape for a scrim drawn inside the page rather than
  pushed as a route.

**If a tap outside a modal closes it, Escape closes it too, with the same
result.** Use these helpers and that holds without extra work.

## How it works

Why presentation is centralized here rather than rebuilt per feature is
documented in the knowledge bundle:

**→ [knowledge/architecture/shared-widgets.md](../../../knowledge/architecture/shared-widgets.md)**

The dismissal rule, why a scaffold inside a modal used to swallow Escape, and
when a modal should refuse both:

**→ [knowledge/conventions/modal-dismissal.md](../../../knowledge/conventions/modal-dismissal.md)**
