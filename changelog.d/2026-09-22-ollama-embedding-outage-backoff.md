### Fixed
- **With local embeddings on and Ollama not running, Lotti kept retrying it.**
  Every changed entry, backfill item, agent report and semantic search tried
  to reach Ollama on its own, sat through the full set of retries, and wrote
  another error to the log. Lotti now notices the outage once, stops trying for
  five minutes, and then lets one shared check through before anything else
  tries again. Semantic search fails right away in the meantime instead of
  hanging, and a long outage adds only a few lines to the log.
