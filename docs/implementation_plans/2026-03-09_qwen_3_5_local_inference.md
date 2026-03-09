# Qwen 3.5 Local Inference Integration

## Context

Qwen 3.5 was released in Feb/Mar 2026 with native multimodal capabilities, reasoning,
and tool calling. The small model series (4B, 9B, 27B) are available on Ollama and
represent a significant upgrade over the current local model offerings (qwen3:8b,
deepseek-r1:8b, gemma3 variants).

Key Qwen 3.5 advantages:
- **Native multimodal**: Early-fusion training on text + image (no separate vision encoder)
- **Reasoning + thinking mode**: Built-in chain-of-thought reasoning
- **Tool calling**: Native function calling support (Qwen3-Coder XML format)
- **256K context**: All sizes support 256K tokens natively
- **Efficient**: Gated Delta Networks architecture

### Known Ollama Limitations (as of March 2026)
- **Vision not working**: Ollama doesn't support Qwen 3.5's mmproj vision files yet
- **Tool calling bug on 27B**: [Issue #14493](https://github.com/ollama/ollama/issues/14493) —
  format mismatch (Hermes JSON vs Qwen3-Coder XML) and broken thinking + tool call rendering
- **9B tool calling**: Reportedly more stable than 27B

## Changes

### 1. Update Ollama Known Models (`known_models.dart`)

**Add:**
- `qwen3.5:9b` — 6.6GB download, ~10GB RAM, reasoning + function calling, text + image
- `qwen3.5:27b` — 17GB download, ~22GB RAM, reasoning + function calling, text + image

**Remove (outdated):**
- `gpt-oss:20b` / `gpt-oss:120b` — niche, superseded by Qwen 3.5 for local use
- `deepseek-r1:8b` — superseded by qwen3.5:9b (better reasoning + multimodal)
- `qwen3:8b` — superseded by qwen3.5:9b

**Keep:**
- `gemma3:4b` — still useful as lightweight vision fallback (until Ollama fixes Qwen vision)
- `gemma3:12b` / `gemma3:12b-it-qat` — keep as alternatives
- `mxbai-embed-large` — embeddings model, different purpose

### 2. Update Seeded Inference Profiles (`profile_seeding_service.dart`)

**Update existing "Local (Ollama)" profile:**
- Thinking: `qwen3:8b` → `qwen3.5:9b`
- Image recognition: keep `gemma3:4b` (Qwen 3.5 vision broken in Ollama)

**Add new "Local Power (Ollama)" profile:**
- ID: `profile-local-power-001`
- Thinking: `qwen3.5:27b`
- Image recognition: `gemma3:12b` (larger Gemma for better vision on powerful hardware)
- `desktopOnly: true`

### 3. Testing Plan
- Pull `qwen3.5:9b` via Ollama and test with task agents (Laura/Tom)
- Verify tool calling works for checklist operations
- Test thinking mode produces valid reasoning
- If Ollama fixes vision, update profiles to use Qwen 3.5 for image recognition too
