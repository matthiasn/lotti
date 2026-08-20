# AI

This feature is what makes Lotti's AI work: connecting to a provider, choosing a
model, turning a recording into text, describing a photo, and giving agents
something to think with.

Nothing here happens without the user setting it up. There is no bundled API key
and no default provider — a fresh install has no AI at all until someone connects
one.

## What it does for the user

- **Connects to AI providers.** Cloud services (Gemini, OpenAI, Anthropic,
  Mistral, Melious, Alibaba) and local ones (Ollama, oMLX, MLX Audio on macOS)
  are set up the same way. Connecting a provider automatically offers a matching
  ready-made setup, so nobody has to assemble one model slot at a time.
- **Transcribes voice notes**, using a cloud service or a model running entirely
  on the user's own machine.
- **Summarises a recording in three depths** — a one-line label, a short TLDR,
  and a full organised summary — written in the context of the task the
  recording belongs to, at the moment it was summarised.
- **Describes and reads images** — a short summary, or full text extraction from
  a screenshot or document.
- **Generates prompts** for coding, design and research work, and cover art for
  tasks.
- **Powers agent thinking.** Which model an agent uses is a setting, not
  something baked into the code.
- **Finds things by meaning**, not just by keyword, through local semantic
  search.
- **Keeps automation opt-in.** Automatic transcription, image analysis and
  recording summaries are off until switched on per area, because choosing a
  model is not the same as agreeing to spend tokens on every recording.
- **Shows what was used.** Every AI result records which model produced it and
  what it cost.

## What it owns

Provider, model, prompt and inference-profile configuration; the built-in skill
catalog; prompt assembly and context injection; routing a request to the right
provider endpoint; the multi-turn conversation and tool-calling loop; local
embeddings and vector search; and the AI settings surfaces.

It does **not** decide when an agent wakes or what an agent's lifecycle looks
like — that is the [agents feature](../agents/README.md). It also does not own
the consumption ledger, which belongs to
[ai_consumption](../ai_consumption/README.md).

## Where the code lives

```text
lib/features/ai/
├── model/          # AiConfig variants
├── repository/     # config persistence, provider routing, vector search
├── services/       # skill execution, profile automation
├── skills/         # the built-in skill catalog (code, not data)
├── conversation/   # multi-turn loop and tool calling
├── helpers/        # prompt building and context injection
├── util/           # profile resolution, seeding, locality
├── database/       # AiConfigDb, embedding stores
└── ui/             # provider, model and profile editors
```

## How it works

The runtime architecture — the configuration model, execution paths, profile
resolution, the provider routing table, conversations, seeding and lifecycle,
embeddings, attribution and the eval findings behind the shipped model routing —
is documented in the knowledge bundle:

**→ [knowledge/features/ai/](../../../knowledge/features/ai/)**
