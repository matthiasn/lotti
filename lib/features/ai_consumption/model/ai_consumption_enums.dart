/// The kind of backend AI call an `AiConsumptionEvent` records.
///
/// Persisted as the enum **name** — both inside the serialized JSON blob and in
/// the projected `response_type` column — so the order may change freely but the
/// names must remain stable across releases (a rename would strand already
/// synced rows).
///
/// - [agentTurn]: one LLM request/response inside an autonomous agent wake's
///   conversation loop (finest granularity — one row per turn, not per wake).
/// - [textGeneration]: a task/prompt text response on the legacy unified
///   inference path.
/// - [audioTranscription]: speech-to-text for a `JournalAudio` entry.
/// - [imageAnalysis]: vision/OCR over a `JournalImage` entry.
/// - [imageGeneration]: text-to-image cover-art generation.
/// - [promptGeneration]: a skill-driven prompt/text generation call.
enum AiConsumptionResponseType {
  agentTurn,
  textGeneration,
  audioTranscription,
  imageAnalysis,
  imageGeneration,
  promptGeneration,
}
