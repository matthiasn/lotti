### Fixed
- **A deep backfill no longer re-sends old links on every run.** Links saved
  before links carried a sync clock were left out of the list a device sends,
  so the other device took them for missing there and sent all of them back —
  thousands of messages, every time, changing nothing. They are now listed as
  what they are, and never sent back for that reason.
- **Repair vector clocks now covers entry links too.** *Settings → Sync →
  Backfill sync → Advanced recovery → Vector clocks* gives links saved before
  links carried a clock one, as it already did for agent records, so they sync
  and compare like everything else. Run it once on each device.
