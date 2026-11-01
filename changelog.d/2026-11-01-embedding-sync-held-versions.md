### Fixed
- **Embeddings shared between devices now arrive in full.** A device never
  stored the embedding of a task's current agent report that another device
  shared, nor that of a task with a private label while it hid private items:
  both waited for good, so the embedding counts differed while Sync health
  reported nothing missing. Both now store, the affected tasks are re-embedded
  on start, and Sync health shows any embeddings still waiting under the
  embedding count.

### Changed
- **Tasks are found by their whole agent report.** Search by meaning now
  covers a task report's one-liner and TLDR as well as its body, from the
  task's next report on.
