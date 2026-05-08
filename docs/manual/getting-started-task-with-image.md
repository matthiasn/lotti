# Your First Task — Dictate It, Generate Cover Art, Let an Agent Help

This walkthrough takes you from "I just installed Lotti" to "I have a real task with a transcript, a checklist, and cover art" — the loop you'll repeat every day.

It assumes you've already worked through [**Getting Started with Lotti AI**](../../GETTING_STARTED.md) — the step‑by‑step guide for wiring up either local Ollama (with Gemma, Qwen3, or DeepSeek) or cloud Gemini, and creating the four default prompts (Audio Transcript, Image Analysis, Checklist Updates, Task Summary). For this walkthrough you need at minimum the **Audio Transcript** and **Image Analysis** prompts; **Checklist Updates** is what lets an agent organise voice notes into checklist items for you.

> **Two paths, same flow.** Whether you set up local Ollama with Qwen 3.6 or cloud Gemini Flash, the steps below are identical. The provider is a per‑category choice you can change at any time.

---

## 1. Create the task

1. Open Lotti.
2. From the **Tasks** tab, tap the **+** button.
3. Give the task a title — anything works; you can let an agent rewrite it later.
4. Pick a **category**. Categories are how Lotti decides which AI provider runs on this task (and on its voice notes, summaries, and cover art). If you haven't created any yet, do that now in **Settings → Categories**.

> ![Placeholder: 2026-05-07 - New task dialog with title and category picker - Linux desktop](path/to/lotti-assets/repo)
>
> ![Placeholder: 2026-05-07 - Same flow on a phone — full‑screen new‑task entry - Android](path/to/lotti-assets/repo)

---

## 2. Dictate into it

This is the workflow the author uses most: capture an idea while walking, driving, or otherwise away from a keyboard.

1. From the open task, tap the **microphone** button.
2. Talk for as long as you want. Don't structure your thoughts — that's the agent's job.
3. Stop the recording when you're done.

Lotti will transcribe the audio using the provider configured for this category:

- **Local** — Voxtral or Whisper, fully offline.
- **Cloud** — Gemini, OpenAI, or Mistral, depending on what you set up.

> ![Placeholder: 2026-05-07 - Recording in progress with live waveform - Android](path/to/lotti-assets/repo)
>
> ![Placeholder: 2026-05-07 - Transcript appearing under the audio entry once transcription finishes - Linux desktop](path/to/lotti-assets/repo)

### Let the agent organise it

If you have the **Checklist Updates** prompt configured for this category, the task agent picks up the new transcript on its next wake cycle and proposes checklist items based on what you said. They appear as **pending suggestions** on the task — accept, edit, or reject each one. Nothing lands in your task without your approval (with one narrow exception: if the task has no title at all, an agent may set the initial title automatically).

> ![Placeholder: 2026-05-07 - Pending checklist suggestions awaiting approval, with accept/reject affordances - Linux desktop](path/to/lotti-assets/repo)

---

## 3. Generate cover art

Cover art isn't decoration. Months from now, when you scroll the Tasks tab, the cover art is what lets you recognise a slice of your life at a glance — an Instagram‑style grid of what you actually did.

1. From the task header, tap the **image** icon.
2. Optionally type a short prompt — or leave it empty to let Lotti use the task's title and transcript as the prompt.
3. Pick a provider:
   - **Nano Banana Pro** (Gemini) — the author's default.
   - **OpenAI** — DALL·E 3.
   - **Qwen** — Wan 2.6 image via Alibaba.
4. Generate. The image attaches to the task and shows up as cover art everywhere the task appears.

> ![Placeholder: 2026-05-07 - Image generation panel: prompt + provider selector + generated result - Linux desktop](path/to/lotti-assets/repo)
>
> ![Placeholder: 2026-05-07 - Tasks tab grid view showing several tasks with cover art forming a visual journal - Linux desktop](path/to/lotti-assets/repo)

> **Local image generation isn't there yet.** All three providers above are cloud. A reliable, local Python image‑gen service (analogous to our local Voxtral integration) is one of the few areas where outside contributions are explicitly wanted — see [Contributing](../../README.md#contributing) in the main README.

---

## 4. What to do next

You now have the loop:

1. Create a task in a category.
2. Talk into it.
3. Let the agent propose checklist items; approve them.
4. Generate cover art.
5. Repeat tomorrow.

When you have more than one device — or just want your data to sync between phone and desktop — continue with [Sync between your devices](getting-started-sync.md).

For deeper customisation (multiple agents per category, different souls, custom report directives, weekly 1‑on‑1s), see the [Agents feature README](../../lib/features/agents/README.md) and the longer [Manual](../MANUAL.md).
