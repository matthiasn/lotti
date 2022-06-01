# Lotti Manual

Lotti is a behavioral monitoring and journaling app that lets you keep track of anything you can measure. Measurements could, for example, include tracking exercises manually, plus imported data from Apple Health or the equivalent on Android.


## Creating Measurables

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


## Creating Dashboards

Dashboards are managed in `Settings > Dashboard Management`:

![Dashboards page screenshot](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/dashboards_page.png)

Here, you can either search and then edit existing dashboards, or create new ones with the **+** icon. 

![Exercises dashboard screenshot](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/dashboard_exercise_sample.png)

You can add any number of measurable types in a dashboard, and reorder the charts as desired. Health data types will be imported first time you open the dashboard. 

Finally, you can view the dashboard. 


## Screenshots (Desktop-only)

You can use Lotti to capture screenshots, for example when documenting tasks. You can create screenshots on the journal page using the **+** button and then selecting this icon:

![Exercises dashboard screenshot](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/journal_add_screenshot.png)

It would be useful to also be able to create screenshots from the app menu, see [#1011](https://github.com/matthiasn/lotti/issues/1011) - help is very welcome.
