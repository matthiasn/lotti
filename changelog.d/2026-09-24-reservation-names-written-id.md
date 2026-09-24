### Fixed
- **A task, AI response or person created under a fixed id could stay off
  your other devices after the app was closed at the wrong moment.** Tasks an
  agent creates for a person, AI responses from skills, and people added from
  your contacts are saved under an id chosen in advance. The sync bookkeeping
  for that save recorded a different id. If the app quit after saving but
  before the item was queued for sync, the next start looked for the wrong
  item, found nothing, and told your other devices the save never happened.
  The bookkeeping now records the id the item is saved under. On the next
  start after such a quit, the item is sent to your other devices.
- **Recovering a damaged database could throw away the changes its backup
  was missing.** When the app finds a database it can no longer read, it
  restores the latest backup and sets the damaged file aside, together with
  the log of changes made since that backup, so those changes are not lost.
  The check that found the damage could delete that log while the restore was
  running. It no longer touches the log, so it is kept with the damaged file.
