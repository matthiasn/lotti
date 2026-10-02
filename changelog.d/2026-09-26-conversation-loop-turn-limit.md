### Fixed
- **An agent could keep calling the model without end.** Once a wake's tool
  calls filled the conversation history, trimming the history also rolled back
  the count of turns taken, so a model that kept calling many tools a round
  never reached the wake's turn limit and kept spending. Turns are now counted
  however the history is trimmed. Long conversations are also sturdier: after
  a trim the history no longer opens on a tool call, which Gemini rejected; a
  tool that failed part-way no longer leaves calls unanswered, which made the
  next message fail; tool-call ids no longer repeat; and messages sent into one
  conversation at the same time now take their turns one after the other.
