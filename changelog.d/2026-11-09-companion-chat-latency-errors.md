### Fixed
- **The companion says why an answer did not come.** A failed question used to
  show only "That didn't send." Now the line beside *Try again* names the
  cause: your AI provider is limiting requests, took too long, cannot be
  reached, refused its API key or answered with an error, no model is set up
  for the companion, or it could not finish an answer.
- **The companion answers faster, and a stuck answer no longer hangs.** Her
  requests share one prompt cache with the AI provider, which roughly halves
  the wait once it is warm. A request that sends nothing for 15 seconds is
  sent once more instead of waiting minutes.
- **"Last weekend" means the weekend just past.** Asked on a Monday, questions
  about last weekend's pull requests, logged time or completed tasks were
  sometimes answered for the weekend before.
