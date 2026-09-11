### Changed
- **AI requests that hit a provider's rate limit now retry instead of
  failing.** The OpenAI-compatible client Lotti uses to talk to OpenAI,
  OpenRouter, Anthropic and other compatible providers was eight major
  versions behind. On the new client a request the provider turns away with
  "too many requests" is retried up to three times, waiting a little longer
  each time, so a busy moment at the provider no longer surfaces as a failed
  summary, transcription or agent run. Everything else about how Lotti talks
  to those providers is unchanged.
