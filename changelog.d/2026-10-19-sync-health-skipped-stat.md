### Changed
- **Sync health no longer flags skipped messages as a problem.** The count of
  skipped sync messages sat in the top row in red, beside an alert icon, as
  though something needed fixing. Those are Matrix messages that are gone, not
  entries, and there is nothing to do about them. The top row now shows only
  the inbound queue and missing entries, and the skipped count is a plain line
  in the Sync statistics card.
