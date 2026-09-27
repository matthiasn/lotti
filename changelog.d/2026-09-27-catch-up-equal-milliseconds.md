### Fixed
- **Catch-up after a sync gap could skip a change that arrived in the same
  millisecond as another.** When several synced changes carried the same
  server timestamp and some of them were missed live, catch-up could start or
  stop inside that millisecond and never fetch the rest. Only the periodic
  backfill between devices would recover them, later. Catch-up now covers the
  whole boundary millisecond.
