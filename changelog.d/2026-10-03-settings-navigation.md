### Fixed
- **Leaving Matrix sync maintenance no longer shows Sync Settings twice.** On
  a phone, going Settings → Sync → Matrix sync maintenance and then pressing
  back twice slid Sync Settings in a second time instead of returning to
  Settings. Every settings page now names the page it returns to, so each
  back press moves up exactly one level.
- **Backing out of Conflicts returns to Sync.** Conflicts is listed under Sync,
  but on a phone the back button took you to Advanced Settings instead.
- **What's New opens from the desktop settings tree.** Selecting it showed a
  "not yet implemented" placeholder; it now opens the release notes, as it
  already did on phones.
- **Desktop settings lists no longer repeat their own title.** Categories,
  Labels, Habits, Dashboards, Measurables, the sync Outbox and Conflicts, and
  AI Usage each showed their name twice — once in the breadcrumb above the
  pane and again as a header inside it. The repeat is gone, and the create
  button of a definition list now sits beside its search field.
