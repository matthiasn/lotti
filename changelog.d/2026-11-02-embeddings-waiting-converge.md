### Fixed
- **Sync health could show "Embeddings waiting" stuck at a number that never
  went down, and one device a few embeddings more than the other.** A device
  kept waiting for the text of a deleted entry, or of a report whose task was
  deleted, which would never come — and the device that still held those
  embeddings kept counting them. Embeddings for deleted entries are now
  dropped instead of waited for. Each start also brings the device's own
  embeddings up to date: it removes those of deleted entries and of deleted
  tasks' reports, and embeds again the tasks whose text changed without an
  edit, such as a renamed label. The waiting count and the totals on your
  devices settle to match.
