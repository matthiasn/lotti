# Getting Started with Lotti AI

This guide walks you through setting up AI features in Lotti. The First-Time User Experience (FTUE) picks the provider, seeds models, an inference profile, and a starter category, wires those up to Lotti's built-in skills (transcription, image analysis, image generation, prompt builders), and lands you in a result modal you can dismiss to start using AI right away.

| Path | Best For | Requirements |
|------|----------|--------------|
| **Gemini (Cloud)** | Quick setup, powerful models | Google account, internet connection |
| **Ollama (Local)** | Privacy-focused, offline use | macOS/Linux desktop, 32GB+ RAM |
| **MLX Audio (Local)** | Speech recognition on Apple Silicon | macOS on Apple Silicon |
| **Voxtral (Local)** | Local speech-to-text server | Desktop, Voxtral running on `localhost:11344` |
| **Alibaba (Cloud)** | Qwen models, multimodal, long context | Alibaba Cloud account |

---

## Part 1: Cloud Setup with Google Gemini

Gemini is the quickest path. Within a minute or two you'll have audio transcription, image analysis, checklist generation, and task summaries wired up.

### Step 1: Get a Gemini API Key

1. Visit [Google AI Studio](https://aistudio.google.com/apikey)
2. Sign in with your Google account
3. Click **Create API Key**
4. Copy the generated key (it starts with `AIza...`)

> **Note:** Gemini's API has a free usage tier (limits apply); see Google AI Studio for current quotas.

![Get API Key](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/0.9.1002/gemini_api_key.png)

### Step 2: Open AI Settings in Lotti

1. Launch Lotti on your desktop
2. Navigate to **Settings** → **AI Settings**

The empty state shows a card explaining what AI Settings does and an **Add provider** button:

![Empty State](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/0.9.1002/ai_settings_empty.png)

### Step 3: Pick a Provider

Tap **Add provider**. The pick-provider modal opens with one tile per supported provider:

- **Gemini** (Recommended)
- **OpenAI**
- **Anthropic** (NEW)
- **Alibaba** (NEW)
- **MLX Audio** (NEW, macOS / Apple Silicon)
- **Ollama** (Desktop only)
- **Voxtral** (Desktop only)

![Pick Provider Modal](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/0.9.1002/pick_provider_modal.png)

Pick **Gemini**.

### Step 4: Connect

The connect form opens preselected to Gemini, with the base URL prefilled:

- **Display Name:** `Gemini` (or any name you prefer)
- **Base URL:** leave as default (`https://generativelanguage.googleapis.com/v1beta`)
- **API Key:** paste the key from Step 1

As soon as you stop typing in **API Key** or **Base URL**, Lotti checks the credentials against Gemini's API and shows a status strip below the Base URL:

- spinner while the check runs
- green confirmation with the number of models the key can see + response time
- warning row if the key is invalid / network failed / host unreachable (with a Retry button)

![Connect Gemini](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/0.9.1002/add_gemini_provider.png)

Tap **Save** once the verifier is green.

### Step 5: Models Seeded Automatically

On save, Lotti seeds Gemini's headline models so you don't have to add them by hand:

| Model | Best For | Capabilities |
|-------|----------|--------------|
| **Gemini 3.1 Pro Preview** | Complex reasoning | Text, image, audio in → text out; reasoning + function calling |
| **Gemini 3 Flash Preview** | Fast multimodal tasks | Text, image, audio in → text out; reasoning + function calling |
| **Gemini 3 Pro Image (Nano Banana Pro)** | Image generation | Text + image in → text + image out (cover art, visual mnemonics) |

Visible in the **Models** tab:

![Gemini Models](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/0.9.1002/gemini_models.png)

### Step 6: Start Using AI

Saving the provider also seeds an inference profile and a starter category, and wires them to Lotti's built-in **skills**. The result modal summarizes what was created and offers a single **Start using AI** CTA:

![Start Using AI](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/0.9.1002/start_using_ai.png)

Skills are hardcoded in the app — you don't manage them as data, you pick which model each one runs on. The headline skills:

| Skill | What It Does |
|-------|--------------|
| **Transcribe Audio** | Converts voice recordings to text |
| **Analyze Image** | Describes images and extracts task-relevant detail |
| **Generate Cover Art** | Generates images for tasks via Nano Banana Pro |
| **Generate Coding Prompt** | Builds structured coding prompts from task context |

More skills (image-prompt, design-prompt, research-prompt, task-context variants) are wired up to each inference profile. Review or rewire them under **AI Settings** → **Profiles**:

![Profiles Tab](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/0.9.1002/prompts_list.png)

**What you can now do:**

- **Voice notes:** record audio and have it automatically transcribed
- **Image analysis:** add images to tasks and get AI-powered insights
- **Smart checklists:** speak or type and let AI create actionable checklist items
- **Task summaries:** get comprehensive overviews of long-running tasks

---

## Part 2: Local Setup with Ollama

Ollama runs models entirely on your device. Your data never leaves the machine — ideal for sensitive information.

### Prerequisites

- **macOS** or **Linux** desktop
- **32GB+ RAM** (the headline `Local Power` profile uses a 35B MoE thinking model)
- **~30GB disk space** for models

### Step 1: Install Ollama

1. Visit [ollama.com](https://ollama.com)
2. Download and install Ollama for your platform
3. Verify in Terminal:

```bash
ollama --version
```

### Step 2: Start the Ollama Service

```bash
ollama serve
```

> **Tip:** On macOS, you can set Ollama to start automatically at login.

### Step 3: Pick Ollama in Lotti

Open **Settings** → **AI Settings** → **Add provider**, then pick the **Ollama** tile:

![Ollama Tile](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/0.9.1002/ollama_tile.png)

### Step 4: Connect

The connect form opens with Ollama preselected, the default base URL prefilled, and no API key required:

- **Display Name:** `Ollama Local`
- **Base URL:** `http://localhost:11434`
- **API Key:** not required

![Connect Ollama](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/0.9.1002/add_ollama_provider.png)

Tap **Save**.

### Step 5: Models and Profiles Seeded

Lotti seeds several inference profiles you can choose from:

| Profile | Thinking Model | Image Model | Notes |
|---------|---------------|-------------|-------|
| **Local (Ollama)** | `qwen3.5:9b` | `qwen3.5:9b` | Lighter, runs on more hardware |
| **Local Power (Ollama)** | `qwen3.6:35b-a3b-coding-nvfp4` (35B MoE / ~3B active, NVFP4) | `qwen3.5:27b` | Headline profile when hardware allows |
| **Local Gemma 4 (Ollama)** | `gemma4:26b` | `gemma4:26b` | Gemma 4 alternative |
| **Local Gemma 4 Power (Ollama)** | `gemma4:31b` | `gemma4:31b` | Larger Gemma 4 |

The first time a model is needed, Ollama downloads it automatically.

> **Note:** First-time model downloads can take several minutes depending on your internet speed and the chosen model.

### Step 6: You're Ready for Offline AI

After the result modal closes you're done. All inference happens on your device — no internet required once the model is downloaded.

---

## Other Local Options

### MLX Audio (macOS, Apple Silicon)

On-device speech recognition on macOS Apple Silicon — no separate server to run. Picking the **MLX Audio** tile opens a first-run model picker; **Qwen3-ASR 1.7B 8-bit** is preselected because it's materially faster than Voxtral Realtime for post-recording transcription.

![MLX Audio Setup](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/0.9.1002/mlx_audio_first_run.png)

### Voxtral (Local Server)

If you're running a Voxtral server locally, pick the **Voxtral** tile. The connect form prefills `http://localhost:11344` and skips the API key field.

![Voxtral Tile](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/0.9.1002/voxtral_tile.png)

### Alibaba Cloud (Qwen)

Qwen models — multimodal, long context. Pick the **Alibaba** tile and connect with your Alibaba Cloud key.

![Alibaba Tile](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/0.9.1002/alibaba_tile.png)

---

## Configuring Categories for AI

Once a provider is connected, you can wire categories to a default inference profile so the built-in skills run against the right model on content in that category.

1. Go to **Settings** → **Categories**
2. Select or create a category (e.g., "Work Tasks")
3. Open the **Default inference profile** picker and pick the profile you want to use for that category's audio, image, and task content

Standalone audio / text / image entries that have no parent task fall back to the category's default profile, so you can use Transcribe / Analyze actions on any entry in that category.

---

## Troubleshooting

### Gemini

| Problem | Solution |
|---------|----------|
| "API key invalid" | Double-check the key; ensure no extra spaces |
| "Quota exceeded" | Wait 24 hours or upgrade your Google Cloud billing |
| Slow responses | Use Gemini 3 Flash Preview for faster processing |

### Ollama

| Problem | Solution |
|---------|----------|
| "Connection refused" | Ensure `ollama serve` is running |
| Model download stuck | Check internet connection; restart Ollama |
| Slow inference | Close other apps; try smaller models |
| Out of memory | Use a smaller profile (`Local (Ollama)`) or quantized variants |

### Live verifier shows "Unreachable host"

The verifier hits the provider's models endpoint from your machine. If you're behind a proxy or firewall and the call can't reach the host, you'll see this error. Save anyway — Lotti will surface the same error the next time it actually calls the model.

---

## Next Steps

- **Voice Journal:** record voice notes and get instant transcriptions
- **Photo Analysis:** add screenshots or photos to tasks for AI insights
- **Smart Checklists:** dictate tasks and let AI organize them
- **Weekly Reviews:** generate AI summaries of your accomplishments

**Ready to start using voice-to-checklist?** Follow the [Basic Task Management Guide](docs/BASIC_TASK_MANAGEMENT.md) for a step-by-step walkthrough.

← Back to [Main README](README.md)

---

*This guide covers Lotti version 0.9.1002 and later. UI may vary slightly between versions.*
