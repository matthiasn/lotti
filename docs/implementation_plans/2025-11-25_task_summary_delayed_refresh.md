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

### Decisions

- **Delay duration**: 5 minutes
- **Reset behavior**: No reset - countdown keeps ticking once started. The countdown is a promise that
  something will happen. Additional checklist changes do not extend/reset the timer.
- **Visual design**: Use existing icon style for cancel/trigger buttons
- **Settings exposure**: Add configurability later if needed

### Edge Cases

1. **Multiple checklist changes while scheduled**: Countdown keeps ticking (no reset). The first
   change sets the 5-minute countdown; subsequent changes are batched into that same refresh.
2. **App backgrounded/closed**: Scheduled refresh is lost. Show an "outdated" indicator on the
   summary so users know they should manually refresh when returning to the task.
3. **Inference already running when checklist changes**: Queue the scheduled refresh to trigger
   after current inference completes (existing behavior).
4. **User navigates away from task**: Keep timer running - summary will be ready when they return.

## Implementation Workstreams

### 1. State Model & Controller Changes

**File**: `lib/features/ai/state/direct_task_summary_refresh_controller.dart`

- Replace `Map<String, Timer> _debounceTimers` with a new data structure that tracks:
  - Task ID
  - Scheduled time (`DateTime`)
  - Timer reference
- Change default delay from `500ms` to `5 minutes`
- Do NOT reset timer on subsequent checklist changes (batch into existing countdown)
- Expose scheduled refresh state via a separate provider for UI consumption
- Add methods:
  - `cancelScheduledRefresh(taskId)` - cancel pending refresh
  - `triggerImmediately(taskId)` - bypass countdown and trigger now

**New Provider**: `scheduledTaskSummaryRefreshProvider`

- Family provider keyed by task ID
- Returns `DateTime?` of scheduled refresh time (null = not scheduled)
- Updated when refresh is scheduled/cancelled/triggered

### 2. Countdown State Provider

**New file**: `lib/features/ai/state/scheduled_refresh_controller.dart`

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

**Outdated Indicator**:

- When in idle state, check if summary is outdated (checklist changed since last summary)
- Show subtle visual indicator (e.g., warning icon, "outdated" badge, or different text color)
- This addresses the edge case where app was closed before scheduled refresh completed

### 4. Localization

**New keys** in `lib/l10n/app_*.arb`:

- `aiTaskSummaryScheduled`: "Summary in {time}" (with placeholder for countdown)
- `aiTaskSummaryCancelScheduled`: "Cancel scheduled summary"
- `aiTaskSummaryTriggerNow`: "Generate summary now"
- `aiTaskSummaryOutdated`: "Summary may be outdated"

### 5. Testing

**Unit tests** (`test/features/ai/state/`):

- Scheduled refresh is created with correct 5-minute delay
- Multiple checklist changes do NOT reset the timer (batched into existing countdown)
- `cancelScheduledRefresh` cancels timer and clears state
- `triggerImmediately` cancels timer and triggers inference
- Timer fires after delay and triggers inference
- Running inference queues subsequent scheduled refresh

**Widget tests** (`test/features/ai/ui/`):

- Countdown displays correctly and updates
- Cancel button cancels scheduled refresh
- Trigger button triggers immediate refresh
- UI transitions correctly between idle/scheduled/running
- Outdated indicator shows when appropriate

**Use fake time** per `test/README.md` guidelines for deterministic timer testing.

## Risks & Mitigations

| Risk                                                         | Mitigation                                                                          |
|--------------------------------------------------------------|-------------------------------------------------------------------------------------|
| Countdown UI causes frequent rebuilds                        | Use `ValueListenableBuilder` or `StreamBuilder` scoped to just the countdown widget |
| User forgets they cancelled and wonders why summary is stale | Show "outdated" indicator when summary doesn't reflect current checklist state      |
| 5-minute delay too long for some workflows                   | Consider exposing as a setting in the future                                        |
| App closed before refresh completes                          | Show "outdated" indicator so user knows to manually refresh                         |

## Rollout

1. Implement state changes and new provider
2. Update UI to display countdown and actions
3. Add outdated indicator logic
4. Add localization strings
5. Write tests with fake time
6. Run analyzer/formatter/tests before PR
7. Monitor API usage reduction after deployment
