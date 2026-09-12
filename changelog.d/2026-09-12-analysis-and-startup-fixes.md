### Fixed
- **Image analysis no longer fails when its short summary is invalid.** The
  full analysis is preserved when an AI response has an overlong one-line
  summary or an invalid TLDR, instead of reporting an empty response.
- **Startup does less database work when many agents are present.** Clearing
  old wake countdowns now shares a bulk read and transaction instead of
  opening a separate transaction for every agent, including idle ones.
