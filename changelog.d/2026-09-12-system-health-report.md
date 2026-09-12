### Added
- **A System health tool in Settings → Advanced writes a shareable log report.**
  Pick a time range, keep or adjust the logging domains, and Lotti reads its
  own log files, replaces known personal-data patterns — emails, ids,
  tokens, IP addresses, file paths with your user name — with placeholders,
  takes error text only from the PII-safe error log, and asks the AI model
  of your choice for the three findings most worth fixing, slow database
  queries included. One tap copies the report as
  Markdown, ready to paste into a coding assistant or a bug report.

### Fixed
- **Model pickers no longer show a stale list after you add or remove
  models.** The shared catalog behind the agent, Daily OS and System health
  pickers now follows changes to models, providers and profiles as they
  happen, including ones arriving through sync, instead of holding the list
  it loaded at app start.
