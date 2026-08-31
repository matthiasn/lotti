### Fixed
- **Workouts from Apple Health and Health Connect stopped showing up.** Since
  the move to the upstream health library, a walk started on the watch was
  imported under that library's own spelling of the activity (`WALKING`),
  while every workout chart, every dashboard and the workout history said
  `walking`. Dashboards therefore showed "No data" over months of workouts,
  and a workout's own detail card lost its trend charts. Imported workouts are
  stored under the spelling the charts use again, the charts also count the
  workouts imported in between, and a workout imported on Android now keeps
  the app it came from as its source.
- **Workouts appear on the Daily OS timeline by name.** The Actual lane used
  to print a workout's internal id as its title; it now reads "Walking" or
  "Functional Strength Training", and opening a day pulls new workouts from
  the health store itself instead of waiting for a dashboard with a workout
  chart to be opened.
