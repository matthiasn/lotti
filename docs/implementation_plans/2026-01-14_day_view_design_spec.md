# Day View — Component & Widget Specification

## 0. Overall Layout Structure

**Single vertical column**, scrollable.

```
[ A ] Day Header
[ B ] Time-of-Day Timeline (Plan vs Actual)
[ C ] Time Budgets
[ D ] Day Summary
```

* Same structure on mobile and desktop (sidecar)
* Desktop may increase vertical density, not structural complexity
* No horizontal scrolling anywhere

---

## A. Day Header

### Component: `DayHeader`

**Purpose**

* Orient the user in time
* Set context
* Provide light status feedback

**Visual**

* Sticky at top (optional)
* Minimal height
* Dark neutral background
* High-contrast date text

**Contents**

* Day + date (e.g. “Tuesday, Jan 11”)
* Optional day label / intent chip (e.g. “Focused Workday”)
* Optional day status indicator:

  * On track
  * Over budget
  * Done

**Behavior**

* Swipe left/right → change day
* Tap date → open date picker
* Status indicator is informational only (no actions)

**Non-goals**

* No metrics
* No charts
* No task info

---

## B. Time-of-Day Timeline (Plan vs Actual)

### Component: `DailyTimeline`

This is a **single component**, not two separate columns.

---

### B1. Timeline Grid

#### Subcomponent: `TimeAxis`

**Purpose**

* Provide temporal reference

**Visual**

* Vertical list of hours (e.g. 08:00, 09:00, …)
* Subtle grid lines
* Low-contrast labels

**Behavior**

* Scrolls with content
* No snapping
* No interaction

---

### B2. Planned Time Lane

#### Subcomponent: `PlannedTimeLane`

**Purpose**

* Show intended structure of the day

**Visual**

* Left lane within the timeline
* Ghosted blocks
* Category color at low opacity (20–30%)
* Rounded corners
* Slight dashed or soft outline

**Block contents**

* Category name
* Planned duration (optional, small)
* No task names

**States**

* Normal
* Missed (planned block with no overlapping actual time)

  * Slightly dimmed
  * Optional subtle indicator

**Behavior**

* Tap block → highlights:

  * Related time budget below
  * Any actual blocks linked to that category
* Long-press → edit planned block
* Blocks may overlap; this is allowed

**Non-goals**

* No enforcement
* No warnings
* No success/failure indication

---

### B3. Actual Time Lane

#### Subcomponent: `ActualTimeLane`

**Purpose**

* Show factual record of work

**Visual**

* Right lane within the timeline
* Solid blocks
* Higher contrast than planned blocks
* Category color at full opacity
* Sharper edges than planned blocks

**Block contents**

* Task title (truncated if needed)
* Duration or start–end time
* Optional task thumbnail (small, optional)

**States**

* Active (currently running timer)
* Completed
* Edited (manually adjusted)

**Behavior**

* Tap block → opens task detail
* Long-press → adjust time
* Drag (optional) → adjust start/end

**Rules**

* Actual blocks never snap to planned blocks
* Multiple actual blocks may map to one planned block
* Actual blocks may exist without any planned block

---

## C. Time Budgets

### Component: `TimeBudgetList`

This is the **control center** of the Day View.

---

### C1. Time Budget Card

#### Subcomponent: `TimeBudgetCard`

**Purpose**

* Represent intentional allocation of time
* Track consumption independent of schedule

**Visual**

* Card or row
* Neutral background
* Category color used for accent only
* Clear separation between budgets

**Header contents**

* Category name
* Planned duration (e.g. “3h planned”)
* Status text:

  * “45m remaining”
  * “Time’s up”
  * “+30m over”

---

### C2. Budget Progress Bar

#### Subcomponent: `BudgetProgressBar`

**Purpose**

* Show planned vs recorded time

**Visual**

* Horizontal bar
* 100% = planned budget
* Fill grows as time is recorded
* Overrun spills past 100% visibly

**States**

* Under budget
* Near limit (e.g. <15m remaining)
* Exhausted
* Over budget

**Behavior**

* Updates live as timers run
* Tap → scroll timeline to highlight contributing actual blocks

---

### C3. Task List (Inside Budget)

#### Subcomponent: `BudgetTaskList`

**Purpose**

* Show receipts and affordances for action

##### Task types

1. **Pinned Tasks**

  * Manually added
  * No recorded time yet
  * Quick-start affordance

2. **Recorded Tasks**

  * Appear automatically
  * Show total time contributed to this budget
  * May include thumbnail

**Visual**

* Simple list
* Recorded tasks visually prioritized
* Pinned tasks visually lighter

**Behavior**

* Tap task → open task
* Start timer from pinned task
* Reassign task to another budget

**Rules**

* Any task with recorded time MUST appear
* Tasks may appear in only one budget per day
* Reassignment affects accounting, not timeline

---

### C4. Budget Alerts

#### Subcomponent: `BudgetBoundaryIndicator`

**Purpose**

* Provide gentle enforcement

**Visual**

* Inline text or small icon
* Warm color escalation
* No modals

**Behavior**

* Appears only when relevant
* Never blocks actions
* Can be dismissed temporarily

---

## D. Day Summary

### Component: `DaySummary`

**Purpose**

* Provide closure
* Support reflection

**Visual**

* Calm, low-density
* Optional background image (day cover)
* Text-forward

**Contents**

* Total planned time
* Total recorded time
* Largest drift (category)
* Optional “Done for today” action

**Behavior**

* Mark day as complete
* Copy budgets to next day
* Generate reflection prompt (optional)

**Non-goals**

* No charts
* No drill-down
* No comparisons to other days

---

## Cross-Component Interaction Rules

These are **critical for coherence**:

1. **Timeline ↔ Budgets**

  * Selecting one highlights the other
  * No data duplication

2. **Budgets override time**

  * Success is budget-based, not schedule-based

3. **Plans are editable, receipts are factual**

  * Planned blocks are mutable
  * Actual blocks are historical

4. **Everything degrades gracefully**

  * No planned blocks? Budgets still work
  * No budgets? Timeline still works
  * No recorded time? Pinned tasks guide action

---

## Design Principles Embedded in the Components

* **Separation of concern**
* **Visual humility**
* **Reality-first**
* **No forced alignment**
* **Boundaries without punishment**

Every widget reinforces these principles.

---

If you want next, we can:

* Translate this into a **component tree for implementation**
* Define **state models & data contracts**
* Write **microcopy for every alert and label**
* Design **empty / edge states** (very important here)

This is now a system you can actually build without it collapsing under edge cases.
