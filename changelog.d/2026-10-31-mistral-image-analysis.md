### Fixed
- **Image analysis with a Mistral vision model failed straight away.** With
  Mistral Large 4 (or another Mistral vision model) as a profile's Image
  Recognition model, every analysis stopped with "type 'List<dynamic>' is not a
  subtype of type 'String?'". Mistral sends its answer in pieces the generic
  client could not read; image analysis now goes through Lotti's own Mistral
  client, the one text generation already uses, and shows the description.
- **Mistral Large 4 refused requests with "Think before answering" off.** Lotti
  asked it for no reasoning, a setting Large 4 does not accept, so every request
  came back as HTTP 400. Large 4 now gets its lowest reasoning level instead,
  and its middle level when one is asked for; Mistral Small and Medium are
  unchanged.
- **Large photos could be too big to analyze.** An image wider or taller than
  2,000 pixels, or larger than 5 MB, is now scaled down for the upload only;
  the photo in your journal keeps its full size. A failed Mistral request now
  also names Mistral's reason (its error type and code) in the error.
- **Analyses from reasoning models could include the model's thinking.** An
  image analysis or summary written by a model that reasons out loud, such as
  Mistral's Magistral, was saved with its reasoning in `<think>` tags; it is
  now saved without it. Mistral's "Think before answering" switch also now
  applies to these analyses and summaries, not just to chat.
