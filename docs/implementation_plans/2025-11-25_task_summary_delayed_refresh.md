# Delayed Task Summary Refresh with Countdown UX

## Problem Statement

Task summaries are currently triggered too frequently:

- Every checklist item check-off or creation triggers a summary refresh
- Current 500ms debounce is still too aggressive
- While actively working on a task, summaries aren't needed (user is already in context)
- Summaries are only valuable when **returning** to a task to catch up
- Excessive Gemini Pro API usage is driving up costs

## Goals

- Reduce unnecessary API calls while working on a task
- Provide user visibility into when the next summary will be generated
- Give user control: cancel scheduled refresh or trigger immediately
- Maintain a good UX with clear visual feedback

## Proposed Behavior

### State Machine

```
                  ┌─────────────────────┐
                  │       idle          │
                  │  (no refresh        │
                  │   scheduled)        │
                  └──────────┬──────────┘
                             │
              checklist change triggers
                             │
                             ▼
                  ┌─────────────────────┐
                  │     scheduled       │◄──── user cancels
                  │  (countdown shown)  │      (returns to idle)
                  └──────────┬──────────┘
                             │
           countdown expires │ user triggers now
           ─────────────────┴─────────────────
                             │
                             ▼
                  ┌─────────────────────┐
                  │      running        │
                  │  (generating        │
                  │   summary)          │
                  └──────────┬──────────┘
                             │
                   inference completes
                             │
                             ▼
                  ┌─────────────────────┐
                  │       idle          │
                  └─────────────────────┘
```

### UI States

| State         | Header Text                      | Actions                         |
|---------------|----------------------------------|---------------------------------|
| **Idle**      | "AI Task Summary"                | Refresh button (manual trigger) |
| **Scheduled** | "Summary in 4:32" (countdown)    | Cancel (✕), Trigger now (▶)     |
| **Running**   | "Thinking about task summary..." | Spinner (no actions)            |

### Default Delay Duration

- **5 minutes** as the initial value
- Rationale: Long enough that rapid checklist interactions don't trigger multiple summaries, but
  short enough that the summary is generated before the user context-switches away
- Consider making this configurable in settings in the future if needed

### Edge Cases

1. **Multiple checklist changes while scheduled**: Reset the countdown timer (each change pushes out
   the scheduled time) => no actually, countdown keeps ticking, the countdown is a promise that 
   something will happen
2. **App backgrounded/closed**: Scheduled refresh is lost - acceptable since returning to the app is
   effectively "returning to the task" => okay but then we need to show somehow that the latest 
   summary is outdated 
3. **Inference already running when checklist changes**: Queue the scheduled refresh to trigger
   after current inference completes (existing behavior)
4. **User navigates away from task**: Keep timer running - summary will be ready when they return

## Implementation Workstreams

### 1. State Model & Controller Changes

**File**: `lib/features/ai/state/direct_task_summary_refresh_controller.dart`

- Replace `Map<String, Timer> _debounceTimers` with a new data structure that tracks:
  - Task ID
  - Scheduled time (`DateTime`)
  - Timer reference
- Change default delay from `500ms` to `5 minutes`
- Expose scheduled refresh state via a separate provider for UI consumption
- Add methods:
  - `cancelScheduledRefresh(taskId)` - cancel pending refresh
  - `triggerImmediately(taskId)` - bypass countdown and trigger now

**New Provider**: `scheduledTaskSummaryRefreshProvider`

- Family provider keyed by task ID
- Returns `DateTime?` of scheduled refresh time (null = not scheduled)
- Updated when refresh is scheduled/cancelled/triggered

### 2. Countdown State Provider

**New file**: `lib/features/ai/state/scheduled_refresh_controller.dart` => sounds good

```dart
@riverpod
class ScheduledRefreshController extends _$ScheduledRefreshController {
  @override
  DateTime? build({required String taskId}) {
    // Returns the scheduled time for this task, or null if not scheduled
    // Listen to DirectTaskSummaryRefreshController for updates
  }
}
```

Alternative: Extend `InferenceStatus` enum to include `scheduled` state and add scheduled time to
inference status data. This keeps all states in one place.

### 3. UI Changes

**File**: `lib/features/ai/ui/latest_ai_response_summary.dart`

- Watch the new scheduled refresh provider
- Implement countdown display using `StreamBuilder` or periodic rebuild
- Add action buttons for cancel/trigger-now
- Use `TweenAnimationBuilder` or `Timer.periodic` for smooth countdown updates

**Countdown Widget** (new or inline):

- Displays remaining time in "M:SS" format
- Updates every second while scheduled
- Transitions smoothly to "running" state

**Action Buttons**:

- Cancel: `IconButton` with `Icons.close` - calls `cancelScheduledRefresh`
- Trigger now: `IconButton` with `Icons.play_arrow` - calls `triggerImmediately`
- Both buttons should be styled to match existing UI (outline color, size)

### 4. Localization

**New keys** in `lib/l10n/app_*.arb`:

- `aiTaskSummaryScheduled`: "Summary in {time}" (with placeholder for countdown)
- `aiTaskSummaryCancelScheduled`: "Cancel scheduled summary"
- `aiTaskSummaryTriggerNow`: "Generate summary now"

### 5. Testing

**Unit tests** (`test/features/ai/state/`):

- Scheduled refresh is created with correct delay
- Multiple checklist changes reset the timer
- `cancelScheduledRefresh` cancels timer and clears state
- `triggerImmediately` cancels timer and triggers inference
- Timer fires after delay and triggers inference
- Running inference queues subsequent scheduled refresh

**Widget tests** (`test/features/ai/ui/`):

- Countdown displays correctly and updates
- Cancel button cancels scheduled refresh
- Trigger button triggers immediate refresh
- UI transitions correctly between idle/scheduled/running

**Use fake time** per `test/README.md` guidelines for deterministic timer testing.

## Risks & Mitigations

| Risk                                                         | Mitigation                                                                          |
|--------------------------------------------------------------|-------------------------------------------------------------------------------------|
| Countdown UI causes frequent rebuilds                        | Use `ValueListenableBuilder` or `StreamBuilder` scoped to just the countdown widget |
| User forgets they cancelled and wonders why summary is stale | Show subtle "refresh" indicator or last-updated timestamp                           |
| 5-minute delay too long for some workflows                   | Consider exposing as a setting in the future                                        |

## Open Questions

1. **Exact delay duration**: 5 minutes proposed - is this the right balance? => yes
2. **Reset behavior**: Should each checklist change reset the timer, or should changes accumulate
   without resetting? (Proposed: reset to give consistent behavior) => without resetting
3. **Visual design**: Icon choices for cancel/trigger buttons - use existing icon style or introduce
   new visual language? => existing unless you have a much better idea
4. **Settings exposure**: Should the delay be configurable in settings from the start, or add later
   if needed? => add later if needed

## Rollout

1. Implement state changes and new provider
2. Update UI to display countdown and actions
3. Add localization strings
4. Write tests with fake time
5. Run analyzer/formatter/tests before PR
6. Monitor API usage reduction after deployment
