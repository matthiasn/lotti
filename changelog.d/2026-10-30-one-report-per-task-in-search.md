### Fixed
- **Semantic search no longer finds a task by an agent report it outgrew.**
  When a task agent's report could not be indexed for semantic search — the
  local embedding server was unreachable, or the report was very short — the
  report before it stayed in the index for good, so a task could turn up for
  what its agent said months ago. Each task now keeps only its latest
  indexed report there.
