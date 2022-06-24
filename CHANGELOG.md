# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
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
