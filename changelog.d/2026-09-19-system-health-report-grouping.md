### Fixed
- **A reopened System health report kept its findings and digest apart.** When
  the model's findings contained a collapsed section of their own, the report
  shown after a restart split at that section, so part of the findings landed
  inside the collapsed digest. The report now splits at the digest's own
  section.
- **System health groups more repeats of the same slow query together.** A
  query listing numbers, such as `IN (1, 2, 3)`, or a quoted value with an
  apostrophe in it, used to count as a new query for every different list, so
  one busy query was spread over several rows. These now land in one row with
  their combined count and timings.
