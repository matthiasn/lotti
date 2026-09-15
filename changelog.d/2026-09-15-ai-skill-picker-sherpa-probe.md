### Fixed
- **Generating a coding prompt no longer stalls for seconds the first time
  after the app starts.** When an on-device speech provider was configured,
  tapping a text skill such as *Generate coding prompt* first waited while the
  app verified every downloaded speech model on disk, a check that reads the
  whole model file and can take several seconds for Whisper-sized models. The
  picker now only waits for that check when a speech model is actually among
  the choices, so text and image skills open immediately.
