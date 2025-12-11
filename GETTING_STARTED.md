# Getting Started with Lotti AI

This guide walks you through setting up AI features in Lotti. You have two paths to choose from:

| Path | Best For | Requirements |
|------|----------|--------------|
| **Gemini (Cloud)** | Quick setup, powerful models | Google account, internet connection |
| **Ollama (Local)** | Privacy-focused, offline use | macOS/Linux, 8-16GB RAM |

---

## Part 1: Cloud Setup with Google Gemini

Gemini offers the fastest way to get started with AI features in Lotti. Within minutes, you'll have access to audio transcription, image analysis, checklist generation, and task summaries.

### Step 1: Get a Gemini API Key

1. Visit [Google AI Studio](https://aistudio.google.com/apikey)
2. Sign in with your Google account
3. Click **Create API Key**
4. Copy the generated key (it starts with `AIza...`)

> **Note:** Gemini offers a generous free tier. For most personal use, you won't need to pay anything.

<!-- Screenshot: Google AI Studio API key page -->
![Get API Key](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/gemini_api_key.png)

### Step 2: Open AI Settings in Lotti

1. Launch Lotti on your desktop
2. Navigate to **Settings** (gear icon in the sidebar)
3. Select **AI Settings**

When you first open AI Settings, you'll see an empty state:

<!-- Screenshot: Empty AI Settings page showing "No AI providers configured" -->
![Empty State](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/ai_settings_empty.png)

### Step 3: Add the Gemini Provider

1. Tap the **+** button in the bottom right corner
2. Select **Gemini** from the provider type list
3. Fill in the form:
   - **Display Name:** `Gemini` (or any name you prefer)
   - **Base URL:** Leave as default (`https://generativelanguage.googleapis.com/v1beta`)
   - **API Key:** Paste your API key from Step 1
4. Tap **Save**

<!-- Screenshot: Provider edit page with Gemini selected -->
![Add Gemini Provider](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/add_gemini_provider.png)

### Step 4: Automatic Model Configuration

After saving, Lotti automatically configures the following Gemini models for you:

| Model | Best For | Capabilities |
|-------|----------|--------------|
| **Gemini 3 Pro Preview** | Complex reasoning tasks | Text, images, audio + advanced reasoning |
| **Gemini 2.5 Pro** | General purpose tasks | Text, images, audio + reasoning |
| **Gemini 2.5 Flash** | Fast audio transcription | Text, images, audio + reasoning (fast) |

You can view these in the **Models** tab:

<!-- Screenshot: Models tab showing auto-populated Gemini models -->
![Gemini Models](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/gemini_models.png)

### Step 5: Set Up Default Prompts

Immediately after saving your provider, Lotti offers to create ready-to-use prompts:

<!-- Screenshot: "Set Up Default Prompts?" dialog -->
![Setup Prompts Dialog](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/setup_prompts_dialog.png)

Click **Set Up Prompts** to create these four AI capabilities:

| Prompt | Model Used | What It Does |
|--------|------------|--------------|
| **Audio Transcript** | Gemini Flash | Converts voice recordings to text |
| **Image Analysis** | Gemini Pro | Analyzes images in task context |
| **Checklist Updates** | Gemini Pro | Generates and updates task checklists |
| **Task Summary** | Gemini Pro | Creates comprehensive task overviews |

A success message confirms the prompts were created:

<!-- Screenshot: Success snackbar "4 prompts created successfully!" -->
![Prompts Created](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/prompts_created.png)

### Step 6: You're Ready!

Navigate to the **Prompts** tab to see your new AI capabilities:

<!-- Screenshot: Prompts tab showing the 4 created prompts -->
![Prompts List](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/prompts_list.png)

**What you can now do:**

- **Voice notes:** Record audio and have it automatically transcribed
- **Image analysis:** Add images to tasks and get AI-powered insights
- **Smart checklists:** Speak or type and let AI create actionable checklist items
- **Task summaries:** Get comprehensive overviews of long-running tasks

---

## Part 2: Local Setup with Ollama

Ollama lets you run AI models entirely on your device. Your data never leaves your machine, making it ideal for sensitive information.

### Prerequisites

- **macOS** or **Linux** (Windows support via WSL)
- **8GB RAM minimum** (16GB recommended for larger models)
- **~10GB disk space** for models

### Step 1: Install Ollama

1. Visit [ollama.com](https://ollama.com)
2. Download and install Ollama for your platform
3. Open Terminal and verify installation:

```bash
ollama --version
```

### Step 2: Start the Ollama Service

Ollama runs as a background service. Start it with:

```bash
ollama serve
```

> **Tip:** On macOS, you can set Ollama to start automatically at login.

### Step 3: Add Ollama Provider in Lotti

1. Open **Settings** > **AI Settings** in Lotti
2. Tap the **+** button
3. Select **Ollama** from the provider list
4. Fill in the form:
   - **Display Name:** `Ollama Local`
   - **Base URL:** `http://localhost:11434` (default)
   - **API Key:** Leave empty (not required for local)
5. Tap **Save**

<!-- Screenshot: Add Ollama provider form -->
![Add Ollama Provider](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/add_ollama_provider.png)

### Step 4: Automatic Model Installation

Lotti automatically sets up these local models:

| Model | Size | Best For |
|-------|------|----------|
| **Gemma 3 4B** | ~4GB | Image analysis, general tasks |
| **Gemma 3 12B** | ~12GB | Higher quality responses |
| **DeepSeek R1 8B** | ~8GB | Complex reasoning tasks |
| **Qwen3 8B** | ~8GB | Reasoning with function calling |

When you first use a model, Lotti will download it automatically. You'll see a progress indicator:

<!-- Screenshot: Model download progress -->
![Model Download](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/ollama_model_download.png)

> **Note:** First-time model downloads can take several minutes depending on your internet speed.

### Step 5: Configure Prompts

After the provider is saved, set up prompts the same way as with Gemini. Lotti will:

1. Show the prompt setup dialog
2. Select appropriate local models (e.g., Gemma for images, DeepSeek for reasoning)
3. Create the four default prompts

### Step 6: You're Ready for Offline AI!

Your local AI setup is complete. All processing happens on your device:

- No internet required after model download
- Data stays private
- Works offline (airplane mode, no WiFi areas)

---

## Configuring Categories for AI

Once you have providers and prompts set up, you can configure which AI prompts are available for specific categories.

### Assign Automatic Prompts to Categories

1. Go to **Settings** > **Categories**
2. Select or create a category (e.g., "Work Tasks")
3. Scroll to **AI Configuration**
4. Set automatic prompts for each response type:
   - **Task Summary:** Choose your summary prompt
   - **Image Analysis:** Choose your image prompt
   - **Audio Transcription:** Choose your transcription prompt
   - **Checklist Updates:** Choose your checklist prompt

<!-- Screenshot: Category AI configuration -->
![Category AI Config](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/getting_started/category_ai_config.png)

---

## Troubleshooting

### Gemini Issues

| Problem | Solution |
|---------|----------|
| "API key invalid" | Double-check the key; ensure no extra spaces |
| "Quota exceeded" | Wait 24 hours or upgrade your Google Cloud billing |
| Slow responses | Try Gemini Flash models for faster processing |

### Ollama Issues

| Problem | Solution |
|---------|----------|
| "Connection refused" | Ensure `ollama serve` is running |
| Model download stuck | Check internet connection; restart Ollama |
| Slow inference | Close other apps; try smaller models (4B variants) |
| Out of memory | Use quantized models (QAT variants) |

---

## Next Steps

Now that AI is set up, explore these features:

- **Voice Journal:** Record voice notes and get instant transcriptions
- **Photo Analysis:** Add screenshots or photos to tasks for AI insights
- **Smart Checklists:** Dictate tasks and let AI organize them
- **Weekly Reviews:** Generate AI summaries of your accomplishments

**Ready to start using voice-to-checklist?** Follow the [Basic Task Management Guide](docs/BASIC_TASK_MANAGEMENT.md) for a step-by-step walkthrough.

← Back to [Main README](README.md)

---

*This guide covers Lotti version 0.9.751 and later. UI may vary slightly between versions.*
