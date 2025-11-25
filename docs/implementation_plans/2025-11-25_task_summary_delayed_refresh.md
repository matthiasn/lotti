# Delayed Task Summary Refresh with Countdown UX

**Status**: ✅ Implemented (PR #2471)

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

## Implementation Summary

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

### Design Decisions

- **Delay duration**: 5 minutes
- **Reset behavior**: No reset - countdown keeps ticking once started. The countdown is a promise that
  something will happen. Additional checklist changes do not extend/reset the timer.
- **Visual design**: Use existing icon style for cancel/trigger buttons
- **Settings exposure**: Add configurability later if needed

## Files Changed

### Core Controller

**`lib/features/ai/state/direct_task_summary_refresh_controller.dart`**

- Changed delay from 500ms debounce to **5-minute scheduled refresh**
- Returns `ScheduledRefreshState` instead of `void` to expose scheduled times
- Added `ScheduledRefreshData` class to track scheduled time and timer per task
- Added `ScheduledRefreshState` class exposing `Map<String, DateTime>` of scheduled times
- New methods:
  - `cancelScheduledRefresh(taskId)` - cancel pending refresh
  - `triggerImmediately(taskId)` - bypass countdown and trigger now
  - `getScheduledTime(taskId)` - get scheduled time (marked `@visibleForTesting`)
  - `hasScheduledRefresh(taskId)` - check if scheduled (marked `@visibleForTesting`)
- New provider: `scheduledTaskSummaryRefreshProvider` - family provider returning `DateTime?`

### UI Component

**`lib/features/ai/ui/latest_ai_response_summary.dart`**

- Added `_HeaderText` widget with `StreamBuilder` for efficient countdown updates
  - Uses `StreamController<void>.broadcast()` to emit ticks every second
  - Only rebuilds the header text, not the entire parent widget
  - Timer managed in `initState`/`didUpdateWidget`/`dispose` (no side effects in build)
- Cancel button (✕ icon) - calls `cancelScheduledRefresh`
- Trigger now button (▶ icon) - calls `triggerImmediately`
- Both buttons hidden when inference is running

### Localization

**`lib/l10n/app_en.arb`** (and other locale files)

- `aiTaskSummaryScheduled`: "Summary in {time}"
- `aiTaskSummaryCancelScheduled`: "Cancel scheduled summary"
- `aiTaskSummaryTriggerNow`: "Generate summary now"

### Tests

**`test/features/ai/state/direct_task_summary_refresh_controller_test.dart`** (15 tests)

- 5-minute delay works correctly
- Multiple changes do NOT reset timer (batched into existing countdown)
- `cancelScheduledRefresh` cancels timer and clears state
- `triggerImmediately` cancels timer and triggers inference
- Timer fires after delay and triggers inference
- Uses `fake_async` for deterministic timer testing

**`test/features/ai/ui/latest_ai_response_summary_test.dart`** (7 new tests)

- Cancel and trigger-now buttons shown when scheduled
- Countdown text displays correctly
- Cancel button removes scheduled refresh
- Trigger-now button triggers immediate refresh
- Buttons hidden when inference is running
- Tooltips display correct text

## Code Review Feedback Addressed

From Gemini Code Assist review:

1. **High Priority**: Moved countdown from `setState` every second to `StreamBuilder`
   - Scopes rebuilds to only the `_HeaderText` widget

2. **High Priority**: Removed side effects from `build` method
   - Timer management now in `initState`/`didUpdateWidget`/`dispose`

3. **Medium Priority**: Added `@visibleForTesting` annotations
   - `getScheduledTime` and `hasScheduledRefresh` annotated
   - Documentation clarifies UI should use provider pattern

## Future Enhancements

- [ ] Outdated indicator when summary doesn't reflect current checklist state
- [ ] Configurable delay duration in settings
- [ ] Persist scheduled refresh across app restarts
