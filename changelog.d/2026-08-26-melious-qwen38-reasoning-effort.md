### Fixed

- **Qwen 3.8 models on Melious.ai no longer fail with a "malformed request" error.**
  Qwen 3.8 Max and Qwen 3.8 27B require a reasoning-effort setting that Lotti was
  not sending, so every request to them was rejected before it reached the model.

### Added

- **Qwen 3.8 Max and Qwen 3.8 27B ship as Melious.ai defaults.** Both are
  available as soon as a Melious provider is added, without browsing the full
  remote catalog. Qwen 3.8 27B also handles image input.
