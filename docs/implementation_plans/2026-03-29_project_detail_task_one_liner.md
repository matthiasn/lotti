# Project Detail Task One-Liner Implementation Plan

**Date:** 2026-03-29  
**Status:** Proposed  
**Scope:** Planning only. No application code changes in this phase.

## Summary

Add a dedicated task-level `oneLiner` report field and surface it in the
project detail task card as the subtitle line between the bold task title and
the bottom metadata row.

The implementation should:

- extend the task-agent `update_report` contract so every new task report
  carries a concise `oneLiner`
- persist that field on `AgentReportEntity`
- reuse the existing bulk task-report fetch path so project detail pages do
  not fan out one query per task
- update the shared project-detail task row UI on both mobile and desktop
  to render the optional subtitle with the intended design-system styling
- add targeted provider, workflow, contract, and widget coverage

This is a follow-up to the recent projects-page/design-system alignment work,
so the implementation should preserve the new shared `ProjectRecord` ->
`ProjectTasksPanel` rendering path instead of introducing a parallel UI path.

## Goals

- Introduce `oneLiner` as the canonical short task tagline for task-agent
  reports.
- Keep `tldr` for the existing collapsed report/report-summary use cases.
- Use `oneLiner` in the project detail task list without reusing `tldr` there.
- Avoid N+1 lookups when a project has many linked tasks.
- Keep the detail task row aligned with the current Figma direction:
  title, then grey subtitle, then compact metadata row.
- Preserve responsive wrapping on mobile and with larger text scaling.

## Non-Goals

- No redesign of the top-level grouped projects list unless Figma inspection
  shows a directly required shared token/style adjustment.
- No change to project-agent report contracts.
- No migration/backfill job for old reports in this phase.
- No fallback to legacy AI task summaries for the new subtitle line.
- No schema-table migration beyond the normal serialized `AgentReportEntity`
  model update.

## Current State

### Task-agent report contract

Task-agent reports currently publish only:

- `tldr`
- `content` (with legacy `markdown` accepted as fallback)

Relevant code:

- [lib/features/agents/model/seeded_directives.dart](/Users/mn/github/lotti3/lib/features/agents/model/seeded_directives.dart)
- [lib/features/agents/tools/agent_tool_registry.dart](/Users/mn/github/lotti3/lib/features/agents/tools/agent_tool_registry.dart)
- [lib/features/agents/workflow/task_agent_strategy.dart](/Users/mn/github/lotti3/lib/features/agents/workflow/task_agent_strategy.dart)
- [lib/features/agents/workflow/task_agent_workflow.dart](/Users/mn/github/lotti3/lib/features/agents/workflow/task_agent_workflow.dart)
- [lib/features/agents/model/agent_domain_entity.dart](/Users/mn/github/lotti3/lib/features/agents/model/agent_domain_entity.dart)

`AgentReportEntity` already stores `tldr`, but there is no dedicated
subtitle/tagline field today.

### Project detail task-card data path

The current shared project detail projection does this:

- `projectDetailControllerProvider` loads the linked tasks once
- `projectDetailRecordProvider` sorts them and maps each task into
  `TaskSummary(task, estimatedDuration)`
- `ProjectTasksPanel` / `TaskSummaryRow` render:
  - task title
  - metadata row (duration + status)

Relevant code:

- [lib/features/projects/state/project_detail_record_provider.dart](/Users/mn/github/lotti3/lib/features/projects/state/project_detail_record_provider.dart)
- [lib/features/projects/ui/model/project_list_detail_models.dart](/Users/mn/github/lotti3/lib/features/projects/ui/model/project_list_detail_models.dart)
- [lib/features/projects/ui/widgets/project_tasks_panel.dart](/Users/mn/github/lotti3/lib/features/projects/ui/widgets/project_tasks_panel.dart)

### Existing bulk-fetch building block

The repo already has the exact anti-N+1 primitive we should reuse:

- `AgentRepository.getLatestTaskReportsForTaskIds(List<String>)`

That method batch-resolves task-agent links and then batch-fetches current
reports by agent ID. `AiInputRepository.buildRelatedProjectTasksJson()` already
uses this path for sibling-task context, so the performance pattern is proven.

Relevant code:

- [lib/features/agents/database/agent_repository.dart](/Users/mn/github/lotti3/lib/features/agents/database/agent_repository.dart)
- [lib/features/ai/repository/ai_input_repository.dart](/Users/mn/github/lotti3/lib/features/ai/repository/ai_input_repository.dart)

### Figma / design context

The target Figma nodes are:

- project detail: `372:32080`
- projects list: `372:31900`
- design system references: `3282:8846`, `3282:8655`

During planning, remote MCP reads for these nodes timed out. The provided
screenshots still establish the key layout requirement:

- subtitle sits between title and metadata
- subtitle is smaller and greyed out
- subtitle wraps across multiple lines

Implementation should retry targeted Figma MCP inspection one node at a time
before finalizing the exact typography/token choice.

## Key Decision

Use the new `oneLiner` field directly for the project-detail subtitle.

Implications:

- `tldr` remains the broader collapsed-report summary.
- `oneLiner` is the concise task-card tagline.
- If an older report lacks `oneLiner`, the subtitle is omitted on that row
  instead of reusing `tldr` and risking overly long/noisy subtitles.

This matches the stated intent to reuse the dedicated `oneLiner` field here
and keep the other summary forms for their existing surfaces.

## Proposed Changes

### 1. Extend the task-agent report contract

Add `oneLiner` to the task-agent `update_report` tool call and seeded
directives.

Planned behavior:

- `oneLiner` is a short, meaningful tagline about current task state
- it should be tighter than `tldr`
- it should read well as a subtitle in a compact list row

Prompt/tooling updates:

- Update the task-agent seeded report directive to explicitly describe
  `oneLiner` and give examples such as:
  - implementation done, release and docs next
  - at risk of missing the deadline
  - blocked on backend review
- Update the task-agent scaffold text in `TaskAgentWorkflow` so the model sees
  the new contract even when older template versions do not override it.
- Update `AgentToolRegistry.update_report` schema to declare `oneLiner`.
- Recommended contract enforcement:
  - keep persisted `AgentReportEntity.oneLiner` nullable for older data
  - require non-empty `oneLiner` for new `update_report` calls
  - return a tool error if the model omits it, so the conversation can repair
    itself before persistence

Expected touched files:

- [lib/features/agents/model/seeded_directives.dart](/Users/mn/github/lotti3/lib/features/agents/model/seeded_directives.dart)
- [lib/features/agents/tools/agent_tool_registry.dart](/Users/mn/github/lotti3/lib/features/agents/tools/agent_tool_registry.dart)
- [lib/features/agents/workflow/task_agent_workflow.dart](/Users/mn/github/lotti3/lib/features/agents/workflow/task_agent_workflow.dart)
- [lib/features/agents/workflow/task_agent_strategy.dart](/Users/mn/github/lotti3/lib/features/agents/workflow/task_agent_strategy.dart)

### 2. Persist `oneLiner` on agent reports

Extend `AgentReportEntity` with a nullable `oneLiner` field and persist it when
task reports are written.

Planned changes:

- add `String? oneLiner` to `AgentDomainEntity.agentReport`
- capture it in `TaskAgentStrategy`
- persist it in `TaskAgentWorkflow`
- ensure JSON round-trip / Drift serialization continues to work
- run code generation after model changes

Expected touched files:

- [lib/features/agents/model/agent_domain_entity.dart](/Users/mn/github/lotti3/lib/features/agents/model/agent_domain_entity.dart)
- [lib/features/agents/database/agent_db_conversions.dart](/Users/mn/github/lotti3/lib/features/agents/database/agent_db_conversions.dart) if migration helpers or tests need adjustment
- generated files via `build_runner`

### 3. Reuse the bulk report fetch in project detail

Extend `TaskSummary` with an optional `oneLiner` and populate it in
`projectDetailRecordProvider` using a single bulk task-report lookup.

Planned provider flow:

1. Read the already-loaded linked tasks from `projectDetailControllerProvider`.
2. Sort tasks exactly as today.
3. Extract all task IDs once.
4. Call `AgentRepository.getLatestTaskReportsForTaskIds(taskIds)` once.
5. Build `TaskSummary` rows with:
   - `task`
   - `estimatedDuration`
   - `oneLiner: report.oneLiner?.trim()`

Performance expectation:

- task list query remains the existing single project-task fetch
- report lookup remains one bulk link+report fetch path
- no per-task report lookup loop in the provider

Expected touched files:

- [lib/features/projects/ui/model/project_list_detail_models.dart](/Users/mn/github/lotti3/lib/features/projects/ui/model/project_list_detail_models.dart)
- [lib/features/projects/state/project_detail_record_provider.dart](/Users/mn/github/lotti3/lib/features/projects/state/project_detail_record_provider.dart)

### 4. Update the shared project task row UI

Render the optional subtitle between the title and metadata row in
`TaskSummaryRow`.

Planned UI behavior:

- title remains first
- optional `oneLiner` text is inserted underneath title
- metadata row stays below subtitle
- if `oneLiner` is absent, no empty gap is rendered
- subtitle wraps up to 3 lines
- subtitle uses a smaller, regular-weight, lower-emphasis text style
- mobile and desktop both pick up the change because they already share
  `ProjectTasksPanel`

Design-system alignment plan:

- retry targeted Figma MCP inspection for the project-detail frame and the two
  referenced DS nodes before final token selection
- prefer an existing design-system text recipe rather than inventing a new
  ad-hoc style
- likely candidates to compare:
  - `tokens.typography.styles.others.caption`
  - the small `DesignSystemListItem` subtitle styling

Relevant DS references in code:

- [lib/features/design_system/components/lists/design_system_list_item.dart](/Users/mn/github/lotti3/lib/features/design_system/components/lists/design_system_list_item.dart)
- [lib/features/projects/ui/widgets/project_tasks_panel.dart](/Users/mn/github/lotti3/lib/features/projects/ui/widgets/project_tasks_panel.dart)

### 5. Update mocks, docs, and release notes

Because this is a visible product change, update the supporting artifacts too.

Planned updates:

- Widgetbook/mock data for project detail examples should include realistic
  `oneLiner` samples.
- Projects README should document that the detail task rows now include the
  agent-authored one-liner subtitle and that the provider batch-fetches task
  reports.
- Add a changelog line under version `0.9.936`.
- Add the matching Flatpak metainfo release paragraph.

Expected touched files:

- [lib/features/projects/widgetbook/project_list_detail_mock_data.dart](/Users/mn/github/lotti3/lib/features/projects/widgetbook/project_list_detail_mock_data.dart)
- [lib/features/projects/README.md](/Users/mn/github/lotti3/lib/features/projects/README.md)
- [CHANGELOG.md](/Users/mn/github/lotti3/CHANGELOG.md)
- [flatpak/com.matthiasn.lotti.metainfo.xml](/Users/mn/github/lotti3/flatpak/com.matthiasn.lotti.metainfo.xml)

## Tests

Only targeted tests for touched files should run.

### Agent/report contract coverage

- update report schema test covers `oneLiner`
- task-agent strategy test covers:
  - captures `oneLiner`
  - rejects missing/blank `oneLiner` if enforcement is enabled
- task-agent workflow test covers:
  - persisted `AgentReportEntity.oneLiner`
- model/conversion tests cover JSON round-trip for the new field

Likely files:

- [test/features/agents/tools/agent_tool_registry_test.dart](/Users/mn/github/lotti3/test/features/agents/tools/agent_tool_registry_test.dart)
- [test/features/agents/workflow/task_agent_strategy_test.dart](/Users/mn/github/lotti3/test/features/agents/workflow/task_agent_strategy_test.dart)
- [test/features/agents/workflow/task_agent_workflow_test.dart](/Users/mn/github/lotti3/test/features/agents/workflow/task_agent_workflow_test.dart)
- [test/features/agents/model/agent_domain_entity_test.dart](/Users/mn/github/lotti3/test/features/agents/model/agent_domain_entity_test.dart)
- [test/features/agents/database/agent_db_conversions_test.dart](/Users/mn/github/lotti3/test/features/agents/database/agent_db_conversions_test.dart)

### Project detail/provider coverage

- `projectDetailRecordProvider` test should verify:
  - single bulk-fetch dependency is used for all task IDs
  - `TaskSummary.oneLiner` is mapped from the correct report
  - missing `oneLiner` yields `null`
  - sorting and total-duration behavior stay unchanged

Likely file:

- [test/features/projects/state/project_detail_record_provider_test.dart](/Users/mn/github/lotti3/test/features/projects/state/project_detail_record_provider_test.dart)

### Widget coverage

- `TaskSummaryRow` test should verify:
  - subtitle renders between title and metadata
  - subtitle style is smaller/lower-emphasis than title
  - subtitle wraps on narrow widths
  - subtitle is absent cleanly when no `oneLiner` exists
- `ProjectTasksPanel` test should verify multiple rows with/without subtitle

Likely file:

- [test/features/projects/ui/widgets/project_tasks_panel_test.dart](/Users/mn/github/lotti3/test/features/projects/ui/widgets/project_tasks_panel_test.dart)

## Tooling / Verification Plan

When implementation starts:

1. Retry Figma MCP inspection one node at a time:
   - detail frame `372:32080`
   - list frame `372:31900`
   - DS nodes `3282:8846`, `3282:8655`
2. Implement model + workflow changes first.
3. Run `build_runner` with a generous timeout after model changes.
4. Format touched files with `fvm dart format ...`.
5. Run analyzer on touched files.
6. Run only touched tests.
7. Run a broader analyzer pass for the project once the feature stabilizes.
8. Manually verify mobile and desktop task rows, including larger text scale.

## Risks And Mitigations

- Risk: older reports have no `oneLiner`, so some task rows may temporarily
  show no subtitle.
  Mitigation: accept null on persisted entities and omit the subtitle cleanly;
  future wakes will populate it.

- Risk: the model may ignore the new tool argument initially.
  Mitigation: update both the tool schema and seeded/scaffold directives, and
  reject incomplete `update_report` calls if needed.

- Risk: Figma MCP reads may continue timing out.
  Mitigation: inspect one node at a time and rely on the provided screenshots
  plus existing design-system tokens if the remote file remains slow.

- Risk: adding the field to the shared report entity ripples into many tests.
  Mitigation: keep the new field nullable in constructors/test factories so
  updates remain mechanical and focused.

## Acceptance Criteria

- Task-agent `update_report` publishes `oneLiner` alongside `tldr` and full
  report content.
- `AgentReportEntity` persists `oneLiner`.
- Project detail task rows read `oneLiner` through a bulk report fetch path,
  not one query per task.
- The project detail task card shows the subtitle between title and metadata
  on both mobile and desktop.
- The subtitle uses the intended lower-emphasis design-system styling and
  wraps to at most 3 lines.
- Analyzer is clean for touched code, targeted tests pass, and release/docs
  artifacts are updated consistently.
