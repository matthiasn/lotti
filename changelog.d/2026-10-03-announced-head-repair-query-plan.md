### Fixed
- **Saving agent work could stall while sync looked for missing entries.**
  Each check for entries another device had announced but not yet delivered
  read that device's whole sync history, taking up to most of a second on a
  long-used desktop while other writes waited. It now reads only the entries
  still waiting to arrive.
