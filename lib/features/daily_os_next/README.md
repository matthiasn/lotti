# Daily OS Next

Daily OS Next is the clean-room home for the next Daily OS runtime. New agentic
planning code lives here so it can evolve without depending on the current
`features/daily_os` implementation.

The exception is the shared day-plan aggregate in `lib/classes/day_plan.dart`.
That model is already the durable representation of a day, so Daily OS Next
should extend it instead of creating a second day-plan store. New agent code can
reuse `DayPlanData`, `PlannedBlock`, `PinnedTaskRef`, and `dayPlanId`; it should
not depend on the existing Daily OS UI controllers.

## Agent Runtime

The day-agent layer under `agents/` reuses the shared agent infrastructure from
`features/agents` and adds only the Daily OS Next runtime surface area. The
current backend supports the foundation wake plus Capture/Reconcile tool paths;
the Flutter UI integration is intentionally separate.

```mermaid
flowchart TD
  Template["Shepherd template"] --> Identity["day_agent identity"]
  Identity --> State["AgentState.activeDayId"]
  State --> Wake["DayAgentWorkflow"]
  Wake --> Strategy["DayAgentStrategy"]
  Strategy --> Observe["record_observations"]
  Strategy --> Schedule["set_next_wake"]
  Strategy --> CaptureTools["capture/reconcile tools"]
  CaptureTools --> CaptureService["DayAgentCaptureService"]
  CaptureService --> Entities["agent_entities: capture + parsedItem"]
  CaptureService --> Links["agent_links: capture_to_parsed_item + parsed_item_to_task"]
  CaptureService --> Tasks["JournalDb tasks"]
  Schedule --> State
```

Runtime behavior:

- `DayAgentService` creates one active `day_agent` identity per local calendar
  day.
- `AgentSlots.activeDayId` stores the deterministic day subject ID
  (`dayplan-YYYY-MM-DD`).
- Day-agent lookup is repository-backed by `activeDayId`; the service does not
  hydrate every active day-agent state just to find one calendar day.
- The shared template service seeds the `Shepherd` day-agent template.
- `DayAgentWorkflow` builds the prompt from template directives, recent private
  observations, and, for `capture_submitted:<captureId>` wakes, the submitted
  capture plus a bounded task corpus snapshot.
- `DayAgentStrategy` handles private observations itself and delegates
  `set_next_wake` plus Capture/Reconcile tools through the workflow handler.
- `DayAgentCaptureService` owns direct Capture/Reconcile mutations:
  `submit_capture`, `parse_capture_to_items`, `match_to_corpus`,
  `link_capture_phrase_to_task`, `break_capture_link`,
  `surface_pending_decisions`, `apply_triage`, and
  `create_task_from_phrase`.
- `submit_capture` persists a `CaptureEntity` and enqueues a manual wake with a
  `capture_submitted:<captureId>` trigger token.
- `parse_capture_to_items` persists `ParsedItemEntity` rows and links them to
  the source capture. High-confidence matches (`>= 0.75`) auto-link to tasks,
  medium-confidence matches (`0.5..0.75`) auto-link with `lowConfidence`, and
  low-confidence items stay as new capture items.
- `create_task_from_phrase` writes a pending `ChangeSetEntity` proposal instead
  of directly creating a task.
- Wakes consume any `scheduledWakeAt` timestamp that is no longer in the future
  so app restart does not replay an already-fired scheduled wake.
- Future Daily OS Next planning, refine, commit, and shutdown tools should be
  added under this feature without importing `features/daily_os`.

```mermaid
stateDiagram-v2
  [*] --> Captured: submit_capture
  Captured --> WakeQueued: enqueueManualWake(capture_submitted)
  WakeQueued --> ParsingWake: DayAgentWorkflow.execute
  ParsingWake --> Parsed: parse_capture_to_items
  Parsed --> Linked: link_capture_phrase_to_task
  Linked --> Parsed: break_capture_link
  Parsed --> Proposal: create_task_from_phrase
  Parsed --> TaskMutated: apply_triage
```

## Testing Strategy

Pure day-plan and day-agent logic should use Glados property tests whenever an
invariant is easier to state than to cover with examples:

- date normalization and `dayplan-YYYY-MM-DD` identity stability
- Capture/Reconcile confidence threshold classification
- pending-decision dedupe and sort priority
- `DayPlanData` derived durations, category grouping, and JSON round-trips
- future tool validators such as required AI block reasons, positive block
  durations, non-overlap rules, and commit-state gating
- future diff application/reversion once refine tools produce `ChangeSetEntity`
  proposals

Service and workflow tests should stay deterministic example tests with mocks,
fixed clocks, and no real timers. They should verify transaction boundaries,
wake scheduling, persisted state changes, and tool error paths. Glados belongs
on pure model/validator/diff logic, not on mocked I/O orchestration.
