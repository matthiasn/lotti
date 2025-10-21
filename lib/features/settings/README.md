# Settings Module

This module contains the Settings experience and its feature pages.

## Overview

- The Settings landing page surfaces top-level entries including AI Settings,
  Categories, Tags, Dashboards/Measurables, Theming, Feature Flags, and
  Advanced Settings.
- Sync now appears as a top-level entry at `/settings/sync` and is only
  visible when the Matrix sync feature flag is enabled.

## Sync section

- Sync Settings: `/settings/sync`
  - Matrix setup/login (modal)
  - Outbox Monitor (moved from Advanced): `/settings/sync/outbox`
  - Matrix Stats (full page): `/settings/sync/stats`
  - Conflicts: linked from Sync, still routed under advanced paths

## Advanced section

- Advanced no longer contains Matrix or Outbox tiles.
- It includes Logs, Health Import (on mobile), Maintenance, and About.

## Routing

- Beamer location: `lib/beamer/locations/settings_location.dart`.
- Sync routes use exact path matching for robustness as more sub-routes are
  added over time.

