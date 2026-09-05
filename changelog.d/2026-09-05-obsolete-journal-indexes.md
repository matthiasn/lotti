### Fixed
- **Long-standing installs carried up to seventeen obsolete indexes on the
  journal table.** Databases created before autumn 2025 kept every
  single-column index the original schema had, even though later versions
  stopped using them, and never gained the two date indexes newer installs
  have. Every save paid to maintain the extras. The upgrade now brings the
  indexes of an old database in line with a fresh install, and every future
  upgrade re-checks them.
