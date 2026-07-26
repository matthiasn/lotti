# Modal components

The app's modal-presentation utilities, built on `wolt_modal_sheet`, plus a few
animation widgets for interactive list and card items.

`ModalUtils` is the **only** public export. Every adaptive sheet in the app is
presented through it: a draggable bottom sheet on narrow layouts, a centred dialog
on wide ones, from one call.

## How it works

Why presentation is centralized here rather than rebuilt per feature is
documented in the knowledge bundle:

**→ [knowledge/architecture/shared-widgets.md](../../../knowledge/architecture/shared-widgets.md)**
