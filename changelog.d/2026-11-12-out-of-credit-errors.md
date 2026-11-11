### Fixed
- **An AI provider account that ran out of credit now says so.** An empty
  prepaid balance or a reached spend limit used to read as a rate limit
  ("wait a moment, then try again"), a bad request or a bare "That didn't
  send." Lotti now recognises the out-of-credit answers of OpenAI, Anthropic,
  OpenRouter, Mistral, Gemini, Melious, Alibaba Cloud and ElevenLabs. The AI
  error panel and the companion, goal and person chats show the provider's own
  words, so you can see which account to top up, and background agents stop
  retrying every few minutes against an empty balance.
