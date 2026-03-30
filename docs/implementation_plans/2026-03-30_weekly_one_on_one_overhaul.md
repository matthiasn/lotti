# Weekly One-on-One Overhaul

## Summary

Rebuild the weekly one-on-one feature around app-native cards, compact
history, and a complaint-first ritual flow. The implementation should remove
capped and low-value metrics, surface real wake and token data, persist
session recaps for history, render markdown consistently, filter noisy
rejected checklist signals, and let the user negotiate directive updates
directly in chat until a new template version is approved.

This plan replaces the current review-first experience with a session-first
ritual home and narrows the visible data down to signals that actually help
improve the agent.

## Goals

- Replace the current feedback-heavy ritual entry surface with a history-first
  one-on-one home.
- Use app-native card and button patterns already present in the projects and
  design-system surfaces instead of maintaining a separate evolution look.
- Remove invalid and low-signal metrics from the ritual UI.
- Persist enough one-on-one output to show meaningful history with ratings,
  TLDR, markdown summary, transcript, and approved changes.
- Keep grievances and human-centered language complaints prominent from
  extraction through prompt construction and presentation.
- Standardize markdown rendering across ritual chat and history detail.

## Non-Goals

- Do not keep both the current review-first flow and the new ritual-home flow
  in parallel.
- Do not preserve the current success-rate-driven charts or the version chart.
- Do not reconstruct past ritual history from ephemeral in-memory conversation
  state.

## Findings

### Current UI architecture

- The template detail CTA routes to the ritual review page from
  `lib/features/agents/ui/agent_template_detail_page.dart`.
- The current ritual entry page is
  `lib/features/agents/ui/evolution/evolution_review_page.dart`.
- Live chat is rendered in
  `lib/features/agents/ui/evolution/evolution_chat_page.dart`.
- The top-of-chat dashboard is implemented in
  `lib/features/agents/ui/evolution/widgets/evolution_dashboard_header.dart`.
- Historical session UI is spread across
  `lib/features/agents/ui/evolution/widgets/evolution_history_dashboard.dart`
  and
  `lib/features/agents/ui/evolution/widgets/evolution_session_timeline.dart`.

### Current data and workflow architecture

- Template metrics come from
  `AgentTemplateService.computeMetrics()` in
  `lib/features/agents/service/agent_template_service.dart`.
- That method calls `getWakeRunsForTemplate(templateId, limit: 500)`, so the
  displayed total wakes value is capped and invalid for lifetime totals.
- Wake-run charts are built from
  `templateWakeRunTimeSeriesProvider` in
  `lib/features/agents/state/wake_run_chart_providers.dart`, which currently
  fetches uncapped wake runs and computes daily and per-version series.
- Session metadata is stored in `EvolutionSessionEntity`, which currently only
  holds fields such as `feedbackSummary` and `userRating`.
- The evolution workflow deletes the in-memory conversation on cleanup in
  `TemplateEvolutionWorkflow`, so the current architecture cannot show rich
  history transcripts after a session completes.

### Current prompt and feedback behavior

- Ritual prompts are built in
  `lib/features/agents/workflow/evolution_context_builder.dart` and
  `lib/features/agents/workflow/ritual_context_builder.dart`.
- The seeded template improver directive is defined in
  `lib/features/agents/model/seeded_directives.dart`.
- Feedback extraction is implemented in
  `lib/features/agents/service/feedback_extraction_service.dart`.
- Rejected change decisions are currently turned into negative feedback
  generically, which causes rejected checklist completions to flood the ritual
  UI and prompt even when they have no explanatory value.

### Design-system alignment targets

- Reusable app-native card surfaces already exist via `ModernBaseCard`.
- Primary and secondary call-to-action buttons already exist via
  `LottiPrimaryButton` and `LottiSecondaryButton`.
- Project UI already demonstrates grouped-card, summary-row, and expandable-row
  patterns in widgets such as `ProjectHealthHeader`.

## Implementation Plan

## Status

Audit date: 2026-03-31

Overall status: Partial

- Implemented: 1, 2, 3, 4, 8
- Partial: 5, 6, 7
- Not started: none identified in this audit

The statuses below reflect the current repository state after the follow-up
test and README updates made on 2026-03-31.

### 1. Write the plan into the repo

Status: Implemented

This document exists at the planned path.

- Add this document to
  `docs/implementation_plans/2026-03-30_weekly_one_on_one_overhaul.md`.

### 2. Replace the ritual entry architecture

Status: Implemented

Implemented in the current `EvolutionReviewPage` plus the new ritual summary
and history widgets. The entry surface is now history-first, uses app-native
cards and buttons, and no longer centers raw classified feedback as the main
experience.

- Keep the template detail CTA, but route it into a session-first ritual home
  instead of the current feedback-summary-first page.
- Rebuild the ritual home around:
  - a pending-session card at the top when a ritual is active
  - a compact summary strip with the retained metrics
  - a chronological history list as the primary content
- Demote raw classified feedback to a secondary surface rather than the main
  entry experience.
- Use `ModernBaseCard` for summary and history cards.
- Use `LottiPrimaryButton` and `LottiSecondaryButton` for the main ritual
  actions.
- Borrow grouped-card layout and spacing conventions from project surfaces
  rather than keeping the current custom evolution visual language.

### 3. Replace the current metrics model

Status: Implemented

Implemented via the new uncapped wake-count and windowed wake-history APIs in
`AgentTemplateService` / `AgentRepository`, plus
`ritualSummaryMetricsProvider`. The retained ritual surfaces now use lifetime
wake count, wakes since last session, token usage since last session, MTTR,
and the 30-day wake chart instead of the removed success/version metrics.

- Stop using `computeMetrics(limit: 500)` as the source of displayed total
  wakes.
- Add a repository/service API that returns the actual uncapped lifetime wake
  count for a template.
- Split the current metrics path into two dedicated read models:
  - ritual summary metrics
  - recent 30-day wake history
- The ritual summary metrics model must include:
  - lifetime wake count
  - wakes since the most recent completed one-on-one
  - total token usage since the most recent completed one-on-one
  - mean time to resolution
- The 30-day wake-history model must:
  - load only the last 30 days of wake runs
  - return daily buckets for that range
  - include dates suitable for labeled chart rendering
- Remove these from ritual summary and ritual chat surfaces:
  - success rate
  - success trend
  - version performance
  - MTTR trend chart
  - active instance count

### 4. Introduce persisted ritual recap payloads

Status: Implemented

Implemented via `EvolutionSessionRecapEntity`, DB support, repository/service
read APIs, recap persistence in `TemplateEvolutionWorkflow`, and lazy loading
of recap-backed history entries in `ritualSessionHistoryProvider`.

- Keep `EvolutionSessionEntity` as the index record for session list queries.
- Add a new session-linked persisted recap payload entity rather than bloating
  `EvolutionSessionEntity` with large markdown or transcript data.
- Persist the following when a session is completed:
  - category ratings
  - TLDR
  - markdown recap body
  - approved-change summary
  - transcript snapshot
- Link the recap payload to the session so history screens can fetch details
  lazily.
- Extend the approval/completion path in `TemplateEvolutionWorkflow` so recap
  persistence happens as part of successful completion.

### 5. Rework the ritual chat flow

Status: Partial

Implemented:

- the old dashboard was replaced with the compact `RitualSummaryCard`
- the retained metrics and 30-day chart are present in chat
- the proposal loop still supports revision and approval

Still missing or not yet aligned with this plan:

- the ritual system prompt is still explicitly category-rating-first and
  still frames the opening as a feedback summary rather than the planned
  complaint-first opening sequence
- the current prompt still says to always request category ratings in Phase 1,
  so category ratings still dominate the conversation more than planned

- Replace the current top-of-chat metrics dashboard with a compact stats card.
- The stats card should include:
  - wakes since last one-on-one
  - token usage since last one-on-one
  - mean time to resolution
  - a single 30-day wake activity chart with date labels
- Keep the card visually secondary and low-height.
- Adjust the ritual opening turn instructions so the assistant starts with:
  - what bothered the user
  - what the user liked
  - what seems to need changing
  - a concise invitation for anything else the user wants to add
- Remove self-praise about deterministic success or 100% success rate from the
  ritual prompt.
- Keep proposal rendering tool-backed, but allow the surrounding chat to behave
  as a negotiation loop:
  - assistant proposes concrete directive language
  - user pushes back in chat
  - assistant revises
  - approval creates the new template version

### 6. Tighten feedback extraction and prioritization

Status: Partial

Implemented:

- explicit high-priority grievances are surfaced first in
  `RitualContextBuilder`
- structured grievance/template-improvement observations are not flattened by
  generic text heuristics

Still missing or not yet aligned with this plan:

- rejected checklist completions are still classified generically as negative
  feedback in `FeedbackExtractionService`
- this audit did not find plan-specific filtering that suppresses checklist
  rejection noise unless explanatory context exists
- this audit also did not find a dedicated end-to-end rule for preserving
  “resources” language complaints as a named critical grievance path

- Filter rejected checklist completions out of extracted ritual feedback unless
  they include explanatory context such as:
  - a rejection reason
  - a note
  - or another linked explanatory signal
- Implement the filtering in `FeedbackExtractionService` so both the ritual UI
  and the ritual prompt stop receiving the noise.
- Preserve and prioritize explicit grievances:
  - do not let generic negative heuristics flatten explicit grievance or
    template-improvement observations into routine negative items
  - keep high-priority grievances ahead of all general feedback in ritual
    context assembly
- Ensure human-centered language complaints, including “resources” language,
  remain critical grievances end to end.

### 7. Rewrite ritual prompts and improver defaults

Status: Partial

Implemented:

- proposals still require complete rewritten directive text instead of diffs
- the conversation still supports rejection and revision

Still missing or not yet aligned with this plan:

- `RitualContextBuilder` still instructs the assistant to summarize feedback
  and request category ratings in Phase 1 before proposing
- the prompt language is not yet the planned complaint-first,
  negotiation-oriented opening
- `templateImproverGeneralDirective` has not yet been rewritten to include the
  stricter human-centered language rules, “resources” ban, and direct
  one-on-one opening style called for here

- Update the ritual system prompts in the context builders so Phase 1 is:
  - complaint-first
  - concise
  - negotiation-oriented
- Update the seeded template improver directive defaults so they include:
  - strict human-centered language
  - explicit ban on referring to people as “resources”
  - preference for user-impact and grievances over mechanical success logging
  - direct and concise one-on-one openings
- Keep the two-phase shape, but stop letting category ratings dominate the
  experience. They should inform the proposal, not overwhelm the conversation.
- Preserve the requirement that proposals contain the full rewritten directive
  text instead of diffs.

### 8. Standardize markdown rendering

Status: Implemented

Implemented via `AgentMarkdownView`, which is now reused across assistant chat
content and persisted history/recap surfaces instead of maintaining separate
raw-text rendering paths.

- Use a single markdown rendering path for ritual assistant-authored content.
- Apply it to:
  - assistant chat bubbles
  - persisted session recap detail
  - approved changes detail
  - proposal rationale or recap sections shown in history
- Replace raw `Text` widgets in recap/history/detail surfaces where the content
  is authored markdown.
- Ensure headings, lists, emphasis, and spacing render cleanly in both chat and
  expanded history sections.

## Public Interfaces / Types

- Add a repository/service API for uncapped lifetime wake counts for a
  template.
- Add a repository/service API for recent 30-day wake history only.
- Add a ritual summary provider/view model that supplies:
  - lifetime wake count
  - wakes since last completed session
  - token usage since last completed session
  - mean time to resolution
  - 30-day daily wake buckets
- Add a persisted ritual recap payload type linked to `EvolutionSessionEntity`.
- Extend session completion so it persists:
  - ratings
  - TLDR
  - recap markdown
  - transcript snapshot
  - approved-change summary

## Test Plan

### Repository and service tests

- Actual lifetime wake count is uncapped.
- 30-day wake query only includes runs in the requested date window.
- Token-usage-since-last-session aggregation uses the correct lower bound.

### Feedback extraction tests

- Rejected checklist completions without notes are excluded.
- Rejected checklist completions with rejection reasons or notes are retained.
- Explicit grievance observations remain high-priority grievances.
- Human-centered language complaints are not drowned out by generic negative
  signals.

### Workflow tests

- Session approval persists recap payload and ratings.
- Session history can render TLDR plus expanded transcript data.
- Proposal rejection followed by revision preserves the negotiation loop until
  approval.

### Widget tests

- Ritual home shows history list as the primary surface.
- Pending-session card appears when a ritual is active.
- Compact stats card shows only the retained metrics.
- Removed charts and removed metrics are no longer rendered.
- The 30-day wake chart shows date labels.
- History items expand into markdown-rendered recap and transcript.
- Markdown rendering handles headings, lists, emphasis, and directive text.

### Regression tests

- The template detail CTA still routes correctly.
- Chat still supports ratings submission and proposal approval/rejection.
- No ritual UI still displays the capped `500` total wakes or `100% success
  rate`.

## Assumptions and Defaults

- Use this file path:
  `docs/implementation_plans/2026-03-30_weekly_one_on_one_overhaul.md`.
- Persist detailed session history in a linked payload entity rather than
  overloading `EvolutionSessionEntity`.
- Replace the current review-first ritual entry rather than keeping both flows
  in parallel.
- Reuse app-native card/button/layout patterns from existing shared widgets and
  project surfaces instead of introducing a new evolution-specific component
  family.
- Treat the 30-day wake chart as the only retained chart in ritual surfaces.
- Use complaint-first assistant phrasing by default, even when positive signals
  exist.
