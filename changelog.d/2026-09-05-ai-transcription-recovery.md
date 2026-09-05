### Fixed
- **Long recordings can be transcribed through Melious.** Recordings that
  exceed its upload limit are sent as smaller temporary audio segments and
  combined into one transcript, leaving the original recording unchanged.
- **Mistral's default transcription model uses the correct API.** Existing
  Voxtral Mini configurations now use its dedicated transcription endpoint.
- **Melious image summaries retain their requested structure.** Collecting
  usage and cost no longer drops the required summary tool selection.
