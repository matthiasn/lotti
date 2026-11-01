### Fixed
- **Embeddings of tasks with a private label now reach every device.** A
  device that hid private items built such a task's searchable text without
  the label, so the embeddings another device shared for it never matched and
  waited there for good — the embedding counts differed while Sync health
  reported nothing missing. Every device now builds the same text, re-embeds
  the affected tasks on start, and Sync health shows any embeddings still
  waiting for their entry under the embedding count.

### Changed
- **Tasks are found by their whole agent report.** Search by meaning now
  covers a task report's one-liner and TLDR as well as its body, from the
  task's next report on.
