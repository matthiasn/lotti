# Habits

Habits are the recurring things a user wants to keep doing — and the record of
whether they actually did.

The feature's real work is reconciliation: a habit definition says what should
happen, completion entries say what did, and almost everything the user sees is
derived from combining the two.

## What it does for the user

- **Shows what is due now.** The tab splits habits into open now, pending later
  (not yet due today), and completed — so the list is a to-do, not an inventory.
- **Completes in one gesture.** Swipe or tap to log a habit; a fuller dialog is
  there when the completion needs detail or a different result.
- **Shows momentum honestly.** A daily summary with a done count, a "to go"
  caption, and streak badges — where a streak requires *every* day in the window,
  and only an explicit failure or a missing day breaks it.
- **Shows the long view.** A full-width consistency heatmap of per-day completion
  intensity across all habits, going back years.
- **Charts completion rates** over selectable time spans, with day-level
  breakdowns.
- **Reminds at the right time.** A habit can carry a time it becomes visible and a
  time to be alerted, scheduled as a notification.
- **Groups by area and dashboard**, assigned from the habit's settings form.

## What it owns

The habits tab and its derived sections; the summary card; the consistency
heatmap; completion-rate chart state and the time-span switch; quick completion
capture and the detailed dialog; habit settings state for create and edit;
category and dashboard assignment from the settings form; and the
auto-completion engine that checks a habit off when its recorded signals
satisfy its rule.

It does not own every write path — reads go through `HabitsRepository`, while
definition saves and completion writes both go through shared persistence.

## Where the code lives

```text
lib/features/habits/
├── repository/ · state/ · service/
└── ui/{pages,widgets,charts}
```

## How it works

The three read models, the last-write-wins resolution per habit and day, exactly
what the tab controller derives, how auto-completion decides and when it runs,
and where the data model outruns the current editing surface are documented in
the knowledge bundle:

**→ [knowledge/features/habits.md](../../../knowledge/features/habits.md)**
