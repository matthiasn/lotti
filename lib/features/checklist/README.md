# Checklist Feature

The `checklist` feature is currently a small, focused support feature.

It does not own the checklist UI itself. The visible checklist experience lives under `tasks/`. This feature owns the correction-capture service that learns from user edits to checklist item titles and feeds those corrections back into category-level guidance.

## What This Feature Owns

At runtime, this feature owns:

1. capture of meaningful before/after checklist title corrections
2. delayed-save behavior with undo
3. duplicate and trivial-change filtering
4. persistence of correction examples onto categories

That makes it a learning helper for checklist authoring, not a full checklist subsystem.

## Directory Shape

```text
lib/features/checklist/
└── services/
    └── correction_capture_service.dart
```

## Architecture

```mermaid
flowchart LR
  User["User edits checklist title"] --> Capture["CorrectionCaptureService"]
  Capture --> Filter["Normalization + duplicate/trivial-change checks"]
  Filter --> Pending["CorrectionCaptureNotifier"]
  Pending --> Snackbar["Undo snackbar / pending UI"]
  Pending --> Save["Delayed save callback"]
  Save --> CategoryRepo["CategoryRepository"]
  CategoryRepo --> Category["CategoryDefinition.correctionExamples"]
```

The important detail is that the service does not save immediately. It creates a pending correction and gives the user a brief chance to undo it.

## Correction Capture Flow

```mermaid
sequenceDiagram
  participant User as "User"
  participant Service as "CorrectionCaptureService"
  participant Notifier as "CorrectionCaptureNotifier"
  participant Repo as "CategoryRepository"

  User->>Service: captureCorrection(categoryId, before, after)
  Service->>Service: normalize text
  Service->>Service: reject no-op / trivial changes
  Service->>Repo: load category
  Repo-->>Service: category
  Service->>Service: reject duplicate (vs category.correctionExamples)
  Service->>Notifier: setPending(pending, onSave)
  Notifier-->>User: pending correction visible with undo
  alt user cancels
    User->>Notifier: cancel()
    Notifier->>Notifier: clear pending state
  else timer expires
    Notifier->>Service: onSave()
    Service->>Repo: re-fetch category
    Repo-->>Service: latest category (or null)
    alt category not found or pair now duplicate
      Service->>Service: log + abort (no update)
    else still valid
      Service->>Repo: update category correctionExamples
    end
    Notifier->>Notifier: clear pending state
  end
```

## Pending-Correction State Machine

`CorrectionCaptureNotifier.state` is typed `PendingCorrection?`, so the notifier
itself is binary: `null` (Idle) or a non-null `PendingCorrection` (Pending). The
save phase is a transient step inside the timer callback — while `await onSave()`
runs, `state` is still the same pending value and is only set to `null` after the
await completes (whether the save succeeds or throws). There is no represented
`Saving` state.

```mermaid
stateDiagram-v2
  [*] --> Idle
  Idle --> Pending: setPending(...)
  Pending --> Idle: cancel()
  Pending --> Idle: timer expires, await onSave() completes (state cleared)
  Pending --> Idle: timer expires, onSave() throws (logged, state still cleared)
```

The save delay is currently `kCorrectionSaveDelay = 5 seconds`.

## What Counts as a Meaningful Correction

`CorrectionCaptureService` deliberately ignores:

- missing category IDs
- changes that normalize to the same text (after `normalizeWhitespace`)
- trivial edits — today the only trivial-change rule is narrow: case-only edits
  to texts shorter than 3 characters (`_isMeaningfulCorrection`). Everything else
  is treated as meaningful.
- duplicates already stored on the category (`before`/`after` pair), re-checked
  at save time in case another correction landed during the delay

That filtering matters because otherwise the feature would happily learn from noise and gradually turn category correction examples into a landfill of whitespace tweaks and accidental taps.

## Persistence Model

Corrections are stored on the category as `ChecklistCorrectionExample` entries. That means the learned correction examples are scoped by category rather than globally across the whole app.

That is a good fit for the problem:

- checklist wording often depends on context
- categories already provide the semantic grouping
- prompt-building layers already consume category-specific examples (see Relationship to Other Features)

## Relationship to Other Features

- `tasks` owns checklist UI, drag/drop, and item orchestration
- `categories` owns the category entities this feature updates
- `ai` and agentic flows already consume the stored correction examples as guidance: the AI prompt builder resolves them into the `{{correction_examples}}` placeholder for audio transcription (`PromptBuilderHelper._buildCorrectionExamplesPromptText`), and the agent task prompt builder injects them via `CorrectionExamplesBuilder.buildContext`

This feature is intentionally narrow today, but it does a useful job: it turns "the user fixed the wording" into structured signal instead of throwing that knowledge away.
