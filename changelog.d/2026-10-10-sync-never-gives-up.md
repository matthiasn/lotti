### Fixed
- **Catching up after a gap no longer stops trying.** When fetching the
  messages a device missed kept failing, sync gave up after three tries and
  waited for something else to wake it, which on a quiet account might not
  happen. It now keeps trying, waiting a little longer each time, up to five
  minutes.
- **"Send settings" now also repairs your theme, your Daily OS greeting name
  and your feature flags.** These were sent once when you changed them, so a
  lost message left another device on the old value. A device that already
  holds a newer value keeps it.
- **A sync message an older version of the app could not read is read once
  the app is updated.** Before, such a message, like a saved filter using an
  option from a newer version, was skipped for good.
- **A very large single change now reaches your other devices.** A change
  too big for one sync message used to fail for good; it now travels as a
  compressed attachment instead.
