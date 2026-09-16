### Fixed
- **DeepSeek models no longer skip a required briefing, report or day plan.**
  When an agent had to insist on one particular tool, the request pinned that
  tool — and DeepSeek answered with the call written as text, which the app
  could not see, so the wake ended with nothing saved. The app no longer pins
  the tool for those models, and the retry lands.
