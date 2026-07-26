# Insights

Insights is Lotti's time-analysis dashboard: where the time actually went.

It lives under the Daily OS tab and answers three questions — where did my time
go this period, how much per area per day, and how does that accumulate — over
years of entries, fast enough to browse period by period without waiting.

## What it does for the user

- **Shows time by area, over any period.** Day, week, month, quarter or year,
  stepped one period at a time or jumped to from a calendar.
- **Starts the week where the user's region does.** Monday across most of Europe,
  Sunday in the US — the calendar grid and week periods agree.
- **Has honest "this month" and "this year" shortcuts.** They cover the period so
  far, not the whole calendar period, so the chart is not padded with empty future
  days and per-day averages divide by days that actually happened.
- **Compares against the previous period** with one toggle.
- **Counts time carefully.** Audio recordings are excluded so a recording made
  during a running timer cannot count twice; overlapping entries in the same area
  are merged rather than added; and entries that cross midnight are split
  correctly, including on daylight-saving days.
- **Attributes time to the right area.** A time entry linked to a task takes the
  task's area, falling back to its own.
- **Stays fast.** Switching periods is instant, because the underlying data is
  loaded once per year and sliced in memory.

## What it owns

The time-analysis page and its route; the period stepper, calendar picker and
comparison toggle; the focus-category preference; the slim time query and its
bucketing; and the KPI, chart and table builders.

## Where the code lives

```text
lib/features/insights/
├── model/ · repository/ · state/
└── ui/{pages,widgets}
```

## How it works

The query shape and year-window cache, the data semantics that make the numbers
trustworthy, and the period-navigation model are documented in the knowledge
bundle:

**→ [knowledge/features/insights/](../../../knowledge/features/insights/)**
