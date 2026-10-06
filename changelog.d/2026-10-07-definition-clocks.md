### Fixed
- **Categories, labels, habits, dashboards, measurables and dictionary terms
  no longer go missing on a synced device.** Each change to one now carries
  its place in the order of changes, so a device that missed it asks for it
  and gets it back, as it already does for entries. When two devices change
  the same one at once, both keep the later change, whichever arrives first,
  and a change made on a device whose clock runs behind still replaces the
  version it was made from.

### Changed
- ***Repair vector clocks* now covers settings definitions too.** Running it
  once, on any one device, brings categories, labels and the other
  definitions saved before this update into the same order; until then they
  sync as before.
