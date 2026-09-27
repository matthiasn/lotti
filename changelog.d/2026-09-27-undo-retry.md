### Fixed
- **Undoing a person's suggested task could get stuck.** If something went
  wrong partway through undoing a task a relationship suggestion had created,
  the task was already deleted but the suggestion still showed as accepted,
  and trying Undo again did nothing. Trying again now finishes the Undo and
  puts the suggestion back up for a decision. A task you changed before it
  was deleted is still left alone.
