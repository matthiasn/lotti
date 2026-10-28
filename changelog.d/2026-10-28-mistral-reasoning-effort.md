### Added

- **Mistral models with adjustable reasoning can think before answering.**
  Mistral Small, Medium 3.5 and Large 4 get a *Think before answering* switch
  on their model page: on, they work through the problem first, which gives
  deeper answers, but they are slower and use more tokens. Quick background
  summaries still ask for a fast answer.

### Fixed

- **Mistral's reasoning now shows in agent internals.** Its thinking used to be
  thrown away; it now appears as thoughts, as it does for Gemini and Ollama.
- **Mistral reasoning models were run hotter than Mistral recommends.** They
  were sent the temperature OpenAI's reasoning models need; they now keep their
  normal temperature.
