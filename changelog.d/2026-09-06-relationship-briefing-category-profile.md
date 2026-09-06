### Fixed
- **"Brief me" on a person's page failed with "Could not request the
  briefing."** The relationship agent only looked for an AI route on the
  person themselves or on its own configuration — neither of which any screen
  sets — and otherwise insisted on one specific cloud model. It now also uses
  the default AI profile of the person's category, the same way a spoken
  check-in already picks its transcription model, so a briefing works with
  whatever profile you route that category through. A cloud provider is still
  named for consent before the run.
