# Task Search: Agent Reports & Metadata Embeddings

**Date:** 2026-03-03
**Branch:** `feat/task-search-agent-reports-metadata`
**Goal:** Dramatically improve vector search relevance for tasks by embedding agent reports and enriched task metadata (title + labels), and adding direct `task_id` / `subtype` columns to the embeddings metadata table for efficient lookups.

---

## Problem Statement

Tasks are currently embedded using only `title` + optional `entryText.plainText` (see `EmbeddingContentExtractor._taskText()`). Most tasks have **no body text**, so the embedding is either:
- A bare title (often < 20 chars → skipped entirely), or
- A short title that produces a weak, low-signal vector.

Meanwhile, AI agents write rich markdown reports about tasks via the `update_report` tool call, but these reports live exclusively in the agent database (`agent_entities` table) and are **invisible to vector search**.

**Result:** Searching for "authentication issues" misses a task titled "Fix login" that has a detailed agent report discussing JWT validation failures.

---

## Architecture Overview

### Current Embedding Pipeline

```text
Entity change → UpdateNotifications.localUpdateStream
  → EmbeddingService._onBatch()
    → EmbeddingProcessor.processEntity()
      → EmbeddingContentExtractor.extractText()  ← text extraction
      → EmbeddingContentExtractor.entityType()   ← type classification
      → SHA-256 content hash check (skip if unchanged)
      → OllamaEmbeddingRepository.embed()        ← Ollama API call
      → EmbeddingsDb.upsertEmbedding()           ← sqlite-vec storage
```

### Current Schema (`embeddings.sqlite`)

```sql
embedding_metadata(entity_id PK, entity_type, model_id, content_hash, created_at, category_id)
vec_embeddings(entity_id PK, embedding float[1024])
```

### Current Entity Types

- `journal_text` — JournalEntry with EntryText
- `task` — Task (title + optional body)
- `audio` — JournalAudio (transcript)
- `ai_response` — AiResponseEntry

### Agent Report Lifecycle

1. Agent runs a wake cycle → calls `update_report(tldr:, content:)` tool
2. `TaskAgentStrategy` accumulates report content
3. `TaskAgentWorkflow` persists `AgentReportEntity` + updates `AgentReportHeadEntity` pointer
4. Agent ↔ Task link tracked via `AgentLink.agentTask(fromId: agentId, toId: taskId)`
5. `taskId` available in workflow via `state.slots.activeTaskId`

---

## Implementation Plan

### Step 1: Schema Migration — Add `task_id` and `subtype` Columns

**File:** `lib/features/ai/database/embeddings_db.dart`

Add two new columns to `embedding_metadata`:

```sql
CREATE TABLE IF NOT EXISTS embedding_metadata (
  entity_id   TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  model_id    TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  category_id TEXT NOT NULL DEFAULT '',
  task_id     TEXT NOT NULL DEFAULT '',    -- NEW: direct task lookup
  subtype     TEXT NOT NULL DEFAULT ''     -- NEW: agent name / report kind
);

CREATE INDEX IF NOT EXISTS idx_task_id ON embedding_metadata(task_id);
```

**Migration strategy:** Same as the existing `category_id` migration — detect missing columns via `PRAGMA table_info`, drop & recreate both tables if mismatch (embeddings are derived data, safe to rebuild).

**Changes:**
- Add `_hasMissingTaskIdColumn()` check in `_createSchema()`
- Add `_hasMissingSubtypeColumn()` check in `_createSchema()`
- Add `task_id` and `subtype` parameters to `upsertEmbedding()` (default `''`)
- Add `idx_task_id` index creation
- Update `EmbeddingSearchResult` to include `taskId` and `subtype` fields
- Update `search()` SQL to SELECT `m.task_id` and `m.subtype`

**Tests:** `test/features/ai/database/embeddings_db_test.dart`
- Schema migration triggers correctly when columns are missing
- `upsertEmbedding` stores and retrieves `task_id` / `subtype`
- Search results include new fields

---

### Step 2: "Tiny Template" — Enrich Task Text with Labels

**File:** `lib/features/ai/service/embedding_content_extractor.dart`

Replace the current `_taskText()` method with an enriched version that includes label names.

Current:
```dart
static String? _taskText(TaskData data, EntryText? entryText) {
  final body = entryText?.plainText;
  if (body != null && body.isNotEmpty) {
    return '${data.title}\n$body';
  }
  return data.title;
}
```

New approach — add a `extractTaskText()` static method that accepts resolved label names:

```dart
static String extractTaskText({
  required String title,
  required List<String> labelNames,
  String? bodyText,
}) {
  final buffer = StringBuffer(title);
  if (labelNames.isNotEmpty) {
    buffer
      ..write('\n')
      ..write('Labels: ')
      ..write(labelNames.join(', '));
  }
  if (bodyText != null && bodyText.isNotEmpty) {
    buffer
      ..write('\n')
      ..write(bodyText);
  }
  return buffer.toString();
}
```

**Why a separate method?** The current `extractText()` only takes a `JournalEntity`, which has `labelIds` but not resolved label names. Label resolution requires a DB query (`JournalDb.getAllLabelDefinitions()`). Rather than making `extractText()` async, we:
1. Keep `extractText()` as the synchronous fast path
2. Add `extractTaskText()` as the label-aware path
3. Update `EmbeddingProcessor.processEntity()` to resolve labels for tasks and call the enriched path

**File:** `lib/features/ai/service/embedding_processor.dart`

Update `processEntity()`:
- Accept an optional `labelResolver` callback parameter: `Future<List<String>> Function(List<String> labelIds)?`
- For `Task` entities, resolve label names and call `extractTaskText()` instead of `extractText()`
- The label resolver will be injected from `EmbeddingService` (which has access to `JournalDb`)

**File:** `lib/features/ai/service/embedding_service.dart`

Wire up the label resolver:
- Query `JournalDb.getAllLabelDefinitions()` (cached per batch, not per entity)
- Build a `Map<String, String>` of id → name
- Pass resolver to `EmbeddingProcessor.processEntity()`

**Tests:**
- `test/features/ai/service/embedding_content_extractor_test.dart` — verify template output format
- `test/features/ai/service/embedding_processor_test.dart` — verify label resolution integration
- `test/features/ai/service/embedding_service_test.dart` — verify label cache per batch

---

### Step 3: Agent Report Embedding — New Entity Type

**File:** `lib/features/ai/service/embedding_content_extractor.dart`

Add new entity type constant:
```dart
const kEntityTypeAgentReport = 'agent_report';
```

**File:** `lib/features/ai/service/embedding_processor.dart`

Add a new static method for processing agent reports:

```dart
static Future<bool> processAgentReport({
  required String reportId,
  required String reportContent,
  required String taskId,
  required String categoryId,
  required String subtype,      // agent template name or scope
  required EmbeddingsDb embeddingsDb,
  required OllamaEmbeddingRepository embeddingRepository,
  required String baseUrl,
}) async {
  final text = reportContent.trim();
  if (text.length < kMinEmbeddingTextLength) return false;

  final hash = EmbeddingContentExtractor.contentHash(text);
  final existingHash = embeddingsDb.getContentHash(reportId);
  if (existingHash == hash) return false;

  final embedding = await embeddingRepository.embed(
    input: text,
    baseUrl: baseUrl,
  );

  embeddingsDb.upsertEmbedding(
    entityId: reportId,
    entityType: kEntityTypeAgentReport,
    modelId: ollamaEmbedDefaultModel,
    embedding: embedding,
    contentHash: hash,
    categoryId: categoryId,
    taskId: taskId,
    subtype: subtype,
  );

  return true;
}
```

**Key design decisions:**
- `entityId` = the report's UUID (not the task's) — each report gets its own vector
- `taskId` stored in metadata for instant resolution back to the parent task
- `subtype` = agent template name (e.g., "Lotti", "Tom") for future multi-agent disambiguation
- When a new report supersedes an old one, the old embedding is **not deleted automatically** — the head pointer pattern means we can query the head to find the current report ID, then delete stale embeddings during backfill/maintenance

**Tests:** `test/features/ai/service/embedding_processor_test.dart`
- Agent report embedding generation
- Content hash skip for unchanged reports
- `task_id` and `subtype` stored correctly

---

### Step 4: Trigger Agent Report Embedding After Workflow Persistence

**File:** `lib/features/agents/workflow/task_agent_workflow.dart`

After the report is persisted (step 9 in the workflow, ~line 425-458), trigger embedding:

```dart
// After persisting report and head pointer:
if (reportContent.isNotEmpty) {
  // ... existing report persistence code ...

  // Trigger embedding for the agent report.
  _triggerReportEmbedding(
    reportId: reportId,
    reportContent: reportContent,
    taskId: taskId,
    categoryId: task.meta.categoryId ?? '',
  );
}
```

**Implementation options (choose one):**

**Option A — Direct call (simpler, preferred):**
Add a method that directly calls `EmbeddingProcessor.processAgentReport()` in a fire-and-forget `Future`. The workflow already has access to all required dependencies. Catch and log errors to avoid disrupting the workflow.

**Option B — Notification-based (consistent with existing pattern):**
- Add `const agentReportNotification = 'AGENT_REPORT';` to `lib/services/db_notification.dart`
- Add `agentReportNotification` to `EmbeddingService._relevantTokens`
- Fire notification with `{agentReportNotification, reportId}` after persistence
- Requires `EmbeddingService` to handle agent reports differently (they're not in the journal DB), so it would need access to the agent repository or the report content directly

**Recommendation:** Option A — direct call. The notification-based approach adds complexity because agent reports live in a different database (`agent_entities`) than journal entities. The `EmbeddingProcessor.processEntity()` method fetches from `JournalDb`, which wouldn't find agent reports. A direct call avoids this impedance mismatch.

**File:** `lib/features/agents/workflow/task_agent_workflow.dart`

Add dependency: `EmbeddingsDb` and `OllamaEmbeddingRepository` (via GetIt or constructor injection).

**Tests:** `test/features/agents/workflow/task_agent_workflow_test.dart`
- Verify embedding is triggered after report persistence
- Verify embedding failure doesn't break the workflow
- Verify `task_id` is correctly passed through

---

### Step 5: Supersede Old Report Embeddings

When a new agent report is created for the same agent+scope, the old report's embedding becomes stale.

**File:** `lib/features/agents/workflow/task_agent_workflow.dart`

Before creating the new report embedding, delete the old one:

```dart
// If there was a previous report head, delete its embedding.
if (existingHead != null) {
  embeddingsDb.deleteEmbedding(existingHead.reportId);
}
```

This ensures only the latest report for each agent+scope is in the vector DB, avoiding duplicate/contradictory results.

**Tests:**
- Old report embedding is deleted when new report is created
- First report (no existing head) doesn't cause errors

---

### Step 6: Update Vector Search Resolution

**File:** `lib/features/ai/repository/vector_search_repository.dart`

Update `_resolveToTasks()` to handle `kEntityTypeAgentReport` results:

Currently, non-task results are resolved via `journalDb.linksForIds()` (journal entry links). Agent report results need a different path — use the `task_id` from `EmbeddingSearchResult`.

```dart
// In the resolution loop:
for (final result in searchResults) {
  if (result.entityType == kEntityTypeAgentReport) {
    // Use task_id from embedding metadata for direct resolution
    final taskId = result.taskId;
    if (taskId.isNotEmpty && !seenTaskIds.contains(taskId)) {
      final task = await journalDb.journalEntityById(taskId);
      if (task != null) {
        tasks.add(task);
        seenTaskIds.add(taskId);
      }
    }
    continue;
  }
  // ... existing resolution logic for other types ...
}
```

**Tests:** `test/features/ai/repository/vector_search_repository_test.dart`
- Agent report search results resolve to their parent tasks via `task_id`
- Deduplication: task from direct hit + agent report hit → appears once
- Empty `task_id` on agent report result is handled gracefully

---

### Step 7: Backfill Support for Agent Reports

**File:** `lib/features/ai/state/embedding_backfill_controller.dart`

Extend the backfill controller to also process existing agent reports:

1. Query all `AgentReportHeadEntity` entries (via `AgentRepository`)
2. For each head, resolve the latest report + parent task (via `agentTask` link)
3. Call `EmbeddingProcessor.processAgentReport()` for each

This can be a separate backfill method (e.g., `backfillAgentReports()`) or integrated into the existing category-scoped backfill.

**Recommendation:** Separate method, triggered from the same backfill UI modal. Agent reports span categories, so a per-category scope doesn't apply cleanly.

**Tests:** `test/features/ai/state/embedding_backfill_controller_test.dart`
- Backfill processes all report heads
- Already-embedded reports are skipped (content hash)
- Missing task links are handled gracefully

---

### Step 8: Re-embed Tasks with Label Enrichment (Backfill)

The existing task embeddings were generated without labels. After the tiny template change, a re-embed is needed.

**Approach:** Invalidate existing task embeddings by changing the content hash input (the template now includes labels, so the hash will naturally differ). The existing backfill mechanism will detect the hash mismatch and re-embed.

No explicit migration code needed — the next backfill run will automatically pick up the changes because:
1. `extractTaskText()` now includes labels → different text → different hash
2. Existing hash ≠ new hash → re-embedding triggered

---

## File Change Summary

| File | Change |
|------|--------|
| `lib/features/ai/database/embeddings_db.dart` | Add `task_id`, `subtype` columns; migration checks; update `upsertEmbedding()` signature; update `EmbeddingSearchResult`; update `search()` SELECT |
| `lib/features/ai/service/embedding_content_extractor.dart` | Add `kEntityTypeAgentReport`; add `extractTaskText()` with label support |
| `lib/features/ai/service/embedding_processor.dart` | Add `processAgentReport()` method; update `processEntity()` for label-enriched tasks |
| `lib/features/ai/service/embedding_service.dart` | Add label caching/resolution per batch |
| `lib/features/agents/workflow/task_agent_workflow.dart` | Trigger report embedding after persistence; delete old report embedding on supersede |
| `lib/features/ai/repository/vector_search_repository.dart` | Handle `kEntityTypeAgentReport` resolution via `task_id` |
| `lib/features/ai/state/embedding_backfill_controller.dart` | Add `backfillAgentReports()` method |
| `lib/services/db_notification.dart` | (Optional) Add `agentReportNotification` constant if using notification-based approach |

**Test files (mirror source paths):**

| Test File | Coverage |
|-----------|----------|
| `test/features/ai/database/embeddings_db_test.dart` | Schema migration, new columns, search results |
| `test/features/ai/service/embedding_content_extractor_test.dart` | Tiny template format, agent report type |
| `test/features/ai/service/embedding_processor_test.dart` | Agent report processing, label-enriched tasks |
| `test/features/ai/service/embedding_service_test.dart` | Label cache per batch |
| `test/features/ai/repository/vector_search_repository_test.dart` | Agent report resolution, deduplication |
| `test/features/agents/workflow/task_agent_workflow_test.dart` | Embedding trigger, supersede, error handling |
| `test/features/ai/state/embedding_backfill_controller_test.dart` | Agent report backfill |

---

## Execution Order

```text
Step 1: Schema migration (task_id, subtype)     ← Foundation, unblocks everything
  ↓
Step 2: Tiny template (title + labels)           ← Independent of agent reports
  ↓
Step 3: Agent report processor                   ← Needs schema from Step 1
  ↓
Step 4: Workflow integration (trigger embedding) ← Needs processor from Step 3
  ↓
Step 5: Supersede old embeddings                 ← Extension of Step 4
  ↓
Step 6: Vector search resolution                 ← Needs schema from Step 1
  ↓
Step 7: Backfill for agent reports               ← Needs processor from Step 3
  ↓
Step 8: Re-embed tasks (automatic via backfill)  ← Needs template from Step 2
```

Steps 2 and 3 can be done in parallel after Step 1.
Steps 6 and 7 can be done in parallel after Steps 3-5.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Schema migration drops all embeddings | Embeddings are derived data — backfill regenerates them. Show a notification to the user that backfill is needed after upgrade. |
| Agent reports can be very long (> Ollama context window) | Truncate to a safe limit (e.g., 8192 chars) before embedding. `mxbai-embed-large` supports up to 512 tokens. |
| Label names change after embedding | The content hash will differ on next update, triggering re-embedding. No special handling needed. |
| Cross-database dependency (agent DB → embeddings DB) | Keep the coupling minimal — only the workflow calls the embedding processor. No new DB joins across databases. |
| Ollama unavailable when report is persisted | Catch and log — the report is still saved in the agent DB. Backfill can pick it up later. |

---

## Out of Scope (Future Work)

- Journal/logbook search improvements (per the original plan: tasks first)
- Multi-agent disambiguation in search results (subtype column is ready but UI is not)
- Embedding TLDR separately from full content (could improve short-query relevance)
- Real-time re-embedding when labels are added/removed from a task (would need label-change notification → re-embed trigger)
