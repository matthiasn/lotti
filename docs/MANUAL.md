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

![Category Settings - empty](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.323+2006/categories_empty.png)

Tap the plus icon at the bottom right to create a new category, and enter the name and hex color as
desired, for example:

![Health Category](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.323+2006/category_health.png)

You can also use a color picker to get exactly the color that means something to you. For that, tap
the color palette on the right side of the hex color field and pick what you like:

![Health Category - Color Picker](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.323+2006/category_health_picker.png)

Finally, tap the save button. Repeat until you have a good idea what areas you want to look at next
(you can always add more categories later). For example:

![Category Settings](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.323+2006/categories.png)

## Habits

### Create Habits
Now that categories are defined, let's add some habits. Technically, you could add habits without
categories, but then those habits would be displayed with a boring gray color, and that would look
pretty boring. Got to `Settings > Habits`:

![Habit Settings - empty](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.323+2006/habits_empty.png)

Tap the plus icon and add a title:

![New Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.323+2006/habit3_initial.png)

Here, you can also assign the category you created earlier, in this case `Fitness`:

![New Habit - Select Category](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.323+2006/habit3_category.png)

Finally, save the habit:

![New Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.323+2006/habit3_final.png)

Repeat creating habits until all the ones you want to start with are defined, for example:

![New Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.323+2006/habits.png)

### Complete Habits on a regular base
Go to the Habits page, all the way to the left (this page is also shown after application startup).
This could initially look like this:

![Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.323+2006/habit_completions1.png)

Above, you'll notice that the habit completion chart is all red. You can remedy this in one of two ways:

- Backfilling by adding habit completions for previous days.
- Defining the start date in the settings of a habit.

#### Habit completion backfill
You can backfill habit completions for previous days by tapping on the previous days in the row
below the habit titles, which will create a habit completion entry at `23:59` of that particular
day. For example, when you know walked at least 10K steps two days ago but were lazy yesterday, tap
the red rounded rectangle two from the right and complete the habit as a 'success', and the same for
one further to the right, but completed as a 'fail', and so on:

![Habit - 10k+ Steps](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.323+2006/habit_completion_10k_steps.png)

Eventually, you will end up with a habit completion card that might look a lot more satisfying than
the all red indicator row in the beginning:

![Habit - 10k+ Steps backfilled](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/0.9.323+2006/habit_completion_10k_all.png)



## Creating Measurables [OUTDATED]

Measurable data types are managed in `Settings > Measurable Data Types`:

![Settings page screenshot](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/settings_page.png)

You can add new measurable data types with the **+** icon on the Measurables page, and existing ones can be searched and edited:

![Pull-ups data type screenshot](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/measurables_pull_ups.png)

Name, description and unit type need to be filled out. There are different aggregation types:

- **None:** will result in a line chart with each value representing a point on the line at measurement. Useful, for example, for body measurements, number of followers, balances, etc.
- **Daily Sum:** will result in a bar chart with all measurements added per day. Useful, for example, for repetitions of exercises. This is the default when nothing is selected.
- **Daily Max:** will result in a bar chart with the maximum value for a day, one per day (not currently implemented).
- **Daily Average:** will result in a bar chart with the maximum value for a day, one per day (not currently implemented).

Don't forget to save a new measurable data type. You won't be warned about losing unsaved work when navigating away. Of course users should be warned when navigating away. **Want to help?** See [#1009](https://github.com/matthiasn/lotti/issues/1009).


## Creating Dashboards [OUTDATED]

Dashboards are managed in `Settings > Dashboard Management`:

![Dashboards page screenshot](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/dashboards_page.png)

Here, you can either search and then edit existing dashboards, or create new ones with the **+** icon. 

![Exercises dashboard screenshot](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/dashboard_exercise_sample.png)

You can add any number of measurable types in a dashboard, and reorder the charts as desired. Health data types will be imported first time you open the dashboard. 

Finally, you can view the dashboard. 


## Screenshots (Desktop-only) [OUTDATED]

You can use Lotti to capture screenshots, for example when documenting tasks. You can create screenshots on the journal page using the **+** button and then selecting this icon:

![Exercises dashboard screenshot](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/journal_add_screenshot.png)

It would be useful to also be able to create screenshots from the app menu, see [#1011](https://github.com/matthiasn/lotti/issues/1011) - help is very welcome.


## Audio Recordings

## Questionnaires

## Tasks

