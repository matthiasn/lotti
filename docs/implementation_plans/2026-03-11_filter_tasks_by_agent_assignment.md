# Filter Tasks by Agent Assignment

**Date**: 2026-03-11
**Status**: Planning
**Priority**: P1

## Goal

Add a tri-state filter to the Task Filter Modal that lets users filter tasks by agent assignment:
1. **All** (default) — ignore agent assignment, show everything
2. **Has Agent** — only tasks with an `agent_task` link
3. **No Agent** — only tasks without an `agent_task` link

The primary use case is backfilling agent assignments: filter to "No Agent", process tasks one-by-one, and watch them disappear from the list as agents are assigned.

## Architecture

### Cross-Database Challenge

Agent-task links live in `agent.sqlite` (the `agent_links` table, `type = 'agent_task'`, `to_id` = journal task ID). Tasks live in `db.sqlite` (the `journal` table). These are **separate databases**, so a single SQL JOIN is not possible.

**Approach**: Pre-fetch the set of task IDs that have agent links from the agent database, then use in-memory filtering after the main task query returns. This is consistent with how the existing system handles other cross-concern filters (e.g., due-date sorting is also done in memory).

### Zero-Cost Default Constraint

**When `agentAssignmentFilter == all` (the default), the existing query path must be completely unchanged.** No agent DB queries, no post-filtering, no over-fetching, no extra allocations. The agent filter code is only entered when the user explicitly activates it.

### Data Flow (only when filter is active)

```
if (agentAssignmentFilter != all) {
  AgentRepository.getTaskIdsWithAgentLink()
          ↓
    Set<String> agentLinkedTaskIds
          ↓
  JournalPageController._runQuery()
          ↓
    Post-filter: include/exclude based on agentAssignmentFilter
}
```

## Implementation Steps

### Step 1: Add `AgentAssignmentFilter` enum and state fields

**File**: `lib/features/journal/state/journal_page_state.dart`

- Add a new enum:
  ```dart
  enum AgentAssignmentFilter {
    all,        // No filtering
    hasAgent,   // Only tasks with an agent_task link
    noAgent,    // Only tasks without an agent_task link
  }
  ```
- Add `agentAssignmentFilter` field to `JournalPageState` (default: `all`)
- Add `agentAssignmentFilter` field to `TasksFilter` for persistence (default: `all`)

### Step 2: Add query method to `AgentRepository`

**File**: `lib/features/agents/database/agent_repository.dart`

- Add method:
  ```dart
  Future<Set<String>> getTaskIdsWithAgentLink() async {
    // Query: SELECT DISTINCT to_id FROM agent_links
    //        WHERE type = 'agent_task' AND deleted_at IS NULL
    return ...;
  }
  ```

**File**: `lib/features/agents/database/agent_database.drift`

- Add named query:
  ```sql
  getAgentTaskLinkToIds: SELECT DISTINCT to_id FROM agent_links
    WHERE type = 'agent_task' AND deleted_at IS NULL;
  ```

### Step 3: Update `JournalPageController`

**File**: `lib/features/journal/state/journal_page_controller.dart`

- Add `AgentAssignmentFilter _agentAssignmentFilter = AgentAssignmentFilter.all;` field
- Add `setAgentAssignmentFilter(AgentAssignmentFilter filter)` method (calls `persistTasksFilter()`)
- Update `_emitState()` to include `agentAssignmentFilter`
- Update `_runQuery()` — **guarded by early return**:
  ```dart
  // At the END of the task branch, AFTER the existing query returns `res`:
  if (_agentAssignmentFilter == AgentAssignmentFilter.all) {
    // Return immediately — no agent DB access, no filtering, no overhead.
    return _sortOption == TaskSortOption.byDueDate
        ? _sortByDueDate(res)
        : res;
  }
  // Only reach here when filter is active:
  final agentLinkedIds = await _getAgentLinkedTaskIds();
  return res.where((e) {
    final hasLink = agentLinkedIds.contains(e.meta.id);
    return _agentAssignmentFilter == AgentAssignmentFilter.hasAgent
        ? hasLink
        : !hasLink;
  }).toList();
  ```
  - The `_getAgentLinkedTaskIds()` helper calls `AgentRepository.getTaskIdsWithAgentLink()` — **only invoked when filter != all**
  - Over-fetch with a multiplier to compensate for post-filter pagination loss (only when filter active)
  - The `AgentRepository` is accessed via `getIt` only on first use, not during `build()`
- Update `_loadPersistedFilters()` and `_persistTasksFilterWithoutRefresh()` to include the new field

### Step 4: Create `TaskAgentFilter` widget

**File**: `lib/features/tasks/ui/filtering/task_agent_filter.dart`

- Three-chip `Wrap` layout following `TaskPriorityFilter` pattern:
  - "All" chip (selected when `agentAssignmentFilter == all`)
  - "Has Agent" chip (selected when `hasAgent`)
  - "No Agent" chip (selected when `noAgent`)
- Uses `journalPageScopeProvider` and `journalPageControllerProvider` like siblings
- Calls `controller.setAgentAssignmentFilter(...)` on tap

### Step 5: Add to `TaskFilterContent`

**File**: `lib/features/tasks/ui/filtering/task_filter_content.dart`

- Add `TaskAgentFilter()` between `TaskLabelFilter()` and the divider

### Step 6: Add localization strings

**Files**: All `lib/l10n/app_*.arb` files

- `tasksAgentFilterTitle`: "Agent" / "Agent" / "Agent" / "Agente" / "Agent" / "Agent"
- `tasksAgentFilterAll`: "All" / "Alle" / "Vše" / "Todos" / "Tous" / "Toate"
- `tasksAgentFilterHasAgent`: "Has Agent" / "Hat Agent" / "Má agenta" / "Con agente" / "A un agent" / "Cu agent"
- `tasksAgentFilterNoAgent`: "No Agent" / "Kein Agent" / "Bez agenta" / "Sin agente" / "Sans agent" / "Fără agent"

### Step 7: Run code generation

- `make build_runner` to regenerate freezed/json_serializable files for `JournalPageState` and `TasksFilter`
- `make l10n` to generate localization files

### Step 8: Tests

**File**: `test/features/tasks/ui/filtering/task_agent_filter_test.dart`

- Widget tests following `task_priority_filter_test.dart` pattern:
  - Renders three chips ("All", "Has Agent", "No Agent")
  - Tapping each chip calls `setAgentAssignmentFilter` with correct value
  - Correct chip is visually selected based on state

**File**: `test/features/tasks/ui/filtering/task_filter_content_test.dart`

- Update to verify `TaskAgentFilter` is present in the modal

**File**: `test/features/journal/state/journal_page_controller_test.dart` (or new focused test)

- Unit test that `_runQuery` correctly filters tasks based on agent assignment
- Test persistence round-trip of `agentAssignmentFilter`

**File**: `test/features/agents/database/agent_repository_test.dart`

- Test `getTaskIdsWithAgentLink()` returns correct IDs

## Files Modified (Summary)

| File | Change |
|------|--------|
| `lib/features/journal/state/journal_page_state.dart` | Add enum + fields |
| `lib/features/agents/database/agent_database.drift` | Add named query |
| `lib/features/agents/database/agent_repository.dart` | Add `getTaskIdsWithAgentLink()` |
| `lib/features/journal/state/journal_page_controller.dart` | Filter logic + persistence |
| `lib/features/tasks/ui/filtering/task_agent_filter.dart` | **New** widget |
| `lib/features/tasks/ui/filtering/task_filter_content.dart` | Add widget to layout |
| `lib/l10n/app_*.arb` (6 files) | Add 4 strings each |
| Tests (4+ files) | Widget + unit tests |

## Performance Guarantees

- **Default state (`all`)**: Zero overhead. The `_runQuery()` code path is identical to today — no agent DB access, no `Set` allocation, no `.where()` filtering. The guard `if (_agentAssignmentFilter == AgentAssignmentFilter.all)` returns before any agent-related code runs.
- **`AgentRepository` not accessed during `build()`**: The repository is only looked up via `getIt` inside `_getAgentLinkedTaskIds()`, which is only called from the active-filter branch.
- **State model changes**: The new `agentAssignmentFilter` field defaults to `all` in both `JournalPageState` and `TasksFilter`. Freezed `copyWith` and JSON serialization add negligible overhead (one enum field).

## Risks & Mitigations

- **Performance when filter IS active**: Fetching all agent-linked task IDs hits the agent DB on each paginated fetch. Mitigation: the query uses `idx_agent_links_type` index, the result set is typically small (hundreds of IDs), and this only runs when the user explicitly activates the filter.
- **Pagination accuracy when filter IS active**: Post-filtering after DB fetch means pages may have fewer items than `pageSize`. Mitigation: over-fetch with a multiplier (e.g., 3x), consistent with existing patterns in the codebase (`AgentRepository._overFetchMultiplier`).
- **Separate databases**: No transactional consistency between the two DBs. Mitigation: this is already the case for all agent-journal interactions; eventual consistency is acceptable for a UI filter.
