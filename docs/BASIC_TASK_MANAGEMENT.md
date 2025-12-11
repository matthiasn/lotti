# Basic Task Management with Voice in Lotti

This guide walks you through using voice recordings to create and manage tasks in Lotti. You'll learn how to turn spoken thoughts into organized checklists automatically.

| What You'll Learn | Description |
|-------------------|-------------|
| **Voice Recording** | Capture your thoughts by speaking |
| **Automatic Transcription** | AI converts your speech to text |
| **Smart Checklists** | AI extracts action items from your words |
| **Task Tracking** | Monitor progress and complete items |

> **Prerequisite:** Before starting this guide, make sure you've completed the [Getting Started Guide](../GETTING_STARTED.md) to set up your AI provider (Gemini or Ollama).

---

## Part 1: Understanding the Workflow

Before diving in, here's how voice-to-checklist works in Lotti:

```text
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  You speak      │ ──▶ │  AI transcribes │ ──▶ │  AI finds       │ ──▶ │  Checklist      │
│  your thoughts  │     │  to text        │     │  action items   │     │  is created     │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
```

This entire process happens automatically after you stop recording. No extra steps needed.

---

## Part 2: Creating a Task

### Step 1: Open the Create Menu

1. Launch Lotti on your device
2. Navigate to the **Journal** or **Tasks** section
3. Look for the **+** button (floating action button) in the bottom right corner
4. Tap the **+** button to open the create menu

<!-- Screenshot: Main screen showing the floating action button (+) in bottom right -->
![Floating Action Button](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/floating_action_button.png)

### Step 2: View Entry Options

After tapping the **+** button, a menu appears with several entry types:

| Entry Type | Icon | Description |
|------------|------|-------------|
| **Create Event** | Calendar | Schedule a time-based event |
| **Create Task** | Checkbox | Create a task with checklists |
| **Create Audio Recording** | Microphone | Record a voice note |
| **Create Text** | Document | Write a text entry |
| **Import/Paste Image** | Image | Add a photo or screenshot |

<!-- Screenshot: Create entry modal showing all available options -->
![Create Entry Modal](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/create_entry_modal.png)

### Step 3: Create a New Task

1. Tap **Create Task** from the menu
2. Enter a descriptive title for your task
   - Good examples: "Plan weekend trip", "Quarterly report", "Home renovation project"
   - Avoid vague titles like "Stuff to do" or "Things"
3. Optionally, select a **Category** for better organization
4. Tap **Save** to create the task

<!-- Screenshot: Task creation form with title field and category selector -->
![Create Task Form](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/create_task_form.png)

> **Tip:** Choose a category that has AI prompts configured. This ensures automatic transcription and checklist generation will work.

### Step 4: View Your New Task

After saving, your task opens automatically. You'll see:

- **Task header** with the title you entered
- **Empty content area** ready for notes and recordings
- **+** button to add entries to this task

<!-- Screenshot: Newly created empty task showing header and empty state -->
![Empty Task View](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/empty_task_view.png)

---

## Part 3: Recording Your First Voice Note

### Step 1: Open the Recording Screen

1. While viewing your task, tap the **+** button
2. Select **Create Audio Recording** from the menu

The audio recording modal appears with several elements:

<!-- Screenshot: Audio recording modal in initial state before recording -->
![Audio Recording Modal](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/audio_recording_modal.png)

### Step 2: Understand the Recording Interface

The recording screen has these components:

| Component | Location | Purpose |
|-----------|----------|---------|
| **VU Meter** | Center (large circle) | Shows real-time audio levels in dBFS |
| **Duration Timer** | Below VU meter | Displays recording length (MM:SS) |
| **RECORD Button** | Bottom left | Starts the recording |
| **STOP Button** | Bottom right | Ends and saves the recording |
| **Processing Options** | Below buttons | Checkboxes for AI features |

<!-- Screenshot: Recording interface with all components labeled -->
![Recording Interface Labeled](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/recording_interface_labeled.png)

### Step 3: Configure Processing Options

Before you start recording, check the processing options at the bottom:

| Option | What It Does | Recommended |
|--------|--------------|-------------|
| **Speech Recognition** | Converts your voice to written text | ✅ Always enable |
| **Checklist Updates** | Creates checklist items from your speech | ✅ Enable for tasks |
| **Task Summary** | Generates an overview of your task | ✅ Enable for context |

**Make sure all three checkboxes are selected** for the complete voice-to-checklist experience.

<!-- Screenshot: Processing options checkboxes all enabled -->
![Processing Options Enabled](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/processing_options_enabled.png)

> **Note:** These options only appear when recording within a task. Standalone recordings won't show checklist options.

### Step 4: Start Recording

1. Tap the **RECORD** button
2. The button changes to show recording is active
3. The VU meter starts responding to your voice
4. The timer begins counting up

<!-- Screenshot: Active recording state with VU meter showing audio levels -->
![Recording Active](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/recording_active.png)

### Step 5: Speak Your Tasks Clearly

Now speak naturally about what you need to do. Here are examples of effective speech:

**Good example:**
> "For the weekend trip, I need to book flights for Friday morning, reserve a hotel room for two nights, pack my suitcase with warm clothes, remember to bring my passport and chargers, and check if I need any vaccinations for the destination."

**Why it works:**
- Clear, specific actions
- Each item is distinct
- Includes relevant details

**Less effective example:**
> "I have some stuff to do for the trip... you know, the usual things people do when traveling."

**Why it's less effective:**
- Vague language
- No specific actions
- AI can't extract concrete items

<!-- Screenshot: Example of speaking with VU meter showing voice activity -->
![Speaking Example](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/speaking_example.png)

### Step 6: Stop and Save

1. When you've finished speaking, tap the **STOP** button
2. The recording modal closes automatically
3. Lotti begins processing your audio

<!-- Screenshot: Stop button highlighted, ready to end recording -->
![Stop Recording](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/stop_recording.png)

> **Tip:** Recordings have a maximum duration of 2 minutes for optimal processing. For longer thoughts, make multiple recordings.

---

## Part 4: Automatic AI Processing

After you stop recording, Lotti processes your audio through three stages:

### Stage 1: Speech Recognition

The AI listens to your recording and converts it to text.

- **Processing time:** A few seconds
- **Result:** Written transcript of your words
- **Accuracy:** Works best with clear speech and minimal background noise

<!-- Screenshot: Transcription appearing in the task view -->
![Transcription Result](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/transcription_result.png)

### Stage 2: Checklist Generation

Once transcription completes, the AI analyzes the text to find action items.

- **What it looks for:** Verbs, tasks, to-do items, action words
- **How it organizes:** Groups related items, removes duplicates
- **Result:** A checklist with individual items

<!-- Screenshot: AI generating checklist items from transcript -->
![Checklist Generation](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/checklist_generation.png)

### Stage 3: Task Summary

Finally, the AI creates a summary of your entire task.

- **Includes:** All recordings, notes, and context
- **Purpose:** Quick overview without reading everything
- **Updates:** Refreshes when you add new content

<!-- Screenshot: Task summary appearing at top of task view -->
![Task Summary](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/task_summary.png)

### View Your Generated Checklist

After processing completes, scroll down in your task to see the new checklist:

<!-- Screenshot: Complete task view showing transcript and generated checklist -->
![Generated Checklist Complete](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/generated_checklist_complete.png)

From our example, the AI might create these items:

| Status | Checklist Item |
|--------|----------------|
| ☐ | Book flights for Friday morning |
| ☐ | Reserve hotel room for two nights |
| ☐ | Pack suitcase with warm clothes |
| ☐ | Bring passport |
| ☐ | Bring chargers |
| ☐ | Check vaccination requirements |

---

## Part 5: Managing Your Checklist

### Understanding the Checklist Layout

Each checklist in Lotti has these elements:

```text
┌─────────────────────────────────────────────────────────┐
│  📋 Checklist Header                                    │
│  ┌─────────────────────────────────────────────────┐   │
│  │  [Progress Bar ████████░░░░] 4/6 completed      │   │
│  │  Checklist Title                    [Edit ✏️]    │   │
│  │  [All] [Open Only]                  [Menu ⋮]    │   │
│  └─────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────┤
│  ☑ Book flights for Friday morning                     │
│  ☑ Reserve hotel room for two nights                   │
│  ☑ Pack suitcase with warm clothes                     │
│  ☑ Bring passport                                      │
│  ☐ Bring chargers                                      │
│  ☐ Check vaccination requirements                      │
├─────────────────────────────────────────────────────────┤
│  [Add new item...]                                      │
└─────────────────────────────────────────────────────────┘
```

<!-- Screenshot: Checklist with all UI elements visible and labeled -->
![Checklist Layout Labeled](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/checklist_layout_labeled.png)

### Completing Items

To mark an item as done:

1. Find the item in your checklist
2. Tap the **checkbox** (☐) on the left side
3. The item shows as completed (☑)
4. The progress bar updates automatically

<!-- Screenshot: Before and after completing a checklist item -->
![Completing Item](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/completing_item.png)

To undo a completion:

1. Find the completed item (☑)
2. Tap the checkbox again
3. The item returns to incomplete (☐)

### Viewing Progress

The checklist header shows your progress in two ways:

| Indicator | Description | Example |
|-----------|-------------|---------|
| **Progress Bar** | Visual representation of completion | ████████░░░░ |
| **Counter** | Numeric count of completed items | "4/6 completed" |

<!-- Screenshot: Progress bar and counter showing partial completion -->
![Progress Indicators](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/progress_indicators.png)

### Filtering Your View

Use filter buttons to focus on what matters:

| Filter | What It Shows | When to Use |
|--------|---------------|-------------|
| **All** | Every item (completed and incomplete) | Review everything |
| **Open Only** | Only incomplete items | Focus on remaining work |

To change filters:

1. Look for the filter buttons below the checklist title
2. Tap **Open Only** to hide completed items
3. Tap **All** to show everything again

<!-- Screenshot: Checklist with "Open Only" filter active -->
![Filter Open Only](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/filter_open_only.png)

### Adding Items Manually

Sometimes you need to add items the AI didn't catch:

1. Scroll to the bottom of the checklist
2. Find the text field labeled "Add new item..."
3. Type your new item
4. Press **Enter** or tap the **Add** button

<!-- Screenshot: Adding a new item manually via text field -->
![Add Manual Item](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/add_manual_item.png)

### Editing the Checklist Title

To rename your checklist:

1. Tap the **Edit** button (✏️) next to the title
2. Enter a new title
3. Tap outside the field or press Enter to save

<!-- Screenshot: Editing checklist title -->
![Edit Checklist Title](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/edit_checklist_title.png)

---

## Part 6: Adding Follow-Up Recordings

Tasks often evolve over time. You can add more voice notes to update your checklist.

### Step 1: Record Additional Thoughts

1. Open your existing task
2. Tap the **+** button
3. Select **Create Audio Recording**
4. Ensure **Checklist Updates** is checked
5. Record your additional thoughts

**Example follow-up:**
> "I also need to arrange pet sitting while we're away, stop the mail delivery, and ask the neighbor to water the plants."

<!-- Screenshot: Recording a follow-up voice note -->
![Follow Up Recording](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/follow_up_recording.png)

### Step 2: View Updated Checklist

After processing, the new items appear in your checklist:

| Status | Item | Source |
|--------|------|--------|
| ☐ | Book flights for Friday morning | First recording |
| ☐ | Reserve hotel room for two nights | First recording |
| ☐ | Pack suitcase with warm clothes | First recording |
| ☐ | Bring passport | First recording |
| ☐ | Bring chargers | First recording |
| ☐ | Check vaccination requirements | First recording |
| ☐ | Arrange pet sitting | **Follow-up** |
| ☐ | Stop mail delivery | **Follow-up** |
| ☐ | Ask neighbor to water plants | **Follow-up** |

<!-- Screenshot: Checklist showing original and newly added items -->
![Updated Checklist](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/updated_checklist.png)

> **Note:** The AI intelligently merges new items with existing ones, avoiding duplicates.

---

## Part 7: Smart AI Suggestions

Lotti can suggest when checklist items might be complete based on your activity.

### How Suggestions Appear

When the AI thinks an item is done, you'll see:

- A **colored indicator bar** on the left side of the item
- The bar may **pulse gently** to draw your attention
- Colors indicate confidence level:

| Color | Confidence | Meaning |
|-------|------------|---------|
| **Blue** | High | AI is confident this is complete |
| **Purple** | Medium | Likely complete based on context |
| **Gray** | Low | Possibly complete, needs confirmation |

<!-- Screenshot: Checklist item with AI suggestion indicator -->
![AI Suggestion Indicator](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/ai_suggestion_indicator.png)

### Responding to Suggestions

1. Tap the **colored indicator** on the suggested item
2. A dialog appears with:
   - The AI's reasoning
   - Confidence level
   - Two action buttons
3. Choose your response:

| Button | Action |
|--------|--------|
| **Mark Complete** | Accept the suggestion and check off the item |
| **Cancel** | Dismiss the suggestion and keep the item open |

---

## Part 8: Sharing and Exporting

### Access Export Options

1. Find the **three-dot menu** (⋮) in the checklist header
2. Tap to open the menu
3. Choose an export option

<!-- Screenshot: Checklist menu showing export options -->
![Checklist Menu](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/checklist_menu.png)

### Export Formats

| Option | Format | Best For |
|--------|--------|----------|
| **Export as Markdown** | Plain text with formatting | Notes apps, documentation |

### Markdown Export Example

```markdown
## Weekend Trip Checklist

- [x] Book flights for Friday morning
- [x] Reserve hotel room for two nights
- [ ] Pack suitcase with warm clothes
- [ ] Bring passport
- [ ] Bring chargers
- [ ] Check vaccination requirements
```

<!-- Screenshot: Markdown export result -->
![Markdown Export](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/markdown_export.png)

### Deleting a Checklist

If you need to remove a checklist entirely:

1. Tap the **three-dot menu** (⋮)
2. Select **Delete checklist**
3. Confirm the deletion

> **Warning:** This action cannot be undone. The checklist and all its items will be permanently removed.

---

## Part 9: Tips for Best Results

### Speaking Tips

| Do This | Avoid This |
|---------|------------|
| "I need to call Mom tomorrow" | "Maybe contact family sometime" |
| "Buy groceries: milk, bread, eggs" | "Get some food stuff" |
| "Schedule dentist for Tuesday at 2pm" | "See the dentist eventually" |
| "Email John the quarterly report by Friday" | "Send something to someone" |
| "Research flights under $500 to Paris" | "Look into travel options" |

**Key principles:**
- Use **action verbs** (call, buy, schedule, email, research)
- Include **specific details** (names, dates, amounts)
- State **one task at a time** clearly

### Organization Tips

| Tip | Why It Helps |
|-----|--------------|
| Create separate tasks for different projects | Keeps checklists focused |
| Use descriptive task titles | Easier to find later |
| Record updates as you think of them | Captures everything |
| Review and complete items daily | Maintains momentum |

<!-- Screenshot: Well-organized task list showing multiple tasks -->
![Organized Tasks](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/tasks_getting_started/organized_tasks.png)

### Recording Environment Tips

| Factor | Recommendation |
|--------|----------------|
| **Background noise** | Find a quiet space |
| **Distance** | Hold device 6-12 inches from mouth |
| **Speed** | Speak at a natural, steady pace |
| **Pauses** | Brief pauses between items help AI parse |

---

## Troubleshooting

### Recording Issues

| Problem | Possible Cause | Solution |
|---------|---------------|----------|
| VU meter not moving | Microphone not detected | Check microphone permissions in device settings |
| Recording stops immediately | Permission denied | Grant Lotti microphone access |
| Audio quality poor | Too far from microphone | Hold device closer when speaking |

### Transcription Issues

| Problem | Possible Cause | Solution |
|---------|---------------|----------|
| No transcription appears | AI not configured | Complete the [Getting Started Guide](../GETTING_STARTED.md) |
| Transcription inaccurate | Background noise / fast speech | Re-record in quieter environment, speak slower |
| Wrong language detected | Auto-detection error | Set language manually before recording |

### Checklist Issues

| Problem | Possible Cause | Solution |
|---------|---------------|----------|
| No checklist created | Checkbox not enabled | Ensure "Checklist Updates" is checked before stopping |
| Items missing | Vague speech | Re-record with specific, actionable language |
| Duplicate items | Multiple similar recordings | Delete duplicates manually |

---

## Quick Reference Card

### Creating Tasks

| Action | Steps |
|--------|-------|
| New task | **+** → **Create Task** → Enter title → **Save** |
| Voice recording | **+** → **Create Audio Recording** → **Record** → Speak → **Stop** |

### Managing Checklists

| Action | Steps |
|--------|-------|
| Complete item | Tap checkbox (☐ → ☑) |
| Undo completion | Tap checkbox again (☑ → ☐) |
| Filter view | Tap **Open Only** or **All** |
| Add item | Type in "Add new item..." field → Enter |
| Edit title | Tap ✏️ → Edit → Enter |

### Exporting

| Action | Steps |
|--------|-------|
| Export markdown | **⋮** → **Export as Markdown** |
| Delete checklist | **⋮** → **Delete checklist** → Confirm |

---

## Next Steps

Now that you've mastered voice-to-checklist, explore these advanced features:

| Feature | Description | Where to Find |
|---------|-------------|---------------|
| **AI Chat** | Have conversations with AI about your tasks | Chat icon in task view |
| **Image Analysis** | Add photos for AI-powered insights | **+** → **Import Image** |
| **Weekly Reviews** | Generate summaries of your accomplishments | Journal section |
| **Categories** | Organize tasks by project or area | **Settings** → **Categories** |

← Back to [Main README](../README.md) | [Getting Started with AI](../GETTING_STARTED.md)

---

*This guide covers Lotti version 0.9.751 and later. UI may vary slightly between versions.*
