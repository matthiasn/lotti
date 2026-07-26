# Dashboards

Dashboards are user-built views over the data Lotti already has: a set of charts
chosen and ordered by the user, grouped on one page.

## What it does for the user

- **Builds a view per interest.** A dashboard is a named, ordered set of charts —
  measurements, health data, workouts, habits, survey results, time.
- **Groups by area.** The dashboard list can be filtered by category.
- **Picks a time range.** One control re-slices every chart on the page.
- **Records from the chart.** A measurement chart can open its capture flow
  directly, so logging a value does not mean navigating away.
- **Stays current.** Charts refresh when the underlying entries change.

Dashboards are created and edited in Settings → Definitions → Dashboards; this
feature renders them.

## What it owns

Listing and filtering dashboards; the single-dashboard page and its time-range
control; routing each dashboard item to its chart widget; the measurement capture
flow reachable from a chart; and the refresh model.

The source data lives in the journal database and neighbouring features — this is
a view layer, not a separate analytics store.

## Where the code lives

```text
lib/features/dashboards/
├── state/
└── ui/{pages,widgets,charts}
```

## How it works

What the feature owns, the item rendering matrix, and the refresh model are
documented in the knowledge bundle:

**→ [knowledge/features/dashboards/](../../../knowledge/features/dashboards/)**
