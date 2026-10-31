### Changed
- **Connecting Mistral now sets you up with its current models.** The Mistral
  (EU) profile thinks and reads images with DeepSeek V4.1 Flash, which Mistral
  hosts. It takes the demanding work to Mistral Large 4, transcribes with Voxtral
  Mini Transcribe 3, and reads aloud with Voxtral TTS 3. Setup used to install
  Mistral Small 3.1, Magistral Medium and Voxtral Mini Transcribe 2, and never
  installed the read-aloud model, so reading aloud through Mistral did not work
  until you added that model yourself. An existing Mistral profile keeps the
  models you already use.
