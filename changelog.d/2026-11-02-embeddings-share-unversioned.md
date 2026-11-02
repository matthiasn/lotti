### Fixed
- **Embeddings made while embedding sync was off never reached your other
  devices.** Entries embedded before you turned embedding sync on, or before
  this kind of sync existed, stayed on the device that embedded them, so your
  other devices could not find those entries by meaning. They are now sent on
  the next start, and again whenever embedding sync is turned on.
