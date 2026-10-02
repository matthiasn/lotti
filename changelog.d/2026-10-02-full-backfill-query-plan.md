### Fixed
- **A manual full sync backfill could hang for seconds before it started.**
  Each batch of missing entries was found by reading the whole sync history
  instead of only the entries still waiting to arrive, which took over four
  seconds on a long-used desktop. It now reads only those entries.
