### Fixed
- **A new agent report could stay hidden behind the previous one.** When a
  report was written for the same overdue day as the one already shown, or
  another device's clock ran ahead, the new report was saved but the agent
  kept showing the old one on every device. A new report now replaces the
  one it was written after.
- **An edited personality or template could keep using the old version.**
  When another device's clock ran ahead, saving a new version left the agent
  on the previous one. The saved version now takes effect.
