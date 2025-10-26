# AI Label Assignment

This guide explains how Lotti automatically assigns labels to tasks using AI function calling, how to configure it, and how to undo changes if needed.

## Overview

- The AI suggests labels during the “Checklist Updates” flow.
- The prompt includes a compact list of available labels with `{ id, name }` so the model can reference labels by ID.
- The model calls `assign_task_labels` with `labelIds: string[]` to add labels to the current task.
- The app enforces caps (max 5 per call), validates IDs, and ensures only one label per group is assigned.
- After assignment, a non‑blocking toast (SnackBar) appears in Task Details with an Undo option.

## Configuration

Feature flags are stored in settings and can be toggled from the flags panel.

- `enable_ai_label_assignment` (bool)
  - Enables the label tool and prompt label injection.
- `include_private_labels_in_prompts` (bool)
  - Includes private labels in the injected list when true (default true).
- `ai_label_assignment_shadow` (bool)
  - Shadow mode: computes assignments and returns structured responses to the model but does not persist.

## Safety and Limits

- Max 5 labels per call (config constant `kMaxLabelsPerAssignment`).
- Group exclusivity: one label per group enforced per task.
- Rate limiting: prevents repeat assignments to the same task for 5 minutes.
- Prompt bloat protection: injected label list capped at 100 entries (50 by usage + 50 alphabetical).
- JSON encoding: All injected data is encoded to avoid prompt injection.

## UI and Undo

- When labels are assigned (non‑shadow mode), a SnackBar appears in Task Details listing label names.
- Tap “Undo” to remove the labels just added by the AI function call.

## Troubleshooting

- “No labels assigned”: The model may have had low confidence or group exclusivity filtered them out.
- “Undo didn’t appear”: Ensure you’re on the Task Details page; the toast only appears in that context.
- “Labels keep getting re‑added”: Check if the rate limiter window has elapsed; the model may try again after 5 minutes.

## Privacy

- Private labels can be excluded from the injected prompt list via `include_private_labels_in_prompts=false`.
- Assigned labels are persisted like any other label change, synced via the existing entity pipelines.

