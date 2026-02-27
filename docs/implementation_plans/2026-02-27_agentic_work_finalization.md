# Implementation Plan: Agentic Work Finalization

## Context

Follow-up to the daily sync to prepare agent features for demo and TestFlight release on iOS/macOS. Four areas need work: (1) model selection defaults, (2) report formatting alignment with task summaries, (3) settings UI restructuring for agents, and (4) agent evolution monitoring visibility.

**Decisions**:
- Routing: Clean replace — remove old `/settings/templates` routes, use `/settings/agents` exclusively.
- Report display: Agent report appears as a **separate section** on the task detail page (AI Task Summary stays independent).

---

## Architecture Overview

```mermaid
graph TB
    subgraph "Settings Navigation (Step 3)"
        SP[SettingsPage] -->|"/settings/agents"| ASP[AgentSettingsPage]
        ASP --> TAB1[Tab: Templates]
        ASP --> TAB2[Tab: Instances]
        TAB1 --> ATDP[AgentTemplateDetailPage]
        TAB2 --> AIL[AgentInstancesList]
        AIL -->|tap instance| ADP[AgentDetailPage]
    end

    subgraph "Task Detail View (Step 2)"
        TDP[TaskDetailsPage] --> TF[TaskForm]
        TF --> LARS[LatestAiResponseSummary]
        TF --> ARS[AgentReportSection NEW]
        TF --> LTW[LinkedTasksWidget]
        ARS -->|expandable TLDR| EARS[ExpandableAiResponseSummary]
    end

    subgraph "Model Resolution (Step 1)"
        AT[AgentTemplate] -->|modelId| IPR[resolveInferenceProvider]
        IPR --> AiConfigModel
        AiConfigModel --> AiConfigInferenceProvider
        AiConfigInferenceProvider -->|apiKey + baseUrl| TAW[TaskAgentWorkflow]
    end
```

---

## Step 1: Fix Model Selection — Default to Gemini Flash & Fix Selector

**Problem**: Multiple issues with model selection:
1. `AgentConfig.modelId` (on agent identity) defaults to `'models/gemini-3.1-pro-preview'` but is a **dead field** — the workflow uses `template.modelId`, not `config.modelId`.
2. `TaskAgentService.createTaskAgent()` (line 93) passes `const AgentConfig()` ignoring the template's model entirely.
3. Seeded defaults (Laura, Tom) hardcode `'models/gemini-3.1-pro-preview'`.
4. The model selector value in the UI is stored on the template correctly, but the duplicate `AgentConfig.modelId` creates confusion about which field is authoritative.

```mermaid
flowchart TD
    subgraph "Current (Broken)"
        UI1["AgentModelSelector<br/>user picks Flash"] --> TPL1["Template.modelId<br/>= flash ✓"]
        TPL1 --> WF1["Workflow reads<br/>template.modelId ✓"]

        CAS1["createTaskAgent()"] --> CFG1["const AgentConfig()<br/>modelId = pro ❌"]
        CFG1 --> ID1["Identity.config.modelId<br/>= pro (dead field, unused)"]

        SEED1["seedDefaults()"] --> TPL_SEED["Template.modelId<br/>= pro (hardcoded) ❌"]
    end

    subgraph "Fixed"
        UI2["AgentModelSelector<br/>default = flash"] --> TPL2["Template.modelId<br/>= flash ✓"]
        TPL2 --> WF2["Workflow reads<br/>template.modelId ✓"]

        CAS2["createTaskAgent()"] --> CFG2["AgentConfig(modelId:<br/>template.modelId) ✓"]

        SEED2["seedDefaults()"] --> TPL_SEED2["Template.modelId<br/>= flash ✓"]
    end
```

**Changes**:

1. **`lib/features/agents/model/agent_config.dart:14`** — Change default `modelId` from `'models/gemini-3.1-pro-preview'` to `'models/gemini-3-flash-preview'`.

2. **`lib/features/agents/service/task_agent_service.dart:93`** — Pass the template's `modelId` into the `AgentConfig` instead of using `const AgentConfig()`:
   ```dart
   config: AgentConfig(modelId: templateEntity.modelId),
   ```
   This requires reading the `templateEntity` before `createAgent`, which is already done on line 69-75.

3. **`lib/features/agents/service/agent_template_service.dart:518,528`** — Change seeded defaults (Laura, Tom) from `'models/gemini-3.1-pro-preview'` to `'models/gemini-3-flash-preview'`.

4. **`lib/features/agents/ui/agent_template_detail_page.dart`** — In create mode, pre-populate `_selectedModelId` with `'models/gemini-3-flash-preview'` so the selector shows Flash by default.

5. **Verified**: `gemini-3-flash-preview` already has `isReasoningModel: true` and `supportsFunctionCalling: true` in `known_models.dart:101-106`, so it appears in the `AgentModelSelector` filter.

6. Run `make build_runner` after changing the freezed class default.

---

## Step 2: Align Agent Report Format with Task Summary

**Problem**: The agent's `update_report` tool produces freeform markdown. Task summaries use a well-defined structure. Agent reports should match so they're a "swap-in" replacement.

```mermaid
flowchart TD
    subgraph "Report Structure (Aligned)"
        TLDR["**TLDR:** 3-4 lines, bold, emojis<br/>(always visible, expandable)"]
        GOAL["**Goal:** 1-3 sentences"]
        ACHIEVED["**Achieved results:** ✅ items"]
        REMAINING["**Remaining steps:** numbered list"]
        LEARNINGS["**Learnings:** 💡 items"]
        ANNOYANCES["**Annoyances:** 🤯 items"]
        LINKS["**Links:** markdown URLs"]

        TLDR --> GOAL --> ACHIEVED --> REMAINING --> LEARNINGS --> ANNOYANCES --> LINKS
    end

    subgraph "Generation Flow"
        TD1["Template Directives<br/>(personality/voice)"] --> SP["System Prompt"]
        FMT["Hardcoded Format Spec"] --> SP
        SP --> LLM["Gemini Flash"]
        LLM -->|"update_report tool"| RPT["AgentReportEntity"]
    end
```

**Changes**:

1. **`lib/features/agents/tools/agent_tool_registry.dart:168-184`** — Expand the `update_report` tool description with the exact format spec from the task summary prompt: TLDR (bold, 3-4 lines with emojis), Goal, Achieved results (checkmark), Remaining steps (numbered), Learnings (bulb), Annoyances (exploding head), Links. Reference the agent's personality from template directives.

2. **`lib/features/agents/workflow/task_agent_workflow.dart`** — In system prompt assembly, add explicit formatting instructions for the report, incorporating the template's directives as the agent's voice/personality.

3. **`lib/features/agents/ui/agent_report_section.dart`** — Replace basic `GptMarkdown` card with `ExpandableAiResponseSummary`-style layout (expandable TLDR + details).

4. **`lib/features/agents/ui/agent_activity_log.dart`** — Update Reports tab to use the new expandable format.

5. **`lib/features/tasks/ui/task_form.dart`** — Add a new `AgentReportSection` widget **below** `LatestAiResponseSummary` (separate section). Only shown when the task has an associated agent with a report. Use `taskAgentForTaskProvider` to check for agent, then `agentReportProvider` for the report.

```mermaid
graph TD
    subgraph "Task Detail Layout"
        direction TB
        H["TaskHeaderMetaCard"]
        L["TaskLabelsWrapper"]
        E["Editor"]
        AI["LatestAiResponseSummary<br/>(existing, unchanged)"]
        AR["AgentReportSection ← NEW<br/>(expandable TLDR + details)<br/>shown only if agent exists"]
        LT["LinkedTasksWidget"]
        CL["ChecklistsWidget"]

        H --> L --> E --> AI --> AR --> LT --> CL
    end
```

---

## Step 3: Restructure Settings — "Settings Agents"

```mermaid
graph LR
    subgraph "Before"
        S1[SettingsPage] -->|"Agent Templates"| TL1["/settings/templates<br/>AgentTemplateListPage"]
        TL1 --> TD1["/settings/templates/:id<br/>AgentTemplateDetailPage"]
    end

    subgraph "After"
        S2[SettingsPage] -->|"Agents"| AS["/settings/agents<br/>AgentSettingsPage"]
        AS --> T2["Tab: Templates<br/>(inline list)"]
        AS --> I2["Tab: Instances<br/>AgentInstancesList"]
        T2 --> TD2["AgentTemplateDetailPage"]
        I2 -->|"SegmentedButton filter"| F2["All | Active | Dormant | Destroyed"]
        I2 --> AD2["AgentDetailPage"]
    end
```

### 3a. Localization

Add new l10n keys to all 5 arb files (`app_en.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_ro.arb`):
- `agentSettingsTitle` — "Agents"
- `agentSettingsSubtitle` — "Templates, instances, and monitoring"
- `agentInstancesTitle` — "Instances"
- `agentInstancesFilterAll` — "All"
- `agentInstancesFilterActive` — "Active"
- `agentInstancesFilterDormant` — "Dormant"
- `agentInstancesFilterDestroyed` — "Destroyed"
- `agentInstancesKindAll` — "All"
- `agentInstancesKindTaskAgent` — "Task Agent"
- `agentInstancesKindEvolution` — "Evolution"

### 3b. Settings Card Update

**`lib/features/settings/ui/pages/settings_page.dart:78-84`** — Change:
- Title from `agentTemplatesTitle` to `agentSettingsTitle`
- Subtitle from `agentTemplateSettingsSubtitle` to `agentSettingsSubtitle`
- Route from `/settings/templates` to `/settings/agents`

### 3c. New Agents Landing Page

**`lib/features/agents/ui/agent_settings_page.dart`** (new) — `AgentSettingsPage` with `DefaultTabController` + `TabBar` (Templates, Instances). Templates tab inlines existing `AgentTemplateListPage` content. Instances tab shows `AgentInstancesList`.

### 3d. Agent Instances List

**`lib/features/agents/ui/agent_instances_list.dart`** (new):

```mermaid
stateDiagram-v2
    [*] --> All

    state "Kind Filter" as KF {
        [*] --> AllKinds
        AllKinds --> TaskAgent: tap
        AllKinds --> Evolution: tap
        TaskAgent --> AllKinds: tap
        Evolution --> AllKinds: tap
    }

    state "Lifecycle Filter" as LF {
        [*] --> AllStatus
        AllStatus --> Active: tap
        AllStatus --> Dormant: tap
        AllStatus --> Destroyed: tap
        Active --> AllStatus: tap
        Dormant --> AllStatus: tap
        Destroyed --> AllStatus: tap
    }

    state "Instance Card" as IC {
        [*] --> DisplayName
        DisplayName --> KindBadge
        KindBadge --> LifecycleBadge
        LifecycleBadge --> TaskName
        TaskName --> LastActivity
        LastActivity --> RunningIndicator
    }
```

**Two filter rows**:
1. **Kind filter** — `SegmentedButton<String?>`: All | Task Agent | Evolution
   - Task Agents: `AgentIdentityEntity` with `kind == 'task_agent'` from `AgentService.listAgents()`
   - Evolution agents: `EvolutionSessionEntity` from `AgentTemplateService.getEvolutionSessions()` — these are sessions against templates, not identity entities. Display them with a distinct badge ("Evolution") and show the template name instead of task name.
2. **Lifecycle filter** — `SegmentedButton<AgentLifecycle?>`: All | Active | Dormant | Destroyed (only applies to Task Agents; evolution sessions have their own status)

- List of `ModernBaseCard` items showing: name (from template), kind badge, lifecycle/status badge, associated task/template name, last activity time
- Tap Task Agent → navigates to `AgentDetailPage`
- Tap Evolution session → navigates to `EvolutionChatPage`
- Running indicator from `agentIsRunningProvider` (Task Agents only)

### 3e. New Providers

**`lib/features/agents/state/agent_providers.dart`** — Add:
- `allAgentInstancesProvider` — calls `agentService.listAgents()`
- Optionally a family variant with lifecycle filter

### 3f. Routing Update

**`lib/beamer/locations/settings_location.dart`**:

```mermaid
graph TD
    subgraph "New Route Tree"
        R1["/settings/agents"] --> R2["/settings/agents/templates/create"]
        R1 --> R3["/settings/agents/templates/:templateId"]
        R1 --> R4["/settings/agents/instances/:agentId"]
    end
```

- Remove old `/settings/templates/*` patterns
- Add `/settings/agents`
- Template create/edit routes become `/settings/agents/templates/create` and `/settings/agents/templates/:templateId`
- Agent instance detail: `/settings/agents/instances/:agentId`

---

## Step 4: Agent Evolution Monitoring Visibility

```mermaid
flowchart LR
    TEW["TemplateEvolutionWorkflow"] -->|creates| AIE["AgentIdentityEntity"]
    AIE -->|listed by| AS["AgentService.listAgents()"]
    AS -->|displayed in| AIL["AgentInstancesList"]
    AIL -->|"running? 🔄"| ARP["agentIsRunningProvider"]
    AIL -->|tap| ADP["AgentDetailPage"]
    ADP -->|Reports tab| ARS["AgentReportSection<br/>(expandable TLDR)"]
```

1. Verify evolution agents created by `TemplateEvolutionWorkflow` appear in `AgentService.listAgents()`. They should already be `AgentIdentityEntity` instances.

2. In `AgentInstancesList`, show running indicator when `agentIsRunningProvider(agentId)` emits true.

3. In `AgentDetailPage`, update the Reports tab to use the new expandable report format from Step 2.

---

## Step 5: Tests, Cleanup, Release Prep

1. Write tests:
   - `test/features/agents/ui/agent_settings_page_test.dart` — tab switching
   - `test/features/agents/ui/agent_instances_list_test.dart` — lifecycle filtering
   - `test/features/agents/ui/agent_report_section_test.dart` — expandable TLDR
   - Verify default model ID in existing agent config tests

2. Run `make l10n` + `make sort_arb_files` after arb changes.
3. Run `dart_fix`, `dart_format`, `analyze_files` until zero issues.
4. Update `lib/features/agents/README.md` with new UI structure.
5. Add CHANGELOG entry under current version from `pubspec.yaml`.
6. Update `flatpak/com.matthiasn.lotti.metainfo.xml`.

---

## Verification

1. **Analyzer**: Zero warnings/infos for entire project.
2. **Tests**: All existing + new tests pass.
3. **Manual**: Settings → Agents shows tabs, instance filtering works, agent detail shows expandable report.
4. **Model default**: New template pre-selects Gemini Flash.
5. **Report format**: Task agent wake produces structured report with TLDR.
6. **Task view**: Agent report appears as separate section below AI Task Summary.

---

## Execution Order

```mermaid
gantt
    title Implementation Sequence
    dateFormat X
    axisFormat %s

    section Step 1
    Model default + build_runner          :s1, 0, 1

    section Step 2
    Report prompt format                  :s2a, 1, 2
    Report UI (expandable TLDR)           :s2b, 2, 3
    Task form integration                 :s2c, 3, 4

    section Step 3
    Localization (arb files)              :s3a, 4, 5
    AgentSettingsPage + tabs              :s3b, 5, 6
    AgentInstancesList + filter           :s3c, 6, 7
    Routing update                        :s3d, 7, 8

    section Step 4
    Evolution visibility                  :s4, 8, 9

    section Step 5
    Tests + cleanup                       :s5, 1, 9
```

1. Step 1 (model default) — small, self-contained, run build_runner
2. Step 2 (report formatting) — prompt changes + UI updates
3. Step 3 (settings restructure) — new pages, routing, l10n
4. Step 4 (evolution visibility) — depends on Step 3
5. Step 5 (tests, cleanup) — done incrementally after each step

---

## Follow-up: UX/Reliability Improvements (2026-02-27)

### Context
After initial implementation, several UX and reliability issues were identified from task detail screenshots and usage feedback.

### Completed Items

#### 1. Streamlined Report Format (Remove Redundancy)
**Status**: Done

**Problem**: Report prompt instructed the agent to output Title (H1), Status bar, Goal section — all redundant with the task header UI.

**Changes** (`lib/features/agents/workflow/task_agent_workflow.dart`):
- Removed "Title line" and "Status bar" from Required Sections
- Removed them from the example report
- Made TLDR the first section
- Added explicit instruction not to include title/status/goal

#### 2. Display Model in Conversation Thread (per-conversation, not live)
**Status**: Done

**Problem**: No UI showed which model (Flash vs Pro) generated a conversation.

**Changes**:
- Added `modelId` field to `AgentTemplateVersionEntity` (`lib/features/agents/model/agent_domain_entity.dart`) — captures the template's configured model when the version is created
- Updated both version creation sites in `AgentTemplateService` to pass `modelId`
- Added `modelIdForThreadProvider` (`lib/features/agents/state/agent_providers.dart`) — resolves model from `wake_run_log.template_version_id` → `AgentTemplateVersionEntity.modelId`, falls back to live template for pre-existing data
- Converted `_ThreadTile` to `ConsumerWidget`, watches `modelIdForThreadProvider` to show the actual model used for each conversation (not the current template config)
- Displays model ID (stripped of `models/` prefix) in thread subtitle

#### 3. Fix Thread Timestamp to Show Start Time + Duration
**Status**: Done

**Problem**: Thread tile showed the timestamp of the last message (end time), not when the conversation started. Users also wanted to see conversation duration.

**Changes** (`lib/features/agents/ui/agent_conversation_log.dart`):
- Changed from `messages.last` to `messages.first` for timestamp
- Added duration calculation (last - first message)
- Display format: `"2026-02-27 14:30 (2m 15s)"`
- Added `_formatDuration()` helper

#### 4. Fix Date Layout in Conversation Messages
**Status**: Done

**Problem**: Long tool names in the `_MessageCard` Row pushed the timestamp into vertical wrapping.

**Changes** (`lib/features/agents/ui/agent_activity_log.dart`):
- Split into two-row layout: Row 1 has KindBadge + Timestamp + ExpandIcon
- Row 2 (only when tool name present) shows the tool name Chip with full width

#### 5. Debug Logging for Checklist → Agent Wake
**Status**: Done

**Problem**: Checklist item completion may not reliably trigger agent runs. Need visibility into the notification chain.

**Changes** (`lib/features/agents/wake/wake_orchestrator.dart`):
- Added `developer.log` in `_onBatch` for token matching and suppression
- Added `developer.log` in throttle path showing deadline
- Added `developer.log` in `_scheduleDeferredDrain` for timer scheduling and firing
- Removed `kDebugMode` guard from existing logging (now always logs)

#### 6. Concurrency Guard for Orphaned Running Wakes
**Status**: Done

**Problem**: On hot restart, in-memory locks are lost, leaving wake runs stuck in `running` status forever.

**Changes**:
- Added `WakeRunStatus.abandoned` enum value (`lib/features/agents/model/agent_enums.dart`)
- Added `AgentRepository.abandonOrphanedWakeRuns()` method (`lib/features/agents/database/agent_repository.dart`)
- Call on startup in `agentInitialization` provider (`lib/features/agents/state/agent_providers.dart`)
- Updated test mocks to stub the new method

#### 7. Model ID on Template Version + Version on Model Change
**Status**: Done

**Problem**: The model displayed in the conversation thread came from the live template config, not from the version used at the time of the conversation. Also, changing the model on a template did not create a new immutable version.

**Changes**:
- Added `String? modelId` field to `AgentTemplateVersionEntity` (`lib/features/agents/model/agent_domain_entity.dart`)
- Updated `AgentTemplateService.createVersion()` to record `template.modelId` on new versions
- Updated `AgentTemplateService.updateTemplate()` to create a new version when `modelId` changes (author: `system:model_change`)
- Updated workflow to resolve model from version: `templateCtx.version.modelId ?? templateCtx.template.modelId`
- Updated `modelIdForThreadProvider` to look up model from the wake run's template version

#### 8. Fix Checklist → Agent Wake (No Countdown Visible)
**Status**: Done

**Problem**: Two issues prevented the countdown from appearing:
1. The defer-first path in `_onBatch` set the throttle deadline in-memory only — it did not persist `nextWakeAt` to the database.
2. Even after persisting, the UI never rebuilt because `_setThrottleDeadline` and `_clearPersistedThrottle` write via `repository.upsertEntity()` which bypasses `UpdateNotifications` — the Riverpod `agentStateProvider` never received a refresh signal.

**Changes**:
- Replaced inline throttle deadline setting in `_onBatch` with `_setThrottleDeadline()` call (`wake_orchestrator.dart`)
- Added `onAgentStateChanged` callback to `WakeOrchestrator` — fires after any `nextWakeAt` persistence (set or clear)
- Wired callback in `wakeOrchestratorProvider` to `UpdateNotifications.notify({agentId})` so the UI countdown provider rebuilds (`agent_providers.dart`)
- Added diagnostic log when `_onBatch` receives tokens with no subscriptions registered

#### 9. Fix Double-Run on Manual Wake After Notification
**Status**: Done

**Problem**: When a notification-triggered job was queued (e.g. from unchecking checklist items) and the user then triggered a manual wake, both the pending subscription job AND the manual job executed back-to-back.

**Changes**:
- Added `WakeQueue.removeByAgent()` method (`lib/features/agents/wake/wake_queue.dart`) to remove all queued jobs for a given agent
- Updated `enqueueManualWake()` (`lib/features/agents/wake/wake_orchestrator.dart`) to call `queue.removeByAgent(agentId)` before enqueuing the manual job — the manual run supersedes pending subscription wakes
- Added tests for `removeByAgent` and the manual-wake-removes-subscription-jobs behavior

### Verification
- Analyzer: Zero warnings/infos for entire project
- All 1216 agent tests pass
- Formatter: All files formatted
