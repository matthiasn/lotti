---
type: Feature Module
title: Dashboards
description: A view layer over journal-backed data — definitions routed to chart widgets, with a few charts that also launch capture.
resource: ../../../lib/features/dashboards
tags: [dashboards, charts, visualization]
status: stable
generated: { by: claude-code/opus-5, at: 2026-07-26T03:45:00Z }
stale_after: 2027-01-31
sources:
  - id: src
    resource: ../../../lib/features/dashboards
    title: Dashboards feature source
    last_modified: 2026-07-25
---

The dashboards feature reads stored `DashboardDefinition` entities, routes each
`DashboardItem` to the right chart widget, and keeps those charts refreshed from
journal-backed data.

**This is a view layer, not a separate analytics warehouse.** The source data
lives in the journal database and neighbouring features; dashboards mostly
assembles and visualizes it — "mostly", because a few charts can also launch
capture flows directly.

# What it owns

Listing active dashboards; locally filtering that list by category; the single
dashboard page lifecycle and its time-range control; routing each item type to
its chart widget; the measurement capture flow reachable from a chart; and the
refresh and caching model that keeps charts current without re-querying on every
notification.

A `DashboardDefinition` is an `EntityDefinition` variant carrying its name,
description, category, visibility flags and an ordered list of `DashboardItem`s.
**The items are the definition** — reordering or removing a chart is an edit to
that list, made in the [settings](../settings/) dashboard editor rather than here.

# Item rendering is a matrix

Each `DashboardItem` variant maps to one chart widget: measurement charts,
health charts, workout charts, habit charts, survey charts and story-time charts.
Adding a chart type means extending that matrix, not the page.

**Measurement charts are the ones that write.** A measurement chart can open the
capture flow for its data type directly, so recording a value does not require
navigating away — which is why this feature is not purely read-only.

# Refresh and caching

Charts subscribe to the notification stream for the entity kinds they render,
rather than rebuilding the whole page on any journal write. The page owns the
selected time range, so changing it re-slices without re-fetching definitions.

# Related

* [Insights](../insights/) - the dedicated time-analysis dashboard, which is a separate surface with its own data path.
