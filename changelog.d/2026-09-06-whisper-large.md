### Added
- **Whisper Large v3 is available for on-device transcription.** Download the
  full multilingual model from the sherpa-onnx provider settings and select it
  for transcription. The INT8 download is about 1.78 GB.

### Changed
- **On-device speech models are easier to manage.** Compact download controls
  show model size, language coverage and installation progress. Failed model
  setup can be retried without downloading the files again.

### Fixed
- **sherpa-onnx appears when adding your first provider**, including on Linux.
- **Large speech models start faster.** Readiness checks reuse verification for
  unchanged files instead of repeatedly reading the model before transcription.
