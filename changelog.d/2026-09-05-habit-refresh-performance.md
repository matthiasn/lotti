### Fixed
- **Habit history refreshes do less work during sync.** Bursts of completion
  updates now share database reads, older results cannot replace a newer range,
  and long histories load their winning daily completions more efficiently.
