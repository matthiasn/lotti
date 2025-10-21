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
  - Matrix Sync Settings: `/settings/sync/matrix`
    - Launches the existing multi-step Matrix setup/login modal
    - Maintenance tools: `/settings/sync/matrix/maintenance`
      - Delete Sync Database
      - Sync definitions (tags, dashboards, habits, etc.)
      - Re-sync messages
  - Outbox Monitor: `/settings/sync/outbox`
  - Matrix Stats: `/settings/sync/stats`
  - Conflicts: linked from Sync, still routed under advanced paths

## Advanced section

- Advanced excludes Matrix/Outbox entries; those live under Sync.
- It includes Logs, Health Import (on mobile), Maintenance, and About.
- Maintenance now focuses on app-level tasks (database cleanup, purge deleted items, hint resets, AI suggestion cleanup) plus the FTS5 rebuild.
- Matrix-specific maintenance (Sync DB deletion, resync, definitions) lives under Sync.

## Routing

- Beamer location: `lib/beamer/locations/settings_location.dart`.
- Sync routes use exact path matching for robustness as more sub-routes are
  added over time.
