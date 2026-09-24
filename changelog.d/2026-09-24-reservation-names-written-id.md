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
