# Embedding Chunking with Overlaps for Long Documents

**Date:** 2026-03-04
**Branch:** `feat/embedding-chunking-overlap`
**Goal:** Improve search accuracy for long recordings and agent reports by breaking their text into overlapping chunks that fit within the `mxbai-embed-large` model's 512-token context window. Ensure every part of a long transcript is semantically searchable, not just the first ~400 words.

---

## Problem Statement

The `mxbai-embed-large` embedding model has a **512-token context window** (~350–400 words). When a long recording transcript (e.g., a 60-minute meeting with 5,000+ words) is sent to Ollama as a single string, the model silently truncates everything beyond the first ~512 tokens. The resulting embedding only represents the beginning of the recording — content discussed later is invisible to vector search.

**Current behavior:**
- User records a 60-minute meeting
- Transcript: "Sprint planning... [minute 1–5] ... budget approval needed by Friday ... [minute 45]"
- The embedding only captures the first ~400 words (sprint planning)
- Searching "budget approval" returns **no results**

**Desired behavior:**
- The transcript is split into overlapping chunks, each ≤ 512 tokens
- Each chunk gets its own embedding vector
- Searching "budget approval" finds the chunk containing that discussion
- Results are deduplicated: the best-matching chunk determines the document's rank

---

## Architecture Overview

### Current State (Single Embedding per Entity)

```text
Long transcript (5000 words)
  → embed() → 1 vector (captures only first ~400 words)
  → 1 row in embedding_metadata + 1 row in vec_embeddings
```

### Target State (Multiple Chunks per Entity)

```text
Long transcript (5000 words)
  → chunk into ~15 overlapping pieces (~400 words each, 10–20% overlap)
  → embed() × 15 → 15 vectors
  → 15 rows in embedding_metadata + 15 rows in vec_embeddings
  → search returns best-matching chunk per source entity
```

### Visual: Before vs After

```text
Original: [==========A==========B==========C==========D==========]

Before (one embedding):
[====A====] ← only this gets read, B/C/D invisible

After (chunked with overlaps):
[====A====~~]                          ← chunk 0
         [~~A====B====~~]              ← chunk 1 (overlaps with chunk 0)
                  [~~B====C====~~]     ← chunk 2 (overlaps with chunk 1)
                           [~~C====D====]  ← chunk 3 (overlaps with chunk 2)

~~ = overlap region (~50 words shared between consecutive chunks)
```

---

## Token Overlap Strategy

**Model context:** 512 tokens (mxbai-embed-large)
**Target chunk size:** 384 tokens (~75% of window, leaves headroom)
**Overlap:** 64 tokens (~12.5% of chunk size, ~16.7% of window)
**Stride:** 320 tokens (384 − 64)

### Why These Numbers

- **384 tokens** instead of 512: provides a safety margin. Token counts are estimated from character/word counts, and slight overestimates are safer than truncation.
- **64-token overlap** (~50 words): large enough to preserve sentence boundaries and maintain context continuity. Falls within the recommended 10–20% range.
- **Sentence-boundary alignment:** After computing token-based boundaries, adjust chunk start/end to the nearest sentence boundary (`.`, `!`, `?`, `\n\n`) to avoid splitting mid-sentence. This is more important than hitting exact token counts.

### Tokenization Approach

`mxbai-embed-large` uses a WordPiece tokenizer. Exact token counting requires the model's vocabulary, which we don't have client-side. Instead, use a **word-based heuristic**: assume ~1.3 tokens per whitespace-delimited word (standard for English text with subword tokenization). This gives:

- 384 tokens ≈ 295 words
- 64 tokens ≈ 49 words
- 320 stride ≈ 246 words

**Constants to define:**

```dart
const kChunkTargetTokens = 384;
const kChunkOverlapTokens = 64;
const kChunkStrideTokens = 320; // kChunkTargetTokens - kChunkOverlapTokens
const kTokensPerWord = 1.3;     // heuristic for mxbai-embed-large WordPiece
const kChunkTargetWords = 295;   // (kChunkTargetTokens / kTokensPerWord).floor()
const kChunkOverlapWords = 49;
const kChunkStrideWords = 246;
const kMinChunkableLength = 600; // word count above which chunking activates
```

**Short text bypass:** If the full text is ≤ 384 estimated tokens (~295 words), embed as a single chunk (chunk_index = 0). No overhead for the common case of short tasks and journal entries.

---

## Implementation Plan

### Step 1: Add Chunking Utility

**File:** `lib/features/ai/service/text_chunker.dart` (new)

Create a pure utility class `TextChunker` with:

```dart
class TextChunker {
  /// Splits text into overlapping chunks suitable for embedding.
  /// Returns a single-element list if text fits within one chunk.
  static List<String> chunk(String text);

  /// Estimates token count using word-based heuristic.
  static int estimateTokens(String text);
}
```

**Chunking algorithm:**
1. If `estimateTokens(text) <= kChunkTargetTokens`, return `[text]`
2. Split text into sentences (regex: split on `.` / `!` / `?` / `\n\n` followed by whitespace, keeping delimiters with preceding sentence)
3. Greedily accumulate sentences into chunks until adding the next sentence would exceed `kChunkTargetTokens`
4. When a chunk is full, start the next chunk by rewinding to include the last `kChunkOverlapTokens` worth of sentences from the previous chunk
5. If a single sentence exceeds `kChunkTargetTokens`, include it as its own chunk (the model will truncate, but it's better than dropping it entirely)

**Test file:** `test/features/ai/service/text_chunker_test.dart`

Tests:
- Short text (< threshold) returns single chunk
- Long text produces multiple chunks with correct overlap
- Sentence boundaries are respected (no mid-sentence splits)
- Very long single sentence handled gracefully
- Empty / whitespace-only input returns empty list
- Overlap content appears in consecutive chunks
- Unicode text handled correctly

---

### Step 2: Update Database Schema

**File:** `lib/features/ai/database/embeddings_db.dart`

**Schema changes to `embedding_metadata`:**

Add `chunk_index` column:
```sql
CREATE TABLE IF NOT EXISTS embedding_metadata (
  entity_id TEXT NOT NULL,        -- was PRIMARY KEY, now part of composite
  chunk_index INTEGER NOT NULL DEFAULT 0,
  entity_type TEXT NOT NULL,
  model_id TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  category_id TEXT NOT NULL DEFAULT '',
  task_id TEXT NOT NULL DEFAULT '',
  subtype TEXT NOT NULL DEFAULT '',
  PRIMARY KEY (entity_id, chunk_index)
);
```

**New index:**
```sql
CREATE INDEX idx_entity_id ON embedding_metadata(entity_id);
```
(Needed for efficient "delete all chunks for entity" and "find all chunks for entity" queries.)

**Changes to `vec_embeddings`:**

The vec0 virtual table's primary key must be a single TEXT column. Use a composite key string:
```sql
CREATE VIRTUAL TABLE IF NOT EXISTS vec_embeddings
  USING vec0(
    embedding_id TEXT PRIMARY KEY,  -- format: "{entity_id}:{chunk_index}"
    embedding float[1024]
  );
```

**Helper for composite ID:**
```dart
static String embeddingId(String entityId, int chunkIndex) =>
    '$entityId:$chunkIndex';
```

**Migration strategy:** The existing schema detection in `_ensureSchema()` already drops and recreates tables when columns are missing. Adding `chunk_index` will trigger this automatic migration. All embeddings will be regenerated via backfill (embeddings are derived data).

**Updated `upsertEmbedding`:**
- Accept `chunkIndex` parameter (default 0)
- Use composite `embedding_id` for `vec_embeddings`
- Use `(entity_id, chunk_index)` composite PK for `embedding_metadata`

**New method: `deleteEntityEmbeddings(entityId)`:**
- Delete all rows from `embedding_metadata` WHERE `entity_id = ?`
- Delete all rows from `vec_embeddings` WHERE `embedding_id LIKE '{entityId}:%'` or iterate known chunk indices

**Updated `search`:**
- JOIN condition: `v.embedding_id = m.entity_id || ':' || m.chunk_index`
- Return `chunk_index` in results

**New method: `getEntityChunkCount(entityId)`:**
- `SELECT COUNT(*) FROM embedding_metadata WHERE entity_id = ?`
- Used to detect stale chunks that need cleanup when content shrinks

**Test updates:** `test/features/ai/database/embeddings_db_test.dart`
- Test composite key: multiple chunks per entity
- Test `deleteEntityEmbeddings` removes all chunks
- Test search returns correct `chunk_index`
- Test that best chunk per entity appears first in results

---

### Step 3: Update Embedding Processor for Chunking

**File:** `lib/features/ai/service/embedding_processor.dart`

**Updated `processEntity`:**
1. Extract text (unchanged)
2. Compute content hash of **full text** (unchanged — used to skip unchanged entities)
3. Call `TextChunker.chunk(text)` → `List<String> chunks`
4. For each chunk: call `embeddingRepository.embed()` and `embeddingsDb.upsertEmbedding(entityId, chunkIndex: i, ...)`
5. If entity previously had more chunks than now (content shortened), delete stale chunks via `deleteEntityEmbeddings` first, then re-insert
6. Strategy: always delete-all-then-insert-all when content hash changes. Simpler and content hash check prevents unnecessary re-processing.

**Updated `processAgentReport`:**
- Same chunking logic applied to report content

**Test updates:** `test/features/ai/service/embedding_processor_test.dart`
- Test short entity produces single chunk (chunk_index = 0)
- Test long entity produces multiple chunks
- Test content change triggers re-chunking (old chunks deleted)
- Test content hash skip still works (no re-embedding if unchanged)

---

### Step 4: Update Search Result Resolution

**File:** `lib/features/ai/repository/vector_search_repository.dart`

**Updated `searchRelatedTasks`:**
- Increase `k` parameter internally (e.g., `k * 3`) to account for multiple chunks per entity, then deduplicate to return the requested number of unique tasks
- After KNN search, deduplicate by `entity_id`: keep only the **best (lowest distance) chunk** per entity
- Then resolve to tasks as before

**Updated `_resolveToTasks`:**
- The `entity_id` in search results now refers to the source entity (same as before — chunk_index is stripped)
- Resolution logic unchanged; deduplication already exists via `seenIds`

**Test updates:** `test/features/ai/repository/vector_search_repository_test.dart`
- Test multiple chunks from same entity: only best chunk's score is used
- Test that k results are returned even when chunks inflate raw result count

---

### Step 5: Update Real-Time Embedding Service

**File:** `lib/features/ai/service/embedding_service.dart`

Minimal changes — the service calls `EmbeddingProcessor.processEntity()` which handles chunking internally. The service just needs to remain aware that one entity may produce multiple embeddings (no code change needed if processor handles everything).

**Test review:** Verify existing tests still pass with the chunking changes.

---

### Step 6: Update Backfill Controller

**File:** `lib/features/ai/state/embedding_backfill_controller.dart`

**Add `reindexAll()` method:**
1. Clear all existing embeddings (`DELETE FROM embedding_metadata; DELETE FROM vec_embeddings`)
2. Run `backfillCategory()` for all categories
3. Run `backfillAgentReports()`
4. Report progress throughout

This is the "maintenance task to re-index hundreds of existing task reports" mentioned in the requirements.

**Update `backfillCategory` and `backfillAgentReports`:**
- These already call `EmbeddingProcessor.processEntity/processAgentReport`, which will now handle chunking. The content hash check will detect that all existing embeddings need re-processing (because the old schema is gone after migration).

**UI update for backfill modal:**
- Add a "Re-index All" button alongside the existing category-specific backfill
- Show warning that this may take a while for large datasets

**Test updates:** `test/features/ai/state/embedding_backfill_controller_test.dart`
- Test `reindexAll()` clears and rebuilds
- Test progress reporting during reindex

---

### Step 7: Update Content Extractor Constants

**File:** `lib/features/ai/service/embedding_content_extractor.dart`

No structural changes needed. The extractor returns full text; the chunker splits it downstream.

Optional: add a `isChunkable(text)` helper that returns `estimateTokens(text) > kChunkTargetTokens` for use in logging/metrics.

---

### Step 8: Add Localization Strings

**Files:** `lib/l10n/app_en.arb`, `app_de.arb`, `app_cs.arb`, `app_es.arb`, `app_fr.arb`, `app_ro.arb`

New strings for the backfill UI:
- `embeddingReindexAllButton` — "Re-index All Embeddings"
- `embeddingReindexAllWarning` — "This will rebuild all embeddings with improved chunking. This may take a while."
- `embeddingReindexAllProgress` — "Re-indexing: {current} / {total}"

---

### Step 9: Update CHANGELOG and Metadata

**Files:** `CHANGELOG.md`, `flatpak/com.matthiasn.lotti.metainfo.xml`

Add entry under current version describing the chunking improvement.

---

## File Change Summary

| File | Change |
|---|---|
| `lib/features/ai/service/text_chunker.dart` | **NEW** — chunking utility |
| `lib/features/ai/database/embeddings_db.dart` | Schema: composite PK, `chunk_index` column, updated upsert/search/delete |
| `lib/features/ai/service/embedding_processor.dart` | Chunk text before embedding, delete-all-then-insert on change |
| `lib/features/ai/repository/vector_search_repository.dart` | Deduplicate chunks in search, inflate k |
| `lib/features/ai/state/embedding_backfill_controller.dart` | Add `reindexAll()` method |
| `lib/features/ai/service/embedding_content_extractor.dart` | Optional: add `isChunkable()` helper |
| `lib/features/ai/ui/settings/embedding_backfill_modal.dart` | Add "Re-index All" button |
| `lib/features/ai/state/consts.dart` | Chunking constants |
| `lib/l10n/app_*.arb` | New localization strings |
| `test/features/ai/service/text_chunker_test.dart` | **NEW** — chunker tests |
| `test/features/ai/database/embeddings_db_test.dart` | Updated for composite key |
| `test/features/ai/service/embedding_processor_test.dart` | Updated for chunking |
| `test/features/ai/repository/vector_search_repository_test.dart` | Updated for chunk dedup |
| `test/features/ai/state/embedding_backfill_controller_test.dart` | Test `reindexAll()` |

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Token estimate inaccuracy (heuristic vs real tokenizer) | Use conservative target (384 vs 512); sentence-boundary alignment absorbs variance |
| Backfill takes very long for large datasets | Progress UI with cancel button; process in batches |
| Schema migration deletes all embeddings | Expected and acceptable — embeddings are derived data |
| sqlite-vec JOIN performance with more rows | The vec0 KNN is O(n) scan regardless; metadata JOIN is indexed. Monitor if > 100k rows. |
| Overlap inflates storage ~12% | Negligible for 1024-dim float32 vectors (~4KB each) |

---

## Success Criteria

1. Searching for content that appears late in a long transcript returns the parent task
2. Short entities (< 384 tokens) produce exactly 1 chunk (no performance regression)
3. All existing tests pass after schema migration
4. New tests cover: chunking logic, overlap correctness, composite key operations, search deduplication
5. Re-index maintenance task successfully rebuilds all embeddings with chunking
