### Fixed
- **Older synced preferences could replace a newer local choice.** Theme mode
  and greeting-name edits now save their version before syncing, advance past
  previously received versions, and publish only successfully saved values.

- **Synced settings toggles agree when updates arrive out of order.** Updated
  devices keep the same winning toggle and description, and failed saves no
  longer expose a change that was rolled back.

- **Sync no longer advances past a newly reported history gap.** New payloads
  wait for their response’s recovery boundary, while attachment downloads
  continue immediately.
