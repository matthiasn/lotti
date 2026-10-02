### Fixed
- **A device that fell far behind could fail to ask for the entries it was
  missing.** When it noticed hundreds of missing entries at once, it put them
  all into one request that was too large to send. Every attempt failed the
  same way until the request was dropped, so those entries could stay missing.
  Large requests are now split into pieces that each fit.
