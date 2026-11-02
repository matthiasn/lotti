### Changed
- **A task's agent reads its linked tasks deeper when it needs to.** It used
  to see a short summary of every linked task on each run, however many there
  were. It now sees each linked task's one-line summary, and reads that task's
  longer summary or its full report only when the one line is not enough —
  to follow a blocker, say. A task with dozens of links no longer floods the
  agent: it sees the open and newest ones first and is told how many it left
  out.
