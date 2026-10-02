### Fixed
- **Semantic search kept finding text that was no longer there.** A deleted
  entry, or one shortened to a few words, kept its old search vector, so its
  old wording still found it — and still pulled up the task it belonged to.
  Its vectors are now removed, and a deleted entry no longer surfaces its task.
- **Entries edited while Ollama was unreachable were never indexed for
  search.** Every change made during an outage was dropped after one failed
  attempt. Failed entries are now retried once the endpoint is back.
- **Search could keep an entry's older wording after an edit.** When a manual
  re-index and the background indexer handled the same entry around an edit,
  the slower one could store the version from before the edit, and nothing
  corrected it. Each entry is now indexed by one run at a time, so the last
  run always reads the latest text.
- **A task agent's report could stay filed under a task's old category.** A
  report written while the task moved category, or belonging to a task with a
  title too short to index, stayed out of category-filtered search results.
  Reports now follow their task.
- **After a crash, search could fall back to an entry's older text.** An
  entry caught mid-way between two category indexes was restored from
  whichever index sorted last by name; the most recently written copy is now
  kept.
