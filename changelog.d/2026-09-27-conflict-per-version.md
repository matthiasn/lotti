### Fixed
- **An edit saved while another device's change was syncing in could vanish
  for good.** If an entry changed on another device while you had it open,
  your save was held back as a sync conflict for you to decide. When a third
  version arrived before you had resolved it, that conflict was replaced and
  your edit was lost on every device, with no warning. Each version now keeps
  its own conflict. An entry can appear more than once under Settings →
  Advanced → Conflicts, and you decide one version at a time.
