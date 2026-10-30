### Fixed
- **Reading aloud with a Mistral Voxtral voice works again.** Every attempt
  ended in a bare "Error", and Speech settings said the voices could not be
  loaded, because the voice list was requested in pages larger than Mistral
  accepts. The voices now load, and a failure the provider reports is logged
  with the provider's own reason.
