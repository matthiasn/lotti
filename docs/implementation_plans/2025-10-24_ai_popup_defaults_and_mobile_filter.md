# AI Popup Default Highlight & Mobile Local-Model Filter Plan

## Summary

- Make the AI Assistant modal clearly denote which prompt is configured as the automatic default
  without reshuffling the list order.
- Prevent mobile clients from surfacing local-only inference options (Whisper local, Ollama, Gemini
  3N local) so users are never offered unusable automations.
- Stay aligned with repository process: use MCP tooling, keep analyzer/tests green, update
  READMEs/CHANGELOG, avoid touching generated L10N files. Also see AGENTS.md

## Goals

- Introduce UI affordances (gold microphone/icon outline, supporting stroke) that visually mark the
  default prompt in the AI popup bottom sheet across cards, checklists, and audio categories.
- Ensure state management and data providers surface the default flag so widgets can render it
  consistently.
- Filter out local-only models on mobile surfaces for both manual selection and automatic default
  presentation, gracefully handling scenarios where the stored default becomes unavailable.
- Cover the feature with widget/unit tests, keeping adoption guidance documented for QA and release
  notes.

## Non-Goals

- Changing the existing ordering of prompts in the AI modal or rethinking the modal layout beyond
  the new highlight treatment.
- Altering how users configure defaults in settings or introducing new default-selection workflows.
- Enabling remote execution of local models; instead, we simply hide them where unsupported.
- Building backend detection for availability—assume client-side knowledge of platform capabilities.

## Current Findings

- AI prompt metadata already includes a flag for the default automatic inference model, but the UI
  renders all list tiles identically (see `lib/features/ai_assistant/widgets/...`).
- Mobile builds share the same prompt catalog as desktop; the filter layer does not differentiate
  between local and cloud execution targets, so local Whisper/Ollama entries slip through.
- When the default prompt points at a local engine, the modal still selects it by default and
  presents it for manual execution, leading to confusing errors.
- There is no automated test coverage ensuring the modal hides unsupported entries or highlighting
  is applied to the default tile.

## Design Overview

1. **Default Indicator Treatment**
  - Apply a gold-accent theme to the icon background and card border for whichever prompt is the
    configured default.
  - Maintain accessibility by validating contrast ratios and providing semantic labels (e.g.,
    `Default automatic prompt`).
  - Ensure the highlight persists when switching categories or after updating the default.

2. **Capability-Aware Filtering**
  - Define a capability helper in the AI prompt provider that checks platform (mobile vs desktop)
    and model execution type.
  - Exclude prompts flagged as local-only when running on mobile; if the stored default is filtered,
    surface a remote fallback and inform the user (banner/toast) or push to settings.
  - Keep analytics consistent by recording the fallback event.

3. **Documentation & Process**
  - Update feature READMEs outlining UX expectations, QA checklists, and limitations.
  - Document change in `CHANGELOG.md` and add release-note snippets for TestFlight builds.

## Implementation Phases

### Phase 1 – Discovery & UX Alignment

- Inventory prompt metadata shapes (`lib/models/ai_prompt.dart`, service layer).
- Confirm design details with product (gold palette tokens, hit areas, accessibility).
- Decide on fallback messaging for filtered defaults and capture in acceptance criteria.

### Phase 2 – Data & Capability Logic

- Introduce capability helper (e.g., `AiPromptCapabilityFilter`) that inspects
  `PromptModelExecutionType`.
- Wire filtering into the selector powering the modal list and the automatic-default resolver.
- Implement fallback logic when the stored default becomes unavailable on mobile, including
  persistence update.
- Add unit tests covering capability filtering and fallback behavior.

### Phase 3 – UI Updates

- Extend the modal list tile widget to accept a `isDefault` flag and apply gold styling (border,
  icon fill, badge text if needed).
- Ensure focus states, semantics, and interaction remain consistent; update golden/widget tests
  accordingly.
- Verify microinteraction consistency (e.g., shimmering disabled, animations minimal per design
  guidance).

### Phase 4 – QA Collateral & Finalization

- Update relevant READMEs (AI assistant feature guide, mobile UX notes) and `CHANGELOG.md`.
- Capture QA scenarios: default highlight visibility, fallback messaging, mobile vs desktop
  collections.
- Run `dart-mcp.analyze_files`, targeted widget/unit suites, then full `dart-mcp.run_tests`.
- Prepare handoff notes for downstream review chain (Claude review → PR submission →
  Gemini/CodeRabbit follow-ups → TestFlight releases).

## Testing Strategy

- Unit tests for capability filtering (ensure mobile hides local models, defaults fall back
  correctly).
- Widget tests verifying default highlight styling and semantics.

## Risks & Mitigations

- **Missing fallback when default filtered out** — Mitigate with explicit fallback selection and
  user notification; add tests to lock behavior.
- **Visual highlight regressions** — Guard with golden tests and manual QA checklist screenshot
  review.
- **Capability detection drift** — Centralize execution-target metadata and reuse across app to
  avoid divergence.
- **Docs/ChangeLog drift** — Address within Phase 4 and enforce during review.

## Rollout & Monitoring

- Ship behind fully green analyzer/tests; validate on both mobile platforms (iOS, Android) and
  desktop.
- QA to confirm: default highlight clarity, absence of local models on mobile, fallback messaging.
