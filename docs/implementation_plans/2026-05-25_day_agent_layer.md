# Day Agent Layer — Implementation Plan

**Date:** 2026-05-25
**Status:** Plan committed; awaiting selection of phase-1 starting slice
**Scope:** Agentic layer that powers the Daily OS surface (9 screens in `Claude_Design/design_handoff_daily_os/`). Mirrors the existing task-agent layer in `lib/features/agents/`, scoped to one agent instance per calendar date.

---

## Goal

Build a day-level agent layer that:

1. Mirrors the existing task-agent architecture (identity, state, templates, tools, wake orchestration, sync) — no parallel infrastructure.
2. Creates **one `AgentIdentityEntity` per calendar date**, which dies at shutdown. Observations flow to a shared, evolving template.
3. Improves over time via the existing `TemplateEvolutionWorkflow` (weekly ritual, ≥3 feedback items threshold).
4. Exposes the tool surface required to back every interactive affordance across the 9 Daily OS screens.

## Non-goals

- Calendar integration (deferred — `draft_day_plan` accepts an empty `calendarBlocks` list).
- New STT pipeline (route `submit_capture` through `features/speech`).
- Screen 9 (Tasks corpus browser) — pure read surface, no agent involvement.
- New persistence tables. All data rides on `agent_entities` / `agent_links` (type-tagged Drift rows in `agent.sqlite`).

---

## A. Mirror of the task-agent model

| Task layer (today) | Day layer (proposed) | Notes |
|---|---|---|
| `AgentIdentityEntity { kind: 'task_agent' }` | `AgentIdentityEntity { kind: 'day_agent' }` | Reuse the existing entity; only the discriminator changes |
| `AgentSlots.activeTaskId` | `AgentSlots.activeDayId` | Add field to `AgentSlots` (additive, backward-compatible) |
| `AgentStateEntity` (revisioned) | Same; one chain per `DayId` | No new table — `agent_entities` is type-tagged |
| `TaskAgentService.createTaskAgent()` | `DayAgentService.createDayAgent(date)` | Lazy-create on first capture, not on midnight tick |
| `TaskAgentWorkflow.execute()` | `DayAgentWorkflow.execute()` | Reads day + corpus + calendar context; writes via tools |
| `TaskAgentStrategy.executeToolHandler` | `DayAgentStrategy.executeToolHandler` | New tool registry below |
| One identity per Task | **One identity per Day** | Identity dies at shutdown; template carries the learning |
| `task_agent` template (Laura) | `day_agent` template ("Shepherd") — seeded default | Shared across all day-instances |
| Wake on task update via subscription | Wake on capture submit / refine voice / **self-scheduled morning slot** | Same `WakeOrchestrator` / `ScheduledWakeManager` |

The thing that survives across days is the **template + observations + change-set ledger** — exactly the task pattern.

## B. Decisions (locked)

1. **Identity granularity:** per-date. New `DayAgentIdentityEntity` per calendar date. Observations provenance is cleaner ("this learning came from 2026-05-17").
2. **Wake timing:** **the agent decides for itself** when to schedule the morning pre-warm. Exposed as the `set_next_wake({at, reason})` tool. The `TemplateEvolutionWorkflow` refines wake timing over weeks via the same feedback path as everything else.
3. **Calendar integration:** deferred. `draft_day_plan` takes `calendarBlocks: []` for now.
4. **Speech:** route `submit_capture` through `features/speech`. No new STT path.
5. **Refine diffs:** persisted as `ChangeSetEntity` (existing structure). Survives refresh; gives replay + audit.

## C. New / extended types

- `AgentSlots` — add `activeDayId: String?`. Additive; existing rows tolerate null.
- `AgentKind` enum — add `day_agent`.
- `DayAgentConfig` (extends `AgentConfig`): capacity minutes, working-hours window, energy bands, max refinement rounds.
- `Day` aggregate already exists via `DayPlanRepository`. Add: `state: drafted|committed`, `reflection`, `metrics`.
- `TimeBlock` — already conceptually present in `DayPlanRepository.addPlannedBlock`. Add: `reason: String?`, `type: ai|cal|buffer|manual`, `state: drafted|committed|in_progress|completed|dropped`. **`reason` is mandatory for `type=ai`** — enforced at the tool-handler level so no AI placement reaches the UI without a WhyChip payload.

No new Drift tables. All persistence rides on `agent_entities` / `agent_links` exactly like task agents.

## D. Template + improvement cycle

Same machinery, scoped to day:

1. Seed one `AgentTemplateEntity` of kind `day_agent` and an initial `AgentTemplateVersionEntity` carrying:
   - `generalDirective` — voice/persona, energy-aware scheduling, capacity discipline, "propose not impose"
   - `reportDirective` — required contents of the for-tomorrow note + learnings card
2. Each day-instance binds to the **head version** at creation time (revision-pinned).
3. **Feedback signals** (reuse `FeedbackExtractionService`):
   - Every refine `accept` / `revert` → typed feedback record
   - Every triage `Drop` / `Defer` → typed feedback record
   - Shutdown `reflection` → unstructured feedback record
   - Carryover ratio + commit→completed delta → quantitative observations
   - Self-scheduled wake outcomes (was the user already up? did they ignore the pre-warm?) → observations that feed wake-time learning
4. `TemplateEvolutionWorkflow` runs on a **weekly** ritual (existing `ScheduledWakeManager` hook). Threshold ≥3 feedback items. Produces a new `AgentTemplateVersionEntity`; user approves; head pointer advances.
5. **Maturity** is a derived projection over `(template_version_count, confirmed_observation_count, days_active)` — fed into the Shutdown "What I've learned" panel and the Drafting reflection-letter variant.

`TemplateEvolutionWorkflow` is template-kind agnostic; we register `day_agent` as a participating kind. No new workflow class.

## E. Tool inventory

Tool names follow `TaskAgentToolNames` style. **Deferred** = needs user confirm before execution (reuses the existing `ChangeSetEntity` proposal path).

### Screen 1 — Capture
| Tool | Input | Output | Deferred |
|---|---|---|---|
| `submit_capture` | `{transcript, audioRef?, capturedAt}` | `{captureId}` | no |

### Screen 2 — Reconcile
| Tool | Input | Output | Deferred |
|---|---|---|---|
| `parse_capture_to_items` | `{captureId}` | `ParsedItem[]` (kind=NEW/MATCHED/UPDATE, confidence, low-conf flag) | no — inference |
| `match_to_corpus` | `{phrase, categoryHint?}` | `{candidates: [{taskId, score}], best}` | no |
| `link_capture_phrase_to_task` | `{captureItemId, taskId}` | mutation | no |
| `break_capture_link` | `{captureItemId}` | mutation | no |
| `create_task_from_phrase` | `{phrase, category, estimate?, dueAnchor?}` | `{taskId}` | **yes** |
| `surface_pending_decisions` | `{dayId}` | `PendingItem[]` (overdue, in-progress, missed-recurring, due-today) | no |
| `apply_triage` | `{taskId, action: today\|doNow\|defer\|done\|drop, deferTo?}` | mutation | no |

### Screen 3 — Drafting
| Tool | Input | Output | Deferred |
|---|---|---|---|
| `draft_day_plan` | `{dayId, captureId, decidedTaskIds, calendarBlocks}` | `DraftPlan` (blocks + reasons) | no — long-running |
| `summarize_recent_patterns` | `{dayId, lookbackDays}` | learning-card payload (yesterday, week-so-far, gentle-nudge) | no |
| `compose_reflection_letter` | `{dayId, lookbackDays}` | letter text (Variant C) | no |

### Screens 4/5 — Agenda + Day
| Tool | Input | Output | Deferred |
|---|---|---|---|
| `place_block` | `{dayId, taskId?, start, end, type, category, reason}` | `{blockId}` | **yes** if `type=ai` and day is drafted |
| `move_block` | `{blockId, newStart, newEnd, reason}` | mutation | yes |
| `resize_block` | `{blockId, edge: start\|end, newTime, reason}` | mutation | yes |
| `drop_block` | `{blockId, reason}` | mutation | yes |
| `add_buffer` | `{dayId, start, end, reason}` | `{blockId}` | no |
| `update_agenda_outcome` | `{agendaItemId, outcomeText}` | mutation | no |
| `update_block_reason` | `{blockId, reason}` | back-fills WhyChip if missing | no |

### Screen 6 — Refine
| Tool | Input | Output | Deferred |
|---|---|---|---|
| `propose_plan_diff` | `{dayId, voiceTranscript}` | `Diff{moved[], added[], dropped[], reasons[]}` persisted as `ChangeSetEntity` | **yes** (entire UX) |
| `accept_diff` | `{diffId}` | applies via `move_block`/`place_block`/`drop_block` | no |
| `revert_diff` | `{diffId}` | discard | no |

### Screen 7 — Commit
| Tool | Input | Output | Deferred |
|---|---|---|---|
| `commit_day` | `{dayId}` | sets `Day.state=committed`; locks blocks | **yes** (signature moment) |

After commit, the strategy gates the tool surface: only `record_block_progress` and `nudge` remain enabled.

### Screen 8 — Shutdown
| Tool | Input | Output | Deferred |
|---|---|---|---|
| `record_reflection` | `{dayId, text, source: typed\|voice}` | persist to Logbook journal entry | no |
| `record_carryover_decision` | `{taskId, action: tomorrow\|date\|drop, when?}` | mutation | no |
| `generate_tomorrow_note` | `{dayId}` | text | no |
| `record_observation` | `{observation, confidence}` | reused from existing | no |
| `propose_preference` | `{key, value, source}` | adds to "What I've learned" with `confirmed=false` | **yes** |
| `confirm_preference` / `retract_preference` | user actions | flip flag | no |

### Cross-cutting
| Tool | Input | Output | Deferred |
|---|---|---|---|
| `set_next_wake` | `{at, reason}` | writes `AgentStateEntity.scheduledWakeAt` | no |
| `update_report` | accumulates for-tomorrow note body | reused from existing | no |
| `retract_suggestions` | agent self-retraction, no feedback signal | reused | no |
| `propose_directives` | template-evolution path | reused | n/a |

**Total new tool definitions: ~25.** Comparable to the current `TaskAgentToolNames` surface.

## F. Wake triggers

| Trigger | Source | Workflow entry |
|---|---|---|
| Capture submitted | `submit_capture` → UpdateNotifications | `DayAgentWorkflow.execute(reason: capture)` |
| Triage applied | UI mutation | `DayAgentWorkflow.execute(reason: reconcile)` |
| Refine voice ended | UI | `DayAgentWorkflow.execute(reason: refine)` with transcript |
| Block dragged | UI | `DayAgentWorkflow.execute(reason: replan)` — re-proposes diff |
| **Self-scheduled morning ritual** | `ScheduledWakeManager` reading `scheduledWakeAt` set by `set_next_wake` | pre-warm draft so it's ready when user opens Capture |
| Shutdown opened | UI | `DayAgentWorkflow.execute(reason: shutdown)` |
| Weekly template improvement | `ScheduledWakeManager` | `TemplateEvolutionWorkflow` |

Single-flight per `(dayId, reason)` via the existing `WakeQueue` dedupe.

## G. File layout (new)

```text
lib/features/daily_os_next/agents/
  domain/
    day_agent_kind.dart            // enum const, registration
    day_agent_slots.dart           // AgentSlots extension
    day_agent_config.dart
  service/
    day_agent_service.dart         // create/pause/reanalyze, mirrors TaskAgentService
  workflow/
    day_agent_workflow.dart        // context assembly + inference loop
    day_agent_strategy.dart        // implements AgentStrategy, routes tools
  tools/
    day_agent_tool_names.dart
    day_agent_tools.dart           // AgentToolDefinition list + JSON schemas
    handlers/
      capture_handlers.dart
      reconcile_handlers.dart
      plan_handlers.dart           // place/move/resize/drop/buffer
      refine_handlers.dart         // propose_diff, accept, revert
      commit_handlers.dart
      shutdown_handlers.dart
      wake_handlers.dart           // set_next_wake
  templates/
    day_agent_template_seed.dart   // initial general + report directives
  state/
    day_agent_providers.dart       // @riverpod accessors used by UI
```

Tests mirror the source tree under `test/features/daily_os_next/agents/...`. One test file per source file.

## H. Phasing (smallest valuable unit first)

1. **Foundation** — extend `AgentSlots` with `activeDayId`; register `day_agent` kind; seed template; wire `DayAgentService` + `DayAgentWorkflow` skeleton; register strategy. Tools: `record_observation` + `set_next_wake` only. Verifiable: agent wakes, logs, schedules its next wake, no-ops everything else.
2. **Capture + Reconcile tools** — Screens 1 + 2. Hardest matching logic, highest trust risk; ship it early.
3. **Drafting + place_block** — Screens 3 + 5 (Day view). Skip Agenda projection initially; the Day timeline is the source of truth.
4. **Refine** — Screen 6. Diff is now visible via `ChangeSetEntity` proposals; the trust loop closes.
5. **Commit + post-commit gating** — Screen 7 + strategy state machine narrowing the tool surface.
6. **Shutdown + preference learning** — Screen 8 + `propose_preference` / `confirm_preference`.
7. **Agenda projection** — Screen 4 as a read-only view over the same blocks.
8. **Maturity surfaces** — wire the "What I've learned" panel; turn on `TemplateEvolutionWorkflow` for `day_agent`.

## I. Verification gates

Each phase must pass before the next is started:

- `make analyze` — zero warnings or infos (project-wide zero-warning policy).
- `fvm dart format .` clean.
- `flutter test` for the changed files plus the existing `lib/features/agents/` test suite (regression guard on shared types like `AgentSlots`).
- Coverage: full-line coverage on changed code (per project rule).
- The phase's user-facing affordance is exercised end-to-end against a real day instance, not just unit-tested.

## J. Risks

- **`AgentSlots` schema migration.** Adding `activeDayId` is additive but every consumer that destructures `AgentSlots` needs updating. Audit `lib/features/agents/` for exhaustive matches before merging.
- **One-agent-per-day cost.** N days = N `AgentIdentityEntity` rows + state revision chains. Need a retention policy: archive identities beyond a threshold (90 days?) to keep `agent.sqlite` bounded. Open question deferred to phase 8.
- **Tool surface bloat.** ~25 new tools is the bulk of the current task-agent surface again. Strategy-level gating by `Day.state` (drafted vs committed) is essential to keep prompt context tight.
- **Self-scheduled wakes.** A buggy `set_next_wake` could wake the agent every minute. Strategy enforces a minimum interval (15 min?) and a daily wake-count cap.

## K. Open follow-ups (out of scope for this plan)

- Retention/archive policy for old `DayAgent` identities.
- Whether the maturity-aware copy variants in `closing.jsx → maturityCopy` should be string templates owned by the Dart side or live in the template's `reportDirective`.
- Whether `propose_plan_diff` should chain — multiple refinement rounds before a single `accept_diff` — or whether each round is its own change-set.
