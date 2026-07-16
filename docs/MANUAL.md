# Lotti's Manual

Lotti is a behavioral monitoring and journaling app that lets you keep track of anything you can
measure. Measurements could, for example, include tracking exercises, plus imported data
from Apple Health or the equivalent on Android. In terms of behavior, you can monitor habits, e.g.
such that are related to measurables. This could be the intake of medication, numbers of repetitions
of an exercise, the amount of water you drink, the amount of fiber you ingest, you name it. Anything
you can imagine. If you create a habit, you can assign any dashboard you want, and then by the time
you want to complete a habit, look at the data and determine at a quick glance of the conditions are
indeed met for successful completion.

## Focused guides

- [Task agents and AI summaries](manual/task_agents.md)

## Daily OS

Daily OS turns a spoken or typed check-in into an editable plan for one day. It
does not replace your tasks or time records: it proposes when work could happen,
shows the plan beside what you actually recorded, and lets you reshape the
schedule by voice or directly on the calendar.

The screenshots below use a deliberately busy synthetic day for a fictional
Director of Interplanetary Penguin Logistics. Your penguin situation may vary.

### Before your first check-in

Open `Settings > Daily OS` and choose an inference profile. The settings page
identifies whether the configured endpoint is on this device or remote. Daily
OS sends the assembled planning context to that selected endpoint. You can also
set the name used in the greeting.

In `Settings > Categories`, enable **Day planning** for the categories the
planner may use. Keeping that set intentional makes the suggestions more useful
and keeps unrelated parts of your life out of the daily ritual.

### 1. Say what the day needs

Open **Daily OS**, select the date, and choose **Speak a check-in**. Talk in
normal sentences: mention fixed commitments, outcomes, rough durations,
energy constraints, breaks, and anything that should not happen too late. Use
**Type instead** when speaking is inconvenient.

After recognition, review the complete transcript before sending it onward.
The editor grows with longer dictations instead of hiding the rest after a few
lines; you can correct names, numbers, or delightfully niche job titles in
place.

![Review a full Daily OS transcript](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/pro_05_captured_dark.png)

Choose **Re-record** to start over or **Review** to continue. Processing feedback
appears from the first frame, and **Build my day** remains unavailable until the
initial matching pass has completed.

![Daily OS processing indicator rendered by the app shader](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/daily_os_shader_runtime_phone_dark.png)

### 2. Reconcile what the assistant heard

Reconcile is the safety check between speech and action. It separates what you
said into auditable cards:

- **Matched** points to an existing task. Check that the linked task is the one
  you meant; break the link if it is not.
- **New** is a phrase that can become work for today.
- **Update** proposes a change to an existing task.
- Low-confidence and time-anchor labels explain where your attention is most
  useful.

![Reconcile a busy spoken check-in](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/pro_07_reconcile_dark.png)

The second section surfaces work already in progress, overdue, due today, or
recently missed. Decide what belongs today rather than allowing yesterday's
entire backlog to colonize the morning.

If you have already recorded time for the selected date, **Today so far** keeps
that reality visible during the check-in.

![Today so far during capture](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/mini_14_capture_today_so_far_dark.png)

### 3. Let Daily OS draft, then judge the plan

Choose **Build my day** after the decisions look right. The drafting screen
shows what the planner is doing and keeps useful context visible while the plan
is assembled.

![Daily OS drafting a schedule](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/pro_08_drafting_dark.png)

The first result opens on **Agenda**. The capacity card answers “does this fit?”
before the numbered list answers “what matters?” Category totals expose where
the day is going, completed work collapses into compact receipts, and placement
reasons explain why the assistant chose important slots.

![A busy Daily OS agenda](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/day_pro_01_agenda_dark.png)

Use the quick adjustments when the shape is wrong:

- **Too much** asks for a smaller plan.
- **Move lighter** moves demanding work away from low-energy periods.
- **Add buffer** creates breathing room.
- **Refine** opens a free-form voice check-in for any other change.

Nothing is locked in merely because the assistant proposed it. Choose
**Looks good** when the draft is genuinely acceptable.

### 4. Compare the plan with reality

Switch from **Agenda** to **Day** for the calendar projection. On desktop, Plan
and Actual share one time axis; on a phone, swipe horizontally between them.
Idle hours fold instead of disappearing, and you can pinch vertically to
change time density. Planned blocks use a lighter sketched treatment; recorded
sessions are filled, so drift is visible without rewriting history.

![Plan and actual time on the desktop Daily OS timeline](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/day_desktop_02_timeline_dark.png)

### 5. Move, resize, and edit blocks directly

Choose the four-arrow **Arrange** action above the timeline to expand folded
regions and reveal direct-manipulation handles. Drag a block body to move it;
drag its top or bottom handle to change the start or end. Changes snap to
15-minute increments, stay inside the selected day, and appear immediately.
After a successful change, use **Undo** in the confirmation toast if the old
slot was better.

![Arrange mode with move and resize handles](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/day_pro_03_timeline_arrange_dark.png)

Every editable planned block also has a pencil. The overview keeps the common
changes together: title, category, start/end, and the assistant's placement
reason.

![Edit a standalone Daily OS block](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/day_pro_04_block_edit_overview_dark.png)

Choose **Start & end** for the same time wheels used by recorded-time entries.
The overview is not saved until you return and choose **Save changes**, so the
whole edit is applied as one operation.

![Edit a block's start and end](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/day_pro_05_block_edit_time_dark.png)

Task-linked blocks behave slightly differently. Their title and category
belong to the task, so those fields are read-only here and **Open task** takes
you to the source. Rename the task or change its category there; the linked
Agenda row and calendar block update immediately, including the category name
and color. The block's scheduled start and end remain editable from Daily OS.

![Edit a task-linked Daily OS block](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/day_pro_06_block_edit_linked_dark.png)

### A useful mental model

- **Tasks describe the work.** A linked task owns its title and category.
- **The day plan describes intent.** Blocks own placement and duration.
- **Time records describe reality.** Actual sessions remain independent of the
  plan and can diverge honestly.
- **The assistant proposes; you decide.** Reconcile, manual editing, Refine,
  Undo, and Looks good keep consequential changes user-owned.

## Categories
Categories are different important aspects of you life. Examples (in no particular order):

- Health
- Sleep
- Physical Fitness
- Mindfulness
- Family
- Social Life
- Creative Expression
- Dental Health
- Money
- Work
- ...

Lotti lets you define those different categories, and then assign them to other entities, such as
Habits and Dashboards. Categories can then be used for example for filtering by categories, and be
able to focus on one (or a few) at a time.

### Create Categories
In `Settings > Categories`, you can add and manage categories used elsewhere in the app. Initially,
you will see an empty page:

![Category Settings - empty](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/categories_empty.png)

Tap the plus icon at the bottom right to create a new category, and enter the name and hex color as
desired, for example:

![Health Category](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/category_health.png)

You can also use a color picker to get exactly the color that means something to you. For that, tap
the color palette on the right side of the hex color field and pick what you like:

![Health Category - Color Picker](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/category_health_picker.png)

Finally, tap the save button. Repeat until you have a good idea what areas you want to look at next
(you can always add more categories later). For example:

![Category Settings](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/categories.png)

## Habits

### Create Habits
Now that categories are defined, let's add some habits. Technically, you could add habits without
categories, but then those habits would be displayed with a boring gray color, and that would look
pretty boring. Got to `Settings > Habits`:

![Habit Settings - empty](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habits_empty.png)

Tap the plus icon and add a title:

![New Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit3_initial.png)

Here, you can also assign the category you created earlier, in this case `Fitness`:

![New Habit - Select Category](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit3_category.png)

Finally, save the habit:

![New Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit3_final.png)

Repeat creating habits until all the ones you want to start with are defined, for example:

![New Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habits.png)

### Complete Habits on a regular base
Go to the Habits page, all the way to the left (this page is also shown after application startup).
This could initially look like this:

![Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit_completions1.png)

Above, you'll notice that the habit completion chart is all red. You can remedy this in one of two ways:

- Backfilling by adding habit completions for previous days.
- Defining the start date in the settings of a habit.

#### Habit completion backfill (optional)
You can backfill habit completions for previous days by tapping on the previous days in the row
below the habit titles, which will create a habit completion entry at `23:59` of that particular
day. For example, when you know walked at least 10K steps two days ago but were lazy yesterday, tap
the red rounded rectangle two from the right and complete the habit as a 'success', and the same for
one further to the right, but completed as a 'fail', and so on:

![Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit_completion_10k_steps.png)

Eventually, you will end up with a habit completion card that might look a lot more satisfying than
the all red indicator row in the beginning:

![Habit - 10k+ Steps backfilled](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit_completion_10k_all.png)

#### Habit completion
Whenever you want to complete a habit, e.g. because you just flossed, took a certain medication, or
whatever else the desired recurring behavior might be, you just tap the checkmark icon on the far
right of a habit completion card. A dialog will open for completing the habit, with date and time
prefilled, where you can complete a habit with one of three habit completion types:

- **Fail**: I record this state when I could have done something but failed to do so. Example: I
  could’ve flossed but did not.
- **Skip**: this state is meant for habits where I was motivated to complete a habit but could not,
  for reasons outside of my responsibility. Example: let’s say I want to play ping pong every day
  but if I don’t find anyone to play with, I use skip. I also use skip for habits that I only want
  to complete once or a few times for week. Could be a weekly fluoride treatment for stronger teeth,
  or running, where I only record fail if the last time is too long ago. But if I went running
  yesterday, it’s a skip as I don’t even want to go running every day.
- **Success**: this is obviously the desired state. I’m aiming for checking off 80% or more of my
  habits every day, hence also the 80% line in the chart.

![Habit - 10k+ Steps now](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit_completion_10k_steps_now.png)

The Habits page has different section for habits that are open now, habits due later, and habits
that were already completed for the day. Example for the latter:

![Habits - done](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/habit_completions_done.png)

The habit completion dialog can also show data relevant to the respective habit, for example the
different exercise types related for example to a `morning exercises` habit. But first, we need to
look at defining measurable data types and dashboards.

## Creating Measurables

Measurable data types are managed in `Settings > Measurable Data Types`:

![Measurable Data Types - empty](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/measurables_empty.png)

You can add new measurable data types with the **+** icon on the Measurables page, and existing ones
can be searched and edited:

![Measurable Data Type - Pull-ups](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/measurable_pull_ups.png)

The name needs to be filled out, description and unit type are optional. There are different
aggregation types (also optional):

- **None:** will result in a line chart with each value representing a point on the line at measurement. Useful, for example, for body measurements, number of followers, balances, etc.
- **Daily Sum:** will result in a bar chart with all measurements added per day. Useful, for example, for repetitions of exercises. This is the default when nothing is selected.
- **Daily Max:** will result in a bar chart with the maximum value for a day, one per day (not currently implemented).
- **Daily Average:** will result in a bar chart with the maximum value for a day, one per day (not currently implemented).

Press save when completed. You will get back to the list of measurable data types, for example:

![Measurable Data Types](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/measurables.png)


## Creating Dashboards
Dashboards are managed in `Settings > Dashboard Management`:

![Dashboards - empty](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/dashboards_empty.png)

Here, you can either search and then edit existing dashboards, or create new ones with the **+** 
icon. Add a name, plus an optional description:

![Dashboard - Exercises](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/dashboard_exercise.png)

Next, select one or more `Measurable Data Chart` items, followed by tapping `OK`:

![Dashboard - Exercises](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/dashboard_exercise2.png)

Finally, save the dashboard.

![Dashboard - Exercises](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/dashboard_exercise3.png)

![Dashboards - empty](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/dashboards.png)

You can add any number of measurable types in a dashboard, and reorder the charts as desired. 
Health data types will be imported first time you open the dashboard. 

Finally, you can view the dashboard in the dashboards tab:

![Dashboards - empty](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.377+2248/dashboards_tab.png)

## Screenshots (Desktop-only) [OUTDATED]

You can use Lotti to capture screenshots, for example when documenting tasks. You can create 
screenshots on the journal page using the **+** button and then selecting this icon:

![Exercises dashboard screenshot](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/journal_add_screenshot.png)

It would be useful to also be able to create screenshots from the app menu, see [#1011](https://github.com/matthiasn/lotti/issues/1011) - help is very welcome.


## Audio Recordings

## Questionnaires

## Tasks

### Priority (P0–P3)
Tasks support four priority levels using compact short codes (P0—P3). You can set a task’s priority from the task header and filter the Tasks tab by one or more priorities. The list orders by priority first (P0 to P3), then by creation date (newer first).

See: docs/user_guides/task_priority.md
