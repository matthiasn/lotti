# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added:
- Audio playback on Linux

### Changed:
- Upgraded dependencies

## [0.8.330] - 2023-04-24
### Changed:
- Sync assistant styling
- Upgraded dependencies

### Fixed:
- Sync getting stuck after generating new sync key and on reading sync message encrypted with old key

## [0.8.329] - 2023-04-23
### Changed:
- Upgrade flutter_quill lib

## [0.8.328] - 2023-04-23
### Changed:
- Show audio player inline in linked entries

## [0.8.327] - 2023-04-22
### Fixed:
- Navigation after delete (not when displayed as a linked entry)

### Changed:
- Updated provisioning profile (was expired)
- Automatically managed signing on iOS

## [0.8.326] - 2023-04-21
### Added:
- GitHub Action for running Fluttium tests on Windows

## [0.8.325] - 2023-04-20
### Added:
- Semantic labels in measurable data type setting
- Screenshot of creating measurable data types for manual

### Changed:
- Colors and whitespace
- Upgraded dependencies
- Initial height of chart selector bottom sheet
- Slightly less saturated card color

### Fixed:
- Test flows

## [0.8.324] - 2023-04-19
### Fixed:
- Image card background

## [0.8.323] - 2023-04-18
### Changed:
- Updated manual
- Less verbose logging
- App icon with gradient

## [0.8.322] - 2023-04-16
### Changed:
- Fluttium screenshots are pushed to lotti-docs repository

## [0.8.321] - 2023-04-15
### Changed:
- App icon on Android
- App icon on macOS
- App icon on Windows

## [0.8.320] - 2023-04-15
### Changed:
- App icon on Windows
- Upgraded dependencies
- Improved color picker

### Added:
- Category color text field for HEX color, with ColorPicker moved to bottom sheet

### Fixed:
- Update color HEX field after picking new color

## [0.8.319] - 2023-04-13
### Changed:
- Measurable setting page layout

## [0.8.318] - 2023-04-13
### Changed:
- New app icon

## [0.8.317] - 2023-04-12
### Added:
- Settings icon on Habits page

### Fixed:
- SafeArea around Dashboards page

## [0.8.316] - 2023-04-12
### Fixed:
- Clear categories filter visibility
- Text overflow for long habit titles

## [0.8.315] - 2023-04-12
### Added:
- Category selection for dashboards

### Changed:
- Improved search field
- Improved dashboards page header

## [0.8.314] - 2023-04-11
### Changed:
- Material icons in bottom nav
- Material icons in audio recorder
- Remove unused code
- Upgraded dependencies

## [0.8.313] - 2023-04-11
### Changed:
- Updated README

## [0.8.312] - 2023-04-10
### Changed:
- Upgraded dependencies
- Refactoring on Journal page
- Improved habits page header

### Fixed:
- SafeArea around Habit page

## [0.8.311] - 2023-04-09
### Changed:
- Initial window size on macOS

## [0.8.310] - 2023-04-09
### Added:
- Integration tests using Fluttium
- Config flag for recording geolocation
- Category color icons for habit completion card and entry detail view
- Fluttium test in Buildkite

### Changed:
- Reordered fields in habit config
- Default story removed from habits

### Fixed:
- Entry DateTime field width

## [0.8.309] - 2023-04-08
### Changed:
- Refactoring in audio recording

## [0.8.308] - 2023-04-07
### Changed:
- Data capture dialog style

## [0.8.307] - 2023-04-07
### Changed:
- Upgraded dependencies
- App icon for windows msix
- Removed chart animation
- Whitespace in habit completion bottom sheet

## [0.8.306] - 2023-04-06
### Added:
- Windows build

## [0.8.305] - 2023-04-05
### Changed:
- Carousel in dashboards removed

### Fixed:
- Data capture from dashboard line chart
- Style consistency in dialog input fields

## [0.8.304] - 2023-04-05
### Added:
- Android release

## [0.8.303] - 2023-04-04
### Changed:
- Habit completion in modal bottom sheet instead of dialog
- Measurement dialog without beamer page
- Habit completion dialog without beamer page

### Added:
- Select dashboard to display during habit completion
- Show dashboard associated with habit in habit completion modal bottom sheet

### Fixed:
- Sort & filter dashboards in habit definition
- Complete habits for prior days

## [0.8.302] - 2023-04-03
### Fixed:
- Suggested previous values in measurement capture dialog cannot be selected

## [0.8.301] - 2023-04-03
### Fixed:
- Permission for notifications

### Changed:
- Postponed request for geolocation in first-time user experience

## [0.8.300] - 2023-04-02
### Fixed:
- Picking multiple images only picking one image

## [0.8.299] - 2023-04-02
### Changed:
- Upgraded Flutter
- Change habit active status to archived status

### Fixed:
- DateTime form field width

## [0.8.298] - 2023-04-01
### Changed:
- Categories filter applies to all sections, not only currently due habits

## [0.8.297] - 2023-04-01
### Changed:
- Upgrade dependencies
- Whitespace on entry detail page

### Fixed:
- Styling of DateTime modal bottom sheet

## [0.8.296] - 2023-03-30
### Fixed:
- Habit completion chart display range issue

## [0.8.295] - 2023-03-29
### Changed:
- Upgraded dependencies
- Improved naming in habit definition

### Fixed:
- Habit Start Date field appeared filled when it was not

## [0.8.294] - 2023-03-28
### Fixed:
- Show save button upon category color change

## [0.8.293] - 2023-03-28
### Changed:
- Fill survey page removed

## [0.8.292] - 2023-03-27
### Changed:
- FormBuilderCupertinoDateTimePicker replaced in task estimate
- FormBuilderCupertinoDateTimePicker replaced in habit completion dialog
- Removed opacity in bottom sheets
- FormBuilderCupertinoDateTimePicker replaced in new measurement dialog
- New measurement page removed
- flutter_datetime_picker removed from entry datetime modal
- Simpler display of habit completion count
- FormBuilderCupertinoDateTimePicker replaced in habit definition
- FormBuilderCupertinoDateTimePicker code removed
- Upgraded dependencies

## [0.8.291] - 2023-03-27
### Fixed:
- Missing day in habits after switching to DST

## [0.8.290] - 2023-03-26
### Added:
- Display time spent on task

## [0.8.289] - 2023-03-26
### Fixed:
- Category save duplicate warning
- Disable category save icon when form invalid
- Recreate category with the same name as previously deleted category
- Scroll in setting when window is small

### Changed:
- Upgraded dependencies

## [0.8.288] - 2023-03-25
### Added:
- Visualization for categories of open habits
- Category name validation checking for duplicates
- Categories filter bottom sheet with categories toggle
- Filtered habits view by selected category

### Changed:
- Upgraded dependencies

### Fixed:
- Delete category question and confirmation label
- Scroll in category bottom sheet
- Prevent duplicate categories
- Categories filter not visible when no open habits displayed
- 180 days in habit completion rate chart

## [0.8.287] - 2023-03-22
### Changed:
- Habit completion card layout

## [0.8.286] - 2023-03-21
### Added:
- Category entity type
- Categories list page
- Categories details page
- Set category color
- Priority switch in habit, for more prominent display
- Priority icon in habit settings list card
- Priority icon in habits list card
- Category selection in habit definition
- Category color in habit settings card
- Habits sorted by priority first
- Habit color in habit completion card

### Changed:
- Whitespace in settings
- Upgraded dependencies

### Fixed:
- Focus issue in habit category selection

## [0.8.285] - 2023-03-19
### Added:
- Segmented control for filtering which habits are shown (due, later today, complete, all)
- Search field for habits

### Changed:
- Selectable habit time spans
- More obvious habit completion state with strike-trough text and subtle opacity
- Upgraded dependencies
- Toggle display of habits time span

## [0.8.284] - 2023-03-19
### Changed:
- Habit completion icon

### Fixed:
- CI pipeline

## [0.8.283] - 2023-03-18
### Changed:
- Refactor: remove unused code
- Line in header removed
- Upgraded dependencies

## [0.8.282] - 2023-03-17
### Added:
- Placeholder text in editor (English and German)

### Changed:
- Improved journal filters

## [0.8.281] - 2023-03-16
### Changed:
- Habit cards
- Task status styling
- Whitespace around cards
- Task card whitespace
- Refactoring: extracted theme

## [0.8.280] - 2023-03-16
### Changed: 
- Use Material Design icons

## [0.8.279] - 2023-03-15
### Changed:
- Using Cards from Material Design 3 throughout where appropriate
- Upgraded dependencies
- Material Cards in Tag, Habit, and Dashboard definition pages

### Fixed:
- Outbox color by status

## [0.8.278] - 2023-03-13
### Changed:
- Unused code removed
- Upgraded dependencies

## [0.8.277] - 2023-03-03
### Changed:
- Upgraded dependencies

### Fixed:
- Entry DateTime modal layout

## [0.8.276] - 2023-02-28
### Changed:
- more consistent bottom sheet modals
- remove limit in tag search results
- replace monospace font with main font & tabularFigures font feature

## [0.8.275] - 2023-02-26
### Changed:
- Refactor: use showModalBottomSheet for managing tags
- CI: retry on exit status 2
- Upgrade fl_chart library

## [0.8.274] - 2023-02-26
### Changed:
- More consistent app bar
- Reduce clutter in tasks header by moving count stats
- Upgraded dependencies
- Improved styling of about page

## [0.8.273] - 2023-02-24
### Changed:
- Upgraded dependencies
- Progress bar height and opacity
- Remove entry duration in journal card

## [0.8.272] - 2023-02-24
### Changed:
- Replace task progress indicator with material widget
- Editor toolbar styling

## [0.8.271] - 2023-02-23
### Fixed:
- Background color at the top of the survey bottom sheet
- Background color of survey dismiss dialog

## [0.8.270] - 2023-02-22
### Changed:
- Reduce clutter in entry card
- Upgraded dependencies

## [0.8.269] - 2023-02-20
### Changed:
- Replace modal_bottom_sheet lib with Flutter's own implementation
- Replace badges lib with Flutter's own implementation

## [0.8.268] - 2023-02-19
### Fixed:
- Habit fail button color
- Save button color
- Clipped save button on measurement page

## [0.8.267] - 2023-02-19
### Changed:
- Upgraded dependencies

## [0.8.266] - 2023-02-13
### Changed:
- Upgraded dependencies

### Fixed:
- Data capture dialog jumpiness
- Prevent dialog resize when save button becomes visible

## [0.8.265] - 2023-02-13
### Fixed:
- Navigate back icon on task page
- Unordered list color in editor
- Editor menu background color
- Chip style
- Primary material color

### Changed:
- Improved task input fields layout
- Improved chip layout
- Tweak spacing in journal filters
- Improved styling in settings
- Upgraded dependencies
- Tweak bottom navigation bar styling
- Darker link and success icon color in habits completion

## [0.8.264] - 2023-02-11
### Fixed:
- Audio playback restart on navigate to audio entry

### Changed:
- Improved input field layout

## [0.8.263] - 2023-02-10
### Changed:
- Refactoring: set main font in theme in one place
- Material Design 3 enabled

## [0.8.262] - 2023-02-10
### Fixed:
- Display of null title when completing habit

### Changed:
- Upgrade Flutter and dependencies

## [0.8.261] - 2023-02-09
### Fixed:
- Sleep data import
- Flights of stairs data import
- Total distance in interval data import
- Jumpy badge animation

## [0.8.260] - 2023-02-08
### Changed:
- Upgraded very_good_analysis lib

## [0.8.259] - 2023-02-08
### Changed:
- Use Flutter 3.7.1
- Latest health lib (breaks flights of stairs and sleep types)

## [0.8.258] - 2023-02-07
### Changed:
- Replace read-only flutter_quill with flutter_markdown for better scroll performance

### Fixed:
- Journal card text color when using bright theme

## [0.8.257] - 2023-02-06
### Fixed:
- Locking issue in sync

### Added:
- Settings DB

### Changed:
- Window manager persistence moved to settings database
- Routing persistence moved to settings database
- Last read UID persistence moved to settings database
- Improved logging

## [0.8.255] - 2023-02-02
### Changed:
- Upgrade dependencies

### Fixed:
- Keychain locking issue

## [0.8.254] - 2023-01-27
### Changed:
- Improved workout labels

### Fixed:
- Remove broken workout time health chart (workouts are a separate category now)

## [0.8.253] - 2023-01-25
### Changed:
- Upgrade dependencies - major versions

## [0.8.252] - 2023-01-25
### Fixed:
- Repeat tapping of mic overwrote old audio file
- Pop audio recorder as expected

Added:
- Pause icon in audio recorder functionality

## [0.8.251] - 2023-01-24
### Changed:
- Remove unused theme config widget
- Hide config flag: allow_invalid_cert

## [0.8.250] - 2023-01-24
### Changed:
- Remove redundant config flag: enable_beamer_nav
- Remove redundant config flag: listen_to_global_screenshot_hotkey
- Remove redundant config flag: show_tasks_tab
- Remove redundant config flag: hide_for_screenshot
- Remove redundant config flag: notify_exceptions

## [0.8.249] - 2023-01-23
### Changed:
- Differentiate between failed and missing habit completion
- Upgraded dependencies

## [0.8.248] - 2023-01-22
### Changed:
- Upgraded dependencies

### Fixed:
- Fix updating habit completion type

## [0.8.247] - 2023-01-20
### Changed:
- Audio recording lib replaced

### Added:
- Audio recording on macOS

## [0.8.246] - 2023-01-19
### Changed:
- Chore: redundant dependencies removed
- Chore: upgraded dependencies

## [0.8.243] - 2023-01-18
### Changed:
- Adaptive minY value in habit completion chart
- Toggle between zero-based and adaptive charts
- Upgraded dependencies

### Fixed:
- Habit completion percentages
- Show toggle for adaptive charts only when leading to discernible differences

## [0.8.242] - 2023-01-16
### Fixed:
- AppStore Connect warning

## [0.8.241] - 2023-01-15
### Fixed:
- Record audio note as comment to other entry types

## [0.8.240] - 2023-01-14
### Fixed:
- Text color for entry duration when timer running
- Fix possibility of accidentally overwriting task title, estimate, and status

## [0.8.239] - 2023-01-14
### Changed:
- Long press on entry type filter to select only one type
- Select all entry types toggle button
- Long press on task status filter to select only one status
- Select all task statuses toggle button

### Fixed:
- Add missing habit completion summary in entry detail view

## [0.8.238] - 2023-01-14
### Fixed:
- Code font color in text editor
- Consolidate monospace text styles

## [0.8.237] - 2023-01-14
### Fixed:
- Navigate back after entry deletion

## [0.8.236] - 2023-01-14
### Fixed:
- Unlinking entries

## [0.8.235] - 2023-01-13
### Added:
- Remove habit streaks section - not useful, streaks are apparent without
- Chore: upgraded dependencies

## [0.8.234] - 2023-01-13
### Changed:
- Journal card styling
- Entry type filter styling
- Task filter styling

## [0.8.233] - 2023-01-13
### Changed:
- Decluttered task view: only show editor toolbar on first focus
- Decluttered task view: only show tags in task comments when not equal to parent tags
- Show total time spent on a task
- Show task stats
- Task search header styling

## [0.8.232] - 2023-01-13
### Changed:
- Tasks by status can now be found in the journal tab
- Full-text search in tasks
- Tasks tab removed
- Task card navigation adapted
- CMD-R for reloading journal page
- Flagged entries count badge move into search header
- In-progress tasks count badge move into search header

### Fixed:
- Assigning tags to tasks

## [0.8.231] - 2023-01-12
- Fix keyboard dismissal in search field by always showing the X icon
- Fix clearing story selection in habit definition

## [0.8.230] - 2023-01-11
### Changed:
- Simplify settings by removing irrelevant favorite status switch in measurables (not used)
- Story time chart selections removed, will need to be simplified and/or rethought
- Dashboard notification time removed, will be handled better by notifications on habits, such as the habit of looking at a particular dashboard

## [0.8.229] - 2023-01-11
### Fixed:
- Update of JournalImage after change

## [0.8.229] - 2023-01-10
### Changed:
- Show popular values in capture dialog for past dates

## [0.8.228] - 2023-01-10
### Added:
- Full-text search database using FTS5
- Wire full-text database search (no refresh yet)
- Add tags in full-text search
- Add entities cache for faster lookup of measurable data types
- Use entities cache in measurement summary
- Refactor: move fetch logic to cubit
- Refresh results when typing in full-text search field
- Add new and updated text to full-text index
- Fix index creation maintenance task
- Remove previous entry in FTS5 index when updated
- One-step index recreation

### Fixed:
- Update JournalCard in infinite scroll automatically on change, e.g. after navigating back
- Clear query

### Changed:
- Upgraded dependencies

## [0.8.227] - 2023-01-07
### Changed:
- New search header in journal
- Upgraded dependencies

## [0.8.226] - 2023-01-07
### Changed:
- Declutter task form
- Simplified editor toolbar
- Unified searchable list
- Hide task title label when task defined
- Floating search bar replaced in settings
- Floating search bar replaced in journal

## [0.8.225] - 2023-01-06
### Changed:
- Improved text editor layout

## [0.8.224] - 2023-01-05
### Fixed:
- Disappearing keyboard on mobile
- Color theme in tag search

## [0.8.223] - 2023-01-04
### Changed:
- Consistently use light and dark keyboard types
- Upgraded dependencies

## [0.8.222] - 2022-12-31
### Changed:
- Limit editor height so that editor toolbar always stays visible

## [0.8.221] - 2022-12-30
### Changed:
- Fix completion rate by taking into account from when on to count a habit

## [0.8.220] - 2022-12-29
### Fixed:
- Screenshot delay
- Reduce allocations in sync

## [0.8.219] - 2022-12-28
### Changed:
- Disable smooth curved lines in habits chart: sharp lines are not overshooting
- Improved chart layout and CTA (tap chart for daily breakdown)

## [0.8.218] - 2022-12-27
### Changed:
- Journal page with infinite scroll

## [0.8.217] - 2022-12-26
### Changed:
- Improved blood pressure chart

## [0.8.216] - 2022-12-26
### Changed:
- Improved whitespace in habit page header
- Habit chart grid: lines at 20, 40, 60, 80, 100%
- Emphasized 80%-line (sensible minimum target)

## [0.8.215] - 2022-12-25
### Changed:
- Improved habit chart info on tap
- Clear habit chart info within 15 seconds

## [0.8.214] - 2022-12-24
### Added:
- Stacked habit success chart, with success, skipped, explicitly failed, implicitly failed

## [0.8.213] - 2022-12-23
### Added:
- Throttle habits success scoring
- Habit completions via click on habits success indicator

### Fixed:
- Condition where sync inbox could fail during processing and be skipped
- Performance issues when syncing health-related entries

## [0.8.212] - 2022-12-19
### Changed:
- Remove useless entry text toggle icon

## [0.8.211] - 2022-12-18
### Changed:
- Header position on image entries

### Fixed:
- Duplicate display issue
- Tag display issue in JournalCard

## [0.8.210] - 2022-12-17
### Changed:
- Improve line charts by using fl_chart library
- Improve blood pressure chart by using fl_chart library

## [0.8.209] - 2022-12-16
### Fixed:
- Habit completion percentage when private habits not shown

## [0.8.208] - 2022-12-15
### Added:
- Charts for habit skip and explicit habit success

## [0.8.207] - 2022-12-13
### Changed:
- Unlink icon in editor toolbar instead of using Dismissable

## [0.8.206] - 2022-12-11
### Added:
- Tooltips for habit completions, showing date

### Changed:
- Show habit streaks count at bottom of habits page, with labels
- Extract habit streak lists & use adaptive header
- Remove autofocus on measurement value field
- Unify segmented time span controls on dashboard and habit pages
- Increase analyzed habit completion time span to 90 days
- Show date in habit completion rate chart tooltip

## [0.8.205] - 2022-12-09
### Added:
- Chart for habit completion rate over time

### Changed:
- Improved whitespace in habit success indicators
- Improved habit completion rate tooltips

## [0.8.204] - 2022-12-07
### Added:
- Progress bar for habit progress for the current day

## [0.8.203] - 2022-12-05
### Added:
- Suggest last used value in measurable
- Upgrade dependencies
- More responsiveness in measurement creation

## [0.8.202] - 2022-12-01
### Added:
- Habit autocomplete rules editor experiments

## [0.8.201] - 2022-11-22
### Added:
- Show habit description during completion

## [0.8.200] - 2022-11-21
### Changed:
- Refactoring in habit definition page: move logic to cubit

## [0.8.199] - 2022-11-20
### Fixed:
- Show expected habit success from when defined

## [0.8.198] - 2022-11-20
### Added:
- Editor display toggle

## [0.8.197] - 2022-11-20
### Added:
- Habit autocomplete definition refinements
- Optional titles in habit rules
- Habit autocompletion type other habit rule

### Changed:
- New Flutter version & dependencies
- Habits displayed for last 30 days by default on both mobile and desktop

## [0.8.196] - 2022-11-10
### Changed:
- Define default story for habit completion entry

## [0.8.195] - 2022-11-08
### Changed:
- Record duration between opening habit and completing habit (unless date in the past is selected)

## [0.8.194] - 2022-11-08
### Changed:
- Audio playback speed toggle instead of individual icon button

## [0.8.193] - 2022-11-07
### Changed: 
- Upgraded dependencies
- Error handling in editor

### Added:
- CMD-S in task title field

## [0.8.192] - 2022-11-07
### Changed:
- Multiline comments and max width in habit capture dialog

## [0.8.191] - 2022-11-05
### Changed:
- Allow setting habit active or inactive
- Rename "active from" to "expect success from"

## [0.8.190] - 2022-11-04
- Flutter upgrade
- Upgraded dependencies

## [0.8.189] - 2022-10-30
### Fixed:
- Flicker in entry & task tag selection

## [0.8.188] - 2022-10-29
### Fixed
- Flickering keyboard issue when creating habit on mobile
- Flickering keyboard issue when creating measurable data type on mobile
- Flickering keyboard issue when creating dashboard data type on mobile

## [0.8.187] - 2022-10-29
### Changed:
- Flutter upgrade to 3.3.6

## [0.8.186] - 2022-10-29
### Changed:
- Improved habit completion add icon

## [0.8.185] - 2022-10-28
### Changed:
- Simplify sync outbox, remove faulty network connected check
- Add sync inbox tests for decrypting and writing image and audio files

## [0.8.184] - 2022-10-28
### Fixed:
- Update habits range after midnight

## [0.8.183] - 2022-10-27
### Added:
- Autocomplete habits data structure
- Skipping habit doesn't break the chain

## [0.8.182] - 2022-10-24
### Changed:
- Screenshot exception logging
- Retry IMAP actions with exponential backoff

## [0.8.181] - 2022-10-23
### Changed:
- Styling: entry icons
- Styling: colors

## [0.8.180] - 2022-10-23
### Changed:
- Move Sync inbox to separate isolate

## [0.8.179] - 2022-10-22
### Changed:
- Simplify sync by reusing IMAP client in one place
- Restart outbox client isolate on network reconnect

## [0.8.178] - 2022-10-21
### Changed:
- Upgraded dependencies
- Count habits total and finished today
- Count habit streaks of three days (up until yesterday) 
- Count habit streaks of one week (up until yesterday)
- Sections for longer and shorter streaks

## [0.8.177] - 2022-10-17
### Fixed:
- Bring back index creation in journal database
- Fix habit success indicator width

## [0.8.176] - 2022-10-16
### Fixed:
- "Task not found" when task still loading
- Spacing between habit success indicators

## [0.8.175] - 2022-10-16
### Added:
- Habit completion types success, skip, fail

## [0.8.174] - 2022-10-16
### Changed:
- Removed index creation in JournalDb for now

## [0.8.173] - 2022-10-16
### Changed:
- Improved photo view

## [0.8.172] - 2022-10-16
### Changed:
- Upgraded dependencies
- JournalDb moved to a separate isolate, freeing up CPU resources on the main thread/isolate

## [0.8.171] - 2022-10-13
### Changed:
- Sort habits by show from time, then a-z

### Fixed:
- Time chart didn't include today

## [0.8.170] - 2022-10-12
### Changed:
- Enable isolate support in JournalDb, SyncDb, LoggingDb
- Run SyncDb and LoggingDb in separate isolate (thread)
- Run Sync outbox in isolate to avoid jank

## [0.8.169] - 2022-10-11
### Changed:
- Upgrade Flutter to 3.3.4
- Upgrade dependencies

## [0.8.168] - 2022-10-10
### Changed:
- Entry details header icons

## [0.8.167] - 2022-10-08
### Changed:
- Delayed health import to improve scroll performance

## [0.8.166] - 2022-10-06
### Added:
- Health import for DISTANCE_WALKING_RUNNING

## [0.8.165] - 2022-10-06
### Changed:
- Increase measurement line chart height

### Fixed:
- Alignment of time axis between different types

## [0.8.164] - 2022-10-04
### Added
- Habits definition in Settings
- Add habit chart in dashboard
- Habits tab
- Habits grouped by open/completed
- Localize open/closed headers
- Add show from field

## [0.8.163] - 2022-10-01
### Changed:
- Audio recorder icons in dark mode

## [0.8.162] - 2022-10-01
### Changed:
- Active icons in surveys

## [0.8.161] - 2022-10-01
### Changed:
- Launch background color

## [0.8.160] - 2022-09-30
### Fixed:
- Sleep import on iOS

## [0.8.159] - 2022-09-29
### Added:
- Aggregation by hour in measurables charts

## [0.8.158] - 2022-09-29
### Changed:
- Colors adapted for dark mode
- VU meter in audio recording indicator removed

## [0.8.157] - 2022-09-29
### Changed:
- Segmented control for dashboard time span
- Style: dark mode
- Style: improved segmented control for dashboard time span

## [0.8.156] - 2022-09-26
### Changed:
- Charts hidden in journal cards
- New bottom navigation
- Measurement capture dialog style
- AppBar style with leading text
- Splash screen color
- Improved add icons in tasks, dashboards, measurables
- Hide audio recording indicator when on recorder page

### Fixed:
- Chart header cut off

## [0.8.155] - 2022-09-25
### Changed:
- Improve filling surveys by using modal_bottom_sheet lib
- Use showCupertinoModalBottomSheet instead of showModalBottomSheet

## [0.8.153] - 2022-09-25
### Fixed:
- Story assignment on mobile

## [0.8.152] - 2022-09-24
### Changed:
- DefinitionCard design
- Design: Settings > Tags
- Design: Settings > Dashboard Management
- Design: Settings > Measurables
- Consolidated settings cards

### Fixed:
- Health chart legend on select

## [0.8.151] - 2022-09-22
### Changed:
- Style: Inconsolata as monospace font
- New color theme in journal and tasks list
- New color theme in entry details

## [0.8.150] - 2022-09-20
### Fix:
- Bar overlapping domain axis

### Changed:
- Design tweaks in measurement capture
- Design tweaks survey capture
- Replace Lato font
- Empty dashboards page with how to use button
- Bar chart style

## [0.8.149] - 2022-09-18
### Added:
- Detect when desktop app is resumed in Sync

## [0.8.148] - 2022-09-18
### Changed:
- Dashboard chart header tweaks
- No hover color on IconButton elements on desktop
- Chart colors

## [0.8.147] - 2022-09-18
### Changed:
- Sync Conflicts layout
- Sync Conflicts resolution UI

## [0.8.146] - 2022-09-17
### Changed:
- Style: Icon alignment in Settings > Advanced
- Debug logging for Sync
- Style: barrier color in new measurement modal
- Style: add measurement icon
- Style: floating action button color
- Style: white app bar in dashboards
- Style: app bar redesign
- Style: remaining charts

## [0.8.145] - 2022-09-15
### Changed:
- Styling: Settings layout
- Styling: hover in Settings
- Styling: measurables chart
- Styling: survey chart
- Styling: health chart
- Styling: BP chart
- Styling: BMI chart

## [0.8.144] - 2022-09-13
### Changed:
- Move version and entry count to about page

## [0.8.143] - 2022-09-13
### Changed:
- Typography: use PlusJakartaSans in Settings
- Typography: use PlusJakartaSans in Settings > Tags
- Typography: use PlusJakartaSans in Settings > Dashboards
- Typography: use PlusJakartaSans in Settings > Advanced
- Typography: use PlusJakartaSans in Settings > Advanced > Maintenance
- Typography: use PlusJakartaSans in Settings > Config Flags
- Typography: use PlusJakartaSans in app bar
- Typography: use PlusJakartaSans in bottom navigation
- Hide icons in Settings
- White background in Settings
- White background in Dashboards List
- White background in Dashboards
- Chart title in black
- Move app version to Settings > About

## [0.8.142] - 2022-09-13
### Changed:
- Upgraded dependencies
- Assign story tag to comment entries as well

### Added:
- More tests for persistence logic

## [0.8.141] - 2022-09-12
### Changed:
- Flutter version upgrade
- Upgraded dependencies
- Sync reliability improvements

## [0.8.140] - 2022-09-08
### Fixed:
- Bottom sheet for tag selection overlaying the bottom nav bar

## [0.8.139] - 2022-09-07
### Changed:
- Upgrade dependencies

## [0.8.138] - 2022-09-06
### Added:
- Tests for surveys

## [0.8.137] - 2022-09-06
### Changed:
- Navigation: tap on open tab navigates to tab root

## [0.8.136] - 2022-09-05
### Changed:
- Upgraded dependencies
- Added tests for Audio Player widget
- Added tests for Audio Recorder widget

## [0.8.134] - 2022-09-02
### Changed:
- Upgraded dependencies
- Capture text with adding a measurement

## [0.8.133] - 2022-08-29
### Changed:
- Allow adding text in measurable entries
- Allow adding text in survey entries

## [0.8.132] - 2022-08-26
### Changed:
- Measurements captured in alert dialog, not modal
- Cross-tab navigation
- Navigate to dashboard from settings

## [0.8.131] - 2022-08-24
### Changed:
- Plus icon for adding measurement from dashboard instead of double tab
- Plus icon for filling survey from dashboard instead of double tab

## [0.8.130] - 2022-08-23
### Added:
- New navigation using beamer (in progress, available via config flag)
- Navigation in Settings > Tags using beamer
- Navigation in Settings > Dashboards using beamer
- Navigation in Settings > Measurables using beamer
- Navigation in Settings > Config Flags using beamer
- Navigation in Settings > Health Import using beamer
- Navigation in Settings > Advanced using beamer
- Navigation in Journal using beamer
- Navigation in Tasks using beamer
- Navigation in Dashboards using beamer

## [0.8.129] - 2022-08-17
### Changed:
- Copy SyncConfig to clipboard, encrypted with random one-time password
- Paste encrypted SyncConfig from clipboard & decrypt with one-time password

## [0.8.128] - 2022-08-11
### Fixed:
- Text wrap in config flags on small screen (e.g. iPhone 12 mini)

## [0.8.127] - 2022-08-11
### Changed:
- Navbar changed to Salomon style

### Fixed:
- Navigation glitch where the bottom nav bar was moving
- Error handling when page does not exist

## [0.8.126] - 2022-08-08
### Changed:
- Updated dependencies
- Inline code style in editor

## [0.8.124] - 2022-08-08
### Changed:
- Move dashboards page to left
- Change dashboards header
- Whitespace tweaks

## [0.8.124] - 2022-08-06
### Changed:
- Add toggle icon button for map visibility in entry header
- Remove map toggle in entry footer

## [0.8.123] - 2022-08-05
### Changed:
- Save running timer progress

## [0.8.122] - 2022-08-02
### Changed:
- Entry details layout

## [0.8.120] - 2022-08-02
### Fixed
- Crash in tags modal due to wrong context

## [0.8.120] - 2022-08-01
### Changed:
- Time record icon only on text entries

## [0.8.119] - 2022-07-30
### Changed:
- Decoupling of PersistenceLogic and widgets
- Decoupling of JournalDb and widgets

## [0.8.117] - 2022-07-28
### Changed:
- Show unsaved state after changing task title
- Save entries when navigating away
- Number format for selected measurement in chart
- Only show dashboard slideshow icon when multiple dashboards are defined
- Display more obvious entry save button
- Spacing in entry header

## [0.8.116] - 2022-07-26
### Fix:
- Build errors

## [0.8.115] - 2022-07-25
### Fixed:
- Sync resetting its own offset
- Polling

## [0.8.114] - 2022-07-21
### Added:
- Slideshow for dashboards

## [0.8.113] - 2022-07-20
### Added:
- Count duration for entries spanning multiple days for each individual day
- Weekly aggregation in story time charts

## [0.8.112] - 2022-07-19
### Changed:
- Improved query for substring matched stories

## [0.8.111] - 2022-07-17
### Changed:
- Time format hh:mm:ss in time charts for aggregate of selected day
- Time format hh:mm:ss in workout charts for aggregate of selected day

## [0.8.110] - 2022-07-15
### Added:
- Logging in sync

## [0.8.109] - 2022-07-15
### Changed:
- Improved whitespace in DateTime modal on mobile

## [0.8.108] - 2022-07-15
### Added:
- Wildcard matches in story charts

## [0.8.107] - 2022-07-14
### Fixed:
- Close photo button closes fullscreen photo

### Changed:
- Better close photo icon, in white with black shadow

## [0.8.106] - 2022-07-14
### Fixed:
- Duration display as absolute value

## [0.8.105] - 2022-07-14
### Added:
- Confirmation dialog when unlinking entry

## [0.8.104] - 2022-07-13
### Changed:
- Improved logging in sync

## [0.8.103] - 2022-07-13
### Changed:
- Improved time chart

## [0.8.102] - 2022-07-12
### Changed:
- Simplified & cleaner Inbox Service

## [0.8.101] - 2022-07-11
### Changed:
- Show duration

## [0.8.100] - 2022-07-10
### Changed:
- Show single dashboard directly without dashboards list page

## [0.8.99] - 2022-07-10
### Changed:
- Show bottom navigation bar in dashboard page

## [0.8.98] - 2022-07-10
### Fixed:
- Dashboard save button not appearing after reordering items

## [0.8.97] - 2022-07-10
### Changed:
- Simplified & cleaner Outbox Service

## [0.8.96] - 2022-07-08
### Changed:
- Longer IMAP timeouts for better support of flaky connections
- Fix toggle outbound sync in outbox monitor
- Config flags for enabling inbox and outbox
- Config flag for allowing invalid certificate (useful for testing, e.g. with [Toxiproxy](https://github.com/Shopify/toxiproxy))

### Added:
- Tests for measurement in journal
- Tests for health entry in journal
- Tests for dashboards measurement charts
- Tests for dashboards health charts
- Tests for dashboards workout charts
- Tests for logging page

## [0.8.95] - 2022-07-07
### Changed:
- Refactoring (no UI changes)

## [0.8.94] - 2022-07-07
### Changed:
- Upgraded dependencies

## [0.8.93] - 2022-07-06
### Added:
- Tests for journal page
- Tests for tasks page

## [0.8.92] - 2022-07-06
### Added:
- Tests for database and persistence logic

## [0.8.91] - 2022-07-05
### Added:
- Persistence of themes as JSON

## [0.8.90] - 2022-07-04
### Changed:
-Dependencies (no UI changes)

## [0.8.89] - 2022-07-04
### Added:
- Refactor theme management for color picker
- Config flag for color picker on desktop
- Basic theming config with color pickers on desktop
- Show previews and tap to expand/show picker in theme config
- Toggle theme config display via menu

## [0.8.88] - 2022-07-01
### Fixed:
- Hex color strings now parsed like CSS colors

## [0.8.87] - 2022-07-01
### Fixed:
- Timezone for notification

## [0.8.86] - 2022-07-01
### Added:
- Support for inline code in editor
- Support for strikethrough inline style in editor

## [0.8.85] - 2022-06-30
### Changed:
- FadeIn animation on new measurement page

### Fixed:
- Navigation pop after changing entry date
- Navigation pop after adding measurement
- Entry text color in for creating measurable

## [0.8.83] - 2022-06-30
### Fixed:
- Remove notifications for deleted dashboards

## [0.8.82] - 2022-06-29
### Added:
- Bright ☀️ color scheme with config flag
- Change️ color scheme from menu on desktop
- Add loading screen for dashboards, with animation

## [0.8.80] - 2022-06-27
### Changed:
- Use AppRouter mock in tests (no UI changes)

## [0.8.79] - 2022-06-27
### Changed:
- Dependency injection for SecureStorage (no UI changes)

## [0.8.78] - 2022-06-25
### Changed:
- Improve dashboards search width on desktop

## [0.8.78] - 2022-06-24
### Changed:
- Theme colors
- Whitespace in task card

## [0.8.77] - 2022-06-24
### Added:
- Tests for Settings (no UI changes)

## [0.8.76] - 2022-06-24
### Changed:
- Apple developer account for debug mode, for reasons ( ͡ಠ ʖ̯ ͡ಠ)
- Should not affect the build pipeline, current version simply tests the pipeline

## [0.8.75] - 2022-06-24
### Added:
- Tests for measurables detail page

## [0.8.74] - 2022-06-24
### Added:
- Faster measurement entry on desktop with autofocus and Cmd-S hotkey
- Widget tests for new measurement page (no UI changes)

## [0.8.73] - 2022-06-23
### Added:
- Widget tests for dashboard definition page (no UI changes)

## [0.8.72] - 2022-06-23
### Added:
- Link from new measurement page to respective measurable definition

## [0.8.71] - 2022-06-23
### Fixed:
- Line wrap for long title and description in dashboard definition card
- Line wrap for long description in dashboard page
- Line wrap for long title and description in measurement card
- Line wrap for long title in dashboard chart header

## [0.8.70] - 2022-06-23
### Changed:
- Show private status in dashboard card
- Show daily review time in dashboard card

## [0.8.69] - 2022-06-23
### Changed:
- Show unit name in measurement type card
- Show aggregation type in measurement type card

## [0.8.68] - 2022-06-23
### Changed:
- Leading insights icon in measurement card removed

## [0.8.67] - 2022-06-23
### Changed:
- Outbox monitor layout
- Outbox badge now displays larger counts

## [0.8.66] - 2022-06-21
### Added:
- Tests for Sync assistant widgets (no UI changes)
- Tests for OutboxCubit (no UI changes)

## [0.8.65] - 2022-06-20
### Changed:
- Remove aggregation label in chart when aggregation none
- Use aggregation none as default

## [0.8.64] - 2022-06-19
### Added:
- Tests for Sync assistant logic (no UI changes)
- Tests for Sync assistant widgets (no UI changes)

## [0.8.62] - 2022-06-18
### Changed:
- Guard Save button in new measurement by validation

## [0.8.61] - 2022-06-17
### Fixed:
- Saving tags and other form data

## [0.8.60] - 2022-06-17
### Changed:
- Fill survey directly from dashboard

## [0.8.59] - 2022-06-17
### Fixed:
- Save dashboard without daily review time filled out

## [0.8.58] - 2022-06-17
### Added:
- Workout type swimming

## [0.8.57] - 2022-06-16
### Fixed:
- Grey boxes in flagged entries that do not have text yet
- Header margin on mobile

## [0.8.56] - 2022-06-16
### Fixed:
- App bar when creating new entries

## [0.8.55] - 2022-06-16
### Changed:
- Improvements in Sync Assistant
- Prevent progression in Sync Assistant when not allowed

## [0.8.54] - 2022-06-14
### Added:
- Check valid mail account in sync assistant
- Check saved IMAP config in sync assistant

## [0.8.53] - 2022-06-13
### Added:
- App bar with save button in new measurement page
- Ignore chart interaction on journal card

## [0.8.52] - 2022-06-13
### Changed:
- Dev playground removed, not useful

## [0.8.51] - 2022-06-13
### Added:
- Search field for tasks in full width
- Search field for measurables in full width

## [0.8.50] - 2022-06-13
### Changed:
- Indicate unsaved changes on tag edit page
- Indicate unsaved changes on measurable data type edit page
- Indicate unsaved changes on dashboard edit page

## [0.8.49] - 2022-06-13
### Fixed:
- Timezone name on Linux

## [0.8.48] - 2022-06-13
### Fixed:
- Location on Linux

## [0.8.47] - 2022-06-12
### Changed:
- Improve first-time user experience for measurables

## [0.8.46] - 2022-06-12
### Changed:
- Improve layout of health data entry
- Improve layout of measurable data entry

## [0.8.45] - 2022-06-12
### Fixed:
- Sync of entities without vector clock
- Dashboards sorted alphabetically

### Changed:
- Optional description field in dashboard definitions
- Optional description and unit fields in measurable definitions

### Added:
- Maintenance task for reprocessing messages

## [0.8.44] - 2022-06-12
### Changed:
- Layout improvements in empty dashboards page

## [0.8.43] - 2022-06-12
### Changed:
- Allow dashboards with the same name
- Add maintenance task for purging deleted items

## [0.8.42] - 2022-06-11
### Changed:
- Auto-sizing text in Sync Assistant

## [0.8.41] - 2022-06-10
### Changed:
- Default IMAP folder for sync

## [0.8.40] - 2022-06-09
### Fixed:
- No health import on desktop

## [0.8.39] - 2022-06-09
### Changed:
- Ignore foreign messages in IMAP folder

## [0.8.38] - 2022-06-09
### Fixed:
- Romanian language support in forms

## [0.8.37] - 2022-06-09
### Changed
- Improved icons

## [0.8.36] - 2022-06-08
### Added:
- Screenshot from desktop menu

## [0.8.35] - 2022-06-08
### Changed:
- Save screenshots on desktop as JPG
- Improved icons

## [0.8.34] - 2022-06-08
### Added:
- French translation

### Changed:
- Improved Sync Assistant
- Trim fields in email config
- Label for Sync enable/disable

## [0.8.32] - 2022-06-07
### Added:
- Tooltips for circular add actions
- Fix hover UX

## [0.8.32] - 2022-06-07
### Fixed:
- Navigation issue

## [0.8.31] - 2022-06-04
### Changed:
- Define aggregation type for dashboard item

## [0.8.29] - 2022-06-02
### Added:
- Empty Dashboards instructions

### Changed:
- Delete dashboards confirmation in red
- Save and View button in dashboard definition removed

## [0.8.29] - 2022-06-01
### Added:
- Beginnings of a Manual

### Removed:
- Default measurable types

### Added:
- AppBars with matching titles for dashboard and measurable data type management

## [0.8.27] - 2022-06-01
### Changed:
- Improved UI in header

## [0.8.26] - 2022-05-31
### Fixed:
- Top margin for iPhone notch

## [0.8.25] - 2022-05-31
### Changed:
- Hide tasks tab unless config flag is set

## [0.8.24] - 2022-05-31
### Changed:
- Improve Search Header in Tasks

## [0.8.23] - 2022-05-31
### Changed:
- Improve Search Header in Journal

## [0.8.22] - 2022-05-31
### Changed:
- Show open, groomed & in-progress tasks by default
- Remove AppBar in Journal
- Show all types in Journal by default

## [0.8.20] - 2022-05-28
### Fixed:
- Bring back workout import

## [0.8.20] - 2022-05-28
### Fixed:
- Editor crashes

## [0.8.19] - 2022-05-25
### Added:
- Romanian localization

## [0.8.17] - 2022-05-22
### Fixed:
- Intra-day steps import

## [0.8.16] - 2022-05-22
### Added:
- Dashboard not found header, this becomes relevant after deleting a dashboard

## [0.8.15] - 2022-05-21
### Changed:
- Activity imports up to now

## [0.8.14] - 2022-05-21
### Fixed:
- Dashboard creation

## [0.8.12] - 2022-05-20
### Changed:
- Disable file sharing on iOS

## [0.8.11] - 2022-05-19
### Added:
- Persistence of editor drafts

## [0.8.9] - 2022-05-18
### Changed:
- Add task header

## [0.8.7] - 2022-05-17
### Changed:
- Add task stats header for task list

## [0.8.5] - 2022-05-16
### Changed:
- GitHub release for Linux from GitHub Action

## [0.8.4] - 2022-05-16
### Changed:
- Faster screenshots when no location in cache

## [0.8.3] - 2022-05-16
### Changed:
- Bottom Navigation Bar hidden in entry details
- Bottom Navigation Bar hidden in sync assistant
- Bottom Navigation Bar hidden in logging

## [0.8.2] - 2022-05-16
### Changed:
- Bottom Navigation Bar hidden in dashboards
- Dashboard title moved to app bar

## [0.8.1] - 2022-05-15
### Changed: 
- Upgrade to Flutter 3.0.0

## [0.7.38] - 2022-05-12
### Added:
- Min and Max weight in BMI chart range
- Only allow charts to shift back, not forward

## [0.7.37] - 2022-05-11
### Added:
- Disable panning while zoom is ongoing

## [0.7.36] - 2022-05-11
### Added:
- Horizontal Chart Zoom
- Horizontal Chart Panning

## [0.7.33] - 2022-05-11
### Added:
- Hide inactive dashboards

## [0.7.32] - 2022-05-11
### Added:
- Inherit private status from linked

## [0.7.31] - 2022-05-11
### Added:
- Dark keyboard on iOS

## [0.7.30] - 2022-05-11
### Fixed:
- Zero wait for location on entry create, will be added later when available

## [0.7.29] - 2022-05-10
### Fixed:
- Tabs routes are now restored on application restart

## [0.7.28] - 2022-05-05

### Fixed:
- Audio playback for multiple recordings in list of linked entries was not 
  working previously

## [0.7.22] - 2022-04-28
### Added:
- Haptic feedback for setting/unsetting starred/private/flagged statuses

## [0.7.19] - 2022-04-28
### Fixed:
- Footer spacing on mobile

## [0.7.18] - 2022-04-27
### Added:
- Share image and audio files from share button in entry footer

### Changed:
- Removed audio file sharing from audio player

## [0.7.17] - 2022-04-27
### Added:
- Share audio recordings

## [0.7.16] - 2022-04-27
### Added:
- No autofocus on task text

## [0.7.15] - 2022-04-27
### Added:
- Adaptive max height for images

## [0.7.14] - 2022-04-27
### Fixed:
- Code signing on macOS leading to crash on startup

## [0.7.13] - 2022-04-26
### Fixed:
- No sync calls when not configured

## [0.7.11] - 2022-04-26
### Fixed:
- Linux entry persistence crash fix

## [0.7.10] - 2022-04-26
### Added:
- Sync settings: hide sensitive info
- Sync settings: select IMAP folder
- Styling: shadow on navigation bar
- Sync assistant

### Changed:  
- Task form styling
- Unfocus on save only on mobile
- Sync IMAP messages marked seen
- Sync IMAP messages in lotti_sync folder
- Styling: entry card color

## [0.7.9] - 2022-04-25
### Changed:
- Text color in sync settings
- Unfocus on save
- Entry styling

## [0.7.8] - 2022-04-24
### Added:
- New color scheme
- Text editor in slideshow for faster import

## [0.7.7] - 2022-04-24
### Added:
- Added flutter_image_slideshow

## [0.7.6] - 2022-04-22
### Added:
- Release to TestFlight via fastlane
- Added fastlane-plugin-changelog
- Populating release notes/what to test from CHANGELOG
- Added fastlane match
- Added GitHub Actions setup

## [0.7.5] - 2022-04-21
### Added:
- Added `make` tasks for TestFlight upload
