### Fixed
- **Older categories, dashboards, habits and links now sync like everything
  else without a manual repair.** Items saved before sync tracked their
  versions used to need "Repair vector clocks" on one device; every device
  now does this once by itself when the app starts.
- **A feature flag changed right after an update no longer flips back on
  your other devices.** A change queued by the previous version could
  arrive after the newer one; the older change is now dropped.
