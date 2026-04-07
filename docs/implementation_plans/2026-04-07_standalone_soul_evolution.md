# Phase 6: Standalone Soul Evolution

## Context

Phases 1–5 built the soul document data model, service, prompt assembly, evolution tools, and management UI. Soul personality can already be evolved during template 1-on-1 rituals via `propose_soul_directives`. Phase 6 adds a **standalone soul evolution flow** — a dedicated 1-on-1 session focused on personality improvement, aggregating feedback from ALL templates that share a soul.

Both flows coexist:
- **Template ritual** — skill-focused, may opportunistically propose soul changes
- **Soul ritual** (new) — personality-focused, aggregates cross-template feedback

## Design Decisions

**Reuse `TemplateEvolutionWorkflow`** rather than creating a parallel class. The session lifecycle (start → message loop → approve → cleanup) is identical. The differences are:
1. Context building uses a soul-focused builder
2. Feedback is aggregated across all templates using the soul
3. Only `propose_soul_directives` tool is offered (no `propose_directives`)
4. Session entity tracks `soulId` instead of `templateId`
5. Approval creates a soul version only

**Approach**: Add a `startSoulSession(soulId)` method to `TemplateEvolutionWorkflow` (or a thin subclass) that gathers cross-template data and builds soul-focused context. The conversation loop, GenUI, and strategy infrastructure remain unchanged.

## Implementation Steps

### Step 1: Soul Evolution Context Builder
**New: `lib/features/agents/workflow/soul_evolution_context_builder.dart`**

Builds context focused on personality evolution across templates:

```dart
class SoulEvolutionContextBuilder {
  EvolutionContext build({
    required SoulDocumentEntity soul,
    required SoulDocumentVersionEntity currentVersion,
    required List<SoulDocumentVersionEntity> recentVersions,
    required List<({String templateId, String displayName})> affectedTemplates,
    required ClassifiedFeedback aggregatedFeedback,
    required List<EvolutionNoteEntity> pastNotes,
    required int sessionNumber,
  })
}
```

**System prompt**: Personality-focused evolution agent role — scope limited to voice, tone, coaching, anti-sycophancy. Mentions `propose_soul_directives` as the ONLY proposal tool. No `propose_directives`.

**Initial user message sections**:
1. Current soul personality (all 4 fields, version number)
2. Templates using this soul (names + kinds — cross-impact awareness)
3. Aggregated classified feedback across all templates (grouped by template, then by sentiment)
4. High-priority section (grievances + excellence from ALL templates)
5. Soul version history (last 5)
6. Past evolution notes (soul-scoped)
7. Session continuity

### Step 2: Cross-Template Feedback Aggregation
**Modify: `lib/features/agents/service/feedback_extraction_service.dart`**

Add method:
```dart
Future<ClassifiedFeedback> extractForSoul({
  required String soulId,
  required DateTime since,
  required DateTime until,
  required SoulDocumentService soulDocumentService,
})
```

Flow:
1. Get all template IDs using this soul via `getTemplatesUsingSoul()`
2. Call `extract()` for each template (parallel via `Future.wait`)
3. Merge items into single `ClassifiedFeedback` with combined window
4. Tag each item with its source template ID for attribution

May need to add `templateId` field to `ClassifiedFeedbackItem` for attribution (currently `agentId` is the instance, not the template).

### Step 3: Soul Session Support in Workflow
**Modify: `lib/features/agents/workflow/template_evolution_workflow.dart`**

Add `startSoulSession({required String soulId})`:
1. Resolve soul + active version + recent versions
2. Get all templates using this soul
3. Aggregate feedback via `FeedbackExtractionService.extractForSoul()`
4. Gather past soul evolution notes
5. Build context via `SoulEvolutionContextBuilder`
6. Create `EvolutionSessionEntity` with `agentId=soulId`, `templateId=soulId`
7. Set up strategy with only soul directive values (no template directives)
8. Tool list: only `propose_soul_directives`, `publish_ritual_recap`, `record_evolution_note`, `render_surface`
9. Start conversation and return opening message

Add `completeSoulSession({sessionId, userRating?, feedbackSummary?, categoryRatings})`:
1. Get `latestSoulProposal` from strategy
2. Create soul version via `SoulDocumentService.createVersion()`
3. Persist notes and recap
4. Update session to `completed` with `proposedSoulVersionId`

### Step 4: Soul Evolution Chat State
**New: `lib/features/agents/ui/evolution/soul_evolution_chat_state.dart`**

Riverpod notifier following `EvolutionChatState` pattern but parameterized by `soulId`:
- `build(soulId)` → calls `workflow.startSoulSession(soulId)`
- `sendMessage()` → same flow, but implicit approval targets soul proposal
- `approveProposal()` → calls `completeSoulSession()`
- No template proposal actions — only soul proposals

### Step 5: Soul Evolution Chat Page
**New: `lib/features/agents/ui/evolution/soul_evolution_chat_page.dart`**

Follows `EvolutionChatPage` structure. Parameterized by `soulId`. Shows:
- Soul name in app bar
- Chat messages with GenUI surfaces
- Input field for user messages
- Standard approve/reject flow for soul proposals

### Step 6: Soul Review Section on Detail Page
**Modify: `lib/features/agents/ui/agent_soul_detail_page.dart`**

Add a "Review" button to the soul detail page (on the bottom bar when not dirty, mirroring the template detail page pattern). Navigates to the soul evolution chat.

Add soul evolution session history to the Info tab (similar to template's evolution history dashboard).

### Step 7: Soul Evolution Providers
**New/modify: `lib/features/agents/state/soul_query_providers.dart`**

Add:
- `soulEvolutionSessionsProvider(soulId)` — all sessions for a soul
- `pendingSoulEvolutionProvider(soulId)` — active session if any

### Step 8: Routing
**Modify: `lib/beamer/locations/settings_location.dart`**

Add:
- `/settings/agents/souls/:soulId/review` — soul evolution chat page

### Step 9: Localization
**Modify: `lib/l10n/app_*.arb`**

Add keys for soul evolution UI (review button label, session titles, system prompts).

### Step 10: Tests

- `test/features/agents/workflow/soul_evolution_context_builder_test.dart`
- `test/features/agents/service/feedback_extraction_service_test.dart` — add tests for `extractForSoul()`
- `test/features/agents/workflow/template_evolution_workflow_test.dart` — add tests for `startSoulSession()` and `completeSoulSession()`
- `test/features/agents/ui/evolution/soul_evolution_chat_state_test.dart`
- Widget tests for soul evolution chat page

## Key Reuse

| Component | Reuse Strategy |
|-----------|---------------|
| `EvolutionStrategy` | Reuse as-is — handles `propose_soul_directives` tool already |
| GenUI catalog | Reuse `SoulProposal` surface, recap, notes, ratings |
| `EvolutionSessionEntity` | Reuse with `agentId=soulId` — no new entity type needed |
| `EvolutionSessionRecapEntity` | Reuse with `agentId=soulId` |
| `EvolutionNoteEntity` | Reuse with `agentId=soulId` |
| `FeedbackExtractionService` | Extend with `extractForSoul()` that wraps per-template `extract()` |
| Conversation infrastructure | Fully reused — same `ConversationRepository` + `CloudInferenceRepository` |
| `ActiveEvolutionSession` | Reuse — `templateId` field used as entity scope identifier |

## Verification
- `dart-mcp.analyze_files` — zero errors
- `dart-mcp.run_tests` on `test/features/agents/` — all pass
- `fvm dart format .` — no changes
- Manual: navigate to soul detail → Review → start session → approve soul change → verify new version
