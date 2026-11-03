### Fixed
- **Sync health could keep showing "Embeddings waiting: 1" on one device
  while the embedding totals on both devices matched.** After you deleted an
  agent on that device, its reports were gone there, but another device
  still shared new embeddings for them. The device waited for a report that
  would never come back. Those embeddings are now dropped instead of waited
  for, and the count goes back to zero.
