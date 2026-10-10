### Fixed
- **Deleted dashboards and measurables, and removed links, stay deleted on
  every device.** Cleaning up deleted entries used to erase deleted
  dashboards and measurable types outright, so a device that still held an
  old copy could bring them back. A link changed to another type could
  likewise reappear under its old type when a late copy arrived. Both now
  stay gone.
- **Confirming a relationship suggestion again after undoing it restores
  the same task.** Before, it created the task over the undone one in a way
  other devices showed as a conflict, and after a cleanup it could not
  bring the task back at all.
- **Sync no longer asks other devices over and over for the records of an
  agent you deleted.**
