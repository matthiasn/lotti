### Fixed
- **Search now finds what arrived from your other devices.** Entries, tasks
  and recordings that came in by sync were never added to the search index,
  so on a phone that mostly receives its journal, search came up empty until
  the index was rebuilt by hand. Everything is indexed as it arrives now,
  whichever device wrote it, and after this update the index rebuilds itself
  once in the background.
- **Typing an apostrophe, a hyphen or a quote no longer breaks search.**
  Searching for something like "don't" or "self-care" could fail and show
  nothing at all. Every search is read as plain words now.

### Changed
- **Search keeps up while you type and ignores accents.** The word you are
  typing matches as soon as it starts — "pengu" finds "penguin" — and
  "Sudpol" finds "Südpol". Checklist items, projects, goals, events, pull
  requests and recording transcripts are searchable too, and the task picker
  and the assistants get the best matches first, with title matches ahead of
  matches in the text.
