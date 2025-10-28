# Lotti's Manual

Lotti is a behavioral monitoring and journaling app that lets you keep track of anything you can
measure. Measurements could, for example, include tracking exercises, plus imported data
from Apple Health or the equivalent on Android. In terms of behavior, you can monitor habits, e.g.
such that are related to measurables. This could be the intake of medication, numbers of repetitions
of an exercise, the amount of water you drink, the amount of fiber you ingest, you name it. Anything
you can imagine. If you create a habit, you can assign any dashboard you want, and then by the time
you want to complete a habit, look at the data and determine at a quick glance of the conditions are
indeed met for successful completion.

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
