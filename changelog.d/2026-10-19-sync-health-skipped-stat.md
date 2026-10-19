### Changed
- **Sync health no longer flags skipped messages as a problem.** The count of
  skipped sync messages sat in the top row in red, beside an alert icon, as
  though something urgently needed fixing. It counts Matrix messages, not
  entries, and a large number is normal. The top row now shows only the
  inbound queue and missing entries, and the skipped count is a plain line in
  the Sync statistics card. Retry skipped events is still under Advanced
  recovery.
