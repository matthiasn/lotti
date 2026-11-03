### Fixed
- **Mistral calls recorded no cached or reasoning tokens.** Mistral reports how
  many prompt tokens it served from its cache, and how many the model spent
  reasoning, but the app only kept the input, output and total counts, so an
  agent running on Mistral always showed zero cached tokens. Both counts are now
  recorded with every Mistral call.

### Added
- **Agent token usage shows a cache hit rate.** Next to the cached token count,
  each model's row now shows what share of its input was served from the
  provider's cache — the part that is billed at a lower rate.
