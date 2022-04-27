# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
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
