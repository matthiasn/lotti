### Fixed
- **Recording summaries failed with DeepSeek.** DeepSeek can send its answer in
  small pieces, and each piece was read as a separate, unnamed answer, so the
  summary was rejected twice and never saved. The pieces are now put back
  together, and recordings summarise with DeepSeek just as they do with Mistral
  or GLM.
