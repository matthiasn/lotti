# Sharded Vector Search with Relevance Cutoff

**Date:** 2026-03-07
**Status:** Draft — awaiting review before implementation
**Priority:** P1

## Problem Statement

The current single-database vector search architecture has two critical issues:

1. **Drowning problem**: When categories have vastly different sizes (e.g., "Documents" has 10,000
   entries, "Profiles" has 50), a query for entries across both categories returns results dominated
   by the larger category. The `k * 3` oversampling heuristic is insufficient — rare-category results
   are simply absent from the top-N HNSW neighbors.

2. **Trash results**: ObjectBox HNSW always returns the top N results regardless of actual relevance.
   A query about "Kubernetes deployment" against a "Recipes" category still returns 20 recipe entries
   with high cosine distances. There is no relevance cutoff.

## Current Architecture

```mermaid
graph TD
    subgraph User Layer
        UI["Search UI<br/><i>JournalPageController</i>"]
    end

    subgraph Orchestration
        VSR["VectorSearchRepository<br/>searchRelatedTasks(query, k=20, categoryIds?)"]
    end

    subgraph Embedding
        OER["OllamaEmbeddingRepository<br/>embed(input, baseUrl) → Float32List"]
    end

    subgraph Storage ["Single ObjectBox Store"]
        ES["ObjectBoxEmbeddingStore<br/>search(queryVector, k×3, categoryIds?)"]
        OPS["RealObjectBoxOps<br/>nearestNeighborSearch()"]
        HNSW["HNSW Index<br/>1024-dim cosine<br/><b>ALL categories mixed</b>"]
    end

    subgraph Post-Processing
        FILTER["Post-filter by categoryId<br/>(oneOf condition on index)"]
        DEDUP["Deduplicate chunks<br/>keep lowest distance per entity"]
        TRIM["Trim to k results"]
    end

    UI -->|"query text + categoryIds"| VSR
    VSR -->|"query text"| OER
    OER -->|"Float32List (1024-dim)"| VSR
    VSR -->|"queryVector, k×3"| ES
    ES --> OPS
    OPS --> HNSW
    HNSW -->|"top k×3 neighbors"| FILTER
    FILTER -->|"category-matched hits"| DEDUP
    DEDUP --> TRIM
    TRIM -->|"≤k results"| VSR
    VSR -->|"resolved JournalEntities"| UI

    style HNSW fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style FILTER fill:#ffa94d,stroke:#e67700
    style Storage fill:#fff3bf,stroke:#f59f00
```

```mermaid
graph LR
    subgraph "Filesystem: documentsPath/objectbox_embeddings/"
        DATA["data.mdb<br/><i>Single HNSW index</i><br/>All categories interleaved"]
    end

    style DATA fill:#ff6b6b,stroke:#c92a2a,color:#fff
```

### The Drowning Problem (Visualized)

```mermaid
graph TD
    subgraph "Single HNSW Index — Query: 'project deadline'"
        direction TB
        Q["Query Vector"]
        Q --> HNSW["HNSW Search<br/>maxResults = 60 (k×3)"]

        HNSW --> R1["Result 1: Task doc — dist 0.15"]
        HNSW --> R2["Result 2: Task doc — dist 0.18"]
        HNSW --> R3["Result 3: Task doc — dist 0.22"]
        HNSW --> RN["... Results 4-58: all Task docs ..."]
        HNSW --> R59["Result 59: Task doc — dist 0.71"]
        HNSW --> R60["Result 60: Task doc — dist 0.73"]
    end

    subgraph "Post-filter: categoryId.oneOf(['profiles'])"
        R1 -.-x|"❌ wrong category"| DROP1["Dropped"]
        R2 -.-x|"❌ wrong category"| DROP2["Dropped"]
        R3 -.-x|"❌ wrong category"| DROP3["Dropped"]
        RN -.-x|"❌ all wrong category"| DROPN["Dropped"]
        R59 -.-x|"❌ wrong category"| DROP59["Dropped"]
        R60 -.-x|"❌ wrong category"| DROP60["Dropped"]
    end

    EMPTY["⚠️ 0 results for 'Profiles' category<br/>even though relevant entries exist!"]

    DROP1 ~~~ EMPTY
    DROP60 ~~~ EMPTY

    style EMPTY fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style DROP1 fill:#868e96,stroke:#495057,color:#fff
    style DROP2 fill:#868e96,stroke:#495057,color:#fff
    style DROP3 fill:#868e96,stroke:#495057,color:#fff
    style DROPN fill:#868e96,stroke:#495057,color:#fff
    style DROP59 fill:#868e96,stroke:#495057,color:#fff
    style DROP60 fill:#868e96,stroke:#495057,color:#fff
```

**Key files:**
- `lib/features/ai/database/embedding_store.dart` — abstract interface
- `lib/features/ai/database/objectbox_embedding_store.dart` — single-store implementation
- `lib/features/ai/database/objectbox_ops.dart` — ObjectBox operations abstraction
- `lib/features/ai/database/real_objectbox_ops.dart` — production ObjectBox ops
- `lib/features/ai/database/objectbox_embedding_entity.dart` — entity model
- `lib/features/ai/repository/vector_search_repository.dart` — search orchestration
- `lib/features/ai/service/embedding_service.dart` — background embedding pipeline
- `lib/features/ai/service/embedding_processor.dart` — per-entity processing
- `lib/get_it.dart` — DI registration (~line 399)

## Target Architecture

```mermaid
graph TD
    subgraph User Layer
        UI["Search UI<br/><i>JournalPageController</i>"]
    end

    subgraph Orchestration
        VSR["VectorSearchRepository<br/>searchRelatedTasks(query, k=20, categoryIds?)"]
        OER["OllamaEmbeddingRepository<br/>embed(input) → Float32List"]
    end

    subgraph "ShardedEmbeddingStore (implements EmbeddingStore)"
        ROUTER["Shard Router<br/>categoryIds → shard selection"]
        FANOUT["Fan-out Controller<br/>Future.wait() parallel queries"]
        MERGE["Result Merger<br/>combine + sort by distance"]
        CUTOFF["Distance Cutoff<br/>adaptive per-shard threshold"]
        TRIM["Global Trim<br/>top k from merged set"]
    end

    subgraph "Per-Category Shards"
        SA["Shard: Documents<br/>ObjectBoxEmbeddingStore<br/>HNSW Index (10k entries)"]
        SB["Shard: Profiles<br/>ObjectBoxEmbeddingStore<br/>HNSW Index (50 entries)"]
        SC["Shard: Recipes<br/>ObjectBoxEmbeddingStore<br/>HNSW Index (200 entries)"]
        SD["Shard: _default<br/>ObjectBoxEmbeddingStore<br/>HNSW Index (uncategorized)"]
    end

    UI -->|"query + categoryIds"| VSR
    VSR -->|"query text"| OER
    OER -->|"Float32List"| VSR
    VSR -->|"queryVector, k, categoryIds"| ROUTER
    ROUTER -->|"select relevant shards"| FANOUT
    FANOUT -->|"top k"| SA
    FANOUT -->|"top k"| SB
    FANOUT -->|"top k"| SC
    SA -->|"≤k results"| MERGE
    SB -->|"≤k results"| MERGE
    SC -->|"≤k results"| MERGE
    MERGE --> CUTOFF
    CUTOFF --> TRIM
    TRIM -->|"≤k globally ranked"| VSR
    VSR -->|"resolved JournalEntities"| UI

    style SA fill:#51cf66,stroke:#2b8a3e,color:#fff
    style SB fill:#51cf66,stroke:#2b8a3e,color:#fff
    style SC fill:#51cf66,stroke:#2b8a3e,color:#fff
    style SD fill:#868e96,stroke:#495057,color:#fff
    style CUTOFF fill:#ffd43b,stroke:#f59f00
    style FANOUT fill:#74c0fc,stroke:#1c7ed6
```

```mermaid
graph LR
    subgraph "Filesystem: documentsPath/objectbox_embeddings/"
        DEF["_default/<br/>data.mdb"]
        A["cat-uuid-A/<br/>data.mdb<br/><i>Documents</i>"]
        B["cat-uuid-B/<br/>data.mdb<br/><i>Profiles</i>"]
        C["cat-uuid-C/<br/>data.mdb<br/><i>Recipes</i>"]
        MARKER[".migrated<br/><i>migration marker</i>"]
    end

    style A fill:#51cf66,stroke:#2b8a3e,color:#fff
    style B fill:#51cf66,stroke:#2b8a3e,color:#fff
    style C fill:#51cf66,stroke:#2b8a3e,color:#fff
    style DEF fill:#868e96,stroke:#495057,color:#fff
    style MARKER fill:#e9ecef,stroke:#adb5bd
```

### Fan-Out Solves the Drowning Problem

```mermaid
graph TD
    subgraph "Query: 'project deadline' across Documents + Profiles"
        Q["Query Vector (1024-dim)"]
    end

    subgraph "Shard: Documents (10k entries)"
        Q -->|"parallel"| HA["HNSW Search<br/>top 20"]
        HA --> DA1["Doc result 1 — dist 0.15"]
        HA --> DA2["Doc result 2 — dist 0.18"]
        HA --> DA3["Doc result 3 — dist 0.22"]
        HA --> DAN["... up to 20 results"]
    end

    subgraph "Shard: Profiles (50 entries)"
        Q -->|"parallel"| HB["HNSW Search<br/>top 20"]
        HB --> DB1["Profile result 1 — dist 0.25"]
        HB --> DB2["Profile result 2 — dist 0.31"]
        HB --> DB3["Profile result 3 — dist 0.44"]
        HB --> DBN["... up to 20 results"]
    end

    subgraph "Merge & Rank"
        DA1 --> M["Global Sort by Distance"]
        DA2 --> M
        DA3 --> M
        DAN --> M
        DB1 --> M
        DB2 --> M
        DB3 --> M
        DBN --> M
        M --> FINAL["Final: 40 candidates → cutoff → top 20<br/>✅ Both categories fairly represented"]
    end

    style FINAL fill:#51cf66,stroke:#2b8a3e,color:#fff
    style HA fill:#74c0fc,stroke:#1c7ed6
    style HB fill:#74c0fc,stroke:#1c7ed6
```

Each category gets its own ObjectBox store with its own HNSW index. This guarantees that searching
category B always returns the best matches *within* category B, regardless of how many entries exist
in category A.

## Technical Analysis

### ObjectBox Multi-Store Feasibility

ObjectBox supports multiple `Store` instances in the same process, each with its own directory. The
`openStore()` function accepts a `directory` parameter. On macOS sandboxed apps, each store needs the
same `macosApplicationGroup` identifier for POSIX semaphore coordination.

**Constraints:**
- Each store holds its own HNSW index — no cross-store queries possible (by design, this is what we want)
- File handles: each store uses ~3-5 file descriptors. With typical category counts (5-20), this is
  well within OS limits
- Memory: HNSW indexes are memory-mapped. Smaller per-shard indexes are more cache-friendly than one
  large index
- Store open/close: stores can be opened lazily and closed when idle. ObjectBox stores are
  thread-safe and designed for long-lived use

### Cosine Distance Score Ranges

ObjectBox HNSW with `VectorDistanceType.cosine` returns scores in range `[0.0, 2.0]`:
- **0.0**: identical vectors
- **1.0**: orthogonal (unrelated)
- **2.0**: diametrically opposite

```mermaid
graph LR
    subgraph "Cosine Distance Spectrum (0.0 → 2.0)"
        direction LR
        Z["0.0<br/>Identical"] ~~~ A
        A["< 0.3<br/>Strong Match"] ~~~ B
        B["0.3 – 0.6<br/>Related"] ~~~ C
        C["0.6 – 0.8<br/>Weak"] ~~~ D
        D["> 0.8<br/>Trash"] ~~~ E
        E["1.0<br/>Orthogonal"] ~~~ F
        F["2.0<br/>Opposite"]
    end

    style Z fill:#2b8a3e,color:#fff
    style A fill:#51cf66,color:#fff
    style B fill:#ffd43b,color:#333
    style C fill:#ffa94d,color:#333
    style D fill:#ff6b6b,color:#fff
    style E fill:#c92a2a,color:#fff
    style F fill:#862e2e,color:#fff
```

Empirical ranges for `mxbai-embed-large` (1024-dim):
- **< 0.3**: Strong semantic match (same topic, paraphrased)
- **0.3 - 0.6**: Related content (same domain, tangential)
- **0.6 - 0.8**: Weak relation (broad category overlap)
- **> 0.8**: Essentially unrelated ("trash results")

**Action required**: We need to validate these ranges empirically with real data from the app. See
Phase 1 below.

## Implementation Plan

### Phase Dependency Graph

```mermaid
graph TD
    P0["Phase 0<br/><b>Relevance Score Investigation</b><br/>Non-breaking telemetry<br/>Ship to TestFlight"]
    P1["Phase 1<br/><b>ShardedEmbeddingStore</b><br/>Core multi-store implementation<br/>+ Migration logic"]
    P2["Phase 2<br/><b>Update Embedding Pipeline</b><br/>Route writes to shards<br/>Handle re-categorization"]
    P3["Phase 3<br/><b>Relevance Cutoff</b><br/>Adaptive per-shard threshold<br/>UI relevance indicator"]
    P4["Phase 4<br/><b>Backfill & Cleanup</b><br/>Populate shards, remove legacy<br/>Delete old store"]

    P0 -->|"calibrated threshold"| P3
    P0 -->|"can proceed independently"| P1
    P1 -->|"ShardedEmbeddingStore ready"| P2
    P1 -->|"search interface ready"| P3
    P2 -->|"pipeline routing done"| P4
    P3 -->|"cutoff integrated"| P4

    style P0 fill:#74c0fc,stroke:#1c7ed6
    style P1 fill:#ffd43b,stroke:#f59f00
    style P2 fill:#ffd43b,stroke:#f59f00
    style P3 fill:#b197fc,stroke:#7950f2
    style P4 fill:#51cf66,stroke:#2b8a3e,color:#fff
```

### Phase 0: Relevance Score Investigation (non-breaking)

**Goal:** Establish empirical distance thresholds before any architectural changes.

1. **Add distance logging to search results**
   - In `VectorSearchRepository._prepareSearch()`, log the distance distribution of returned results
     (min, max, median, count) using `DevLogger.info`
   - This runs on existing single-store architecture — zero risk

2. **Add distance field to VectorSearchResult**
   - Extend `VectorSearchResult` to carry `List<(JournalEntity, double distance)>` instead of
     just `List<JournalEntity>`
   - Display distance scores in the search results UI (debug overlay or dev mode only)

3. **Collect data from TestFlight**
   - Ship Phase 0 to TestFlight
   - Perform representative queries across different categories
   - Record distance distributions to calibrate the cutoff threshold

**Deliverable:** A validated distance threshold (expected: ~0.7-0.8 for cosine distance) and
a decision on whether to use a fixed cutoff or a relative one (e.g., "drop results > 2× the
best result's distance").

### Phase 1: ShardedEmbeddingStore (core implementation)

**Goal:** Implement the multi-store fan-out architecture behind the existing `EmbeddingStore`
interface.

#### 1a. New class: `ShardedEmbeddingStore`

```dart
/// Manages per-category ObjectBox stores and fans out queries.
class ShardedEmbeddingStore implements EmbeddingStore {
  ShardedEmbeddingStore({
    required String basePath,
    required String? macosApplicationGroup,
    this.distanceCutoff = 0.8,  // tunable, from Phase 0 findings
  });

  /// Category ID → open store. Lazily populated.
  final Map<String, ObjectBoxEmbeddingStore> _shards = {};

  /// The "default" shard for uncategorized entries (categoryId == '').
  static const _defaultShardKey = '_default';

  // --- EmbeddingStore interface ---

  @override
  Future<List<EmbeddingSearchResult>> search({
    required Float32List queryVector,
    int k = 10,
    String? entityTypeFilter,
    Set<String>? categoryIds,
  }) async {
    final shardsToQuery = _resolveShardsToQuery(categoryIds);

    // Fan-out: query each shard for top k results
    final allResults = <EmbeddingSearchResult>[];
    for (final shard in shardsToQuery) {
      final results = shard.search(
        queryVector: queryVector,
        k: k,  // full k per shard, not k*3
        entityTypeFilter: entityTypeFilter,
        // No category filter needed — shard IS the category
      );
      allResults.addAll(results);
    }

    // Apply distance cutoff
    allResults.removeWhere((r) => r.distance > distanceCutoff);

    // Global ranking by distance
    allResults.sort((a, b) => a.distance.compareTo(b.distance));

    return allResults;  // caller trims to k after deduplication
  }

  @override
  Future<void> replaceEntityEmbeddings({...}) async {
    final shard = await _getOrCreateShard(categoryId);
    shard.replaceEntityEmbeddings(...);
  }
}
```

#### Fan-Out Search Sequence

```mermaid
sequenceDiagram
    participant UI as JournalPageController
    participant VSR as VectorSearchRepository
    participant OER as OllamaEmbeddingRepo
    participant SES as ShardedEmbeddingStore
    participant SA as Shard A (Documents)
    participant SB as Shard B (Profiles)
    participant SC as Shard C (Recipes)

    UI->>VSR: searchRelatedTasks("deadline", k=20, {catA, catB})
    VSR->>OER: embed("deadline")
    OER-->>VSR: Float32List [0.12, -0.34, ...]

    VSR->>SES: search(queryVector, k=20, {catA, catB})

    Note over SES: Resolve shards: catA → Shard A, catB → Shard B<br/>Shard C excluded (not in categoryIds)

    par Fan-out (parallel)
        SES->>SA: search(queryVector, k=20)
        SA-->>SES: [R1(0.15), R2(0.18), ..., R20(0.65)]
    and
        SES->>SB: search(queryVector, k=20)
        SB-->>SES: [R1(0.25), R2(0.31), ..., R8(0.72)]
    end

    Note over SES: Merge: 28 total results<br/>Apply cutoff (> 0.8 dropped): 26 remain<br/>Sort globally by distance<br/>Return all 26 (caller deduplicates)

    SES-->>VSR: 26 EmbeddingSearchResults (ranked)

    Note over VSR: Deduplicate by entity/task<br/>Resolve to JournalEntities<br/>Trim to k=20

    VSR-->>UI: VectorSearchResult(entities: [...], elapsed: 142ms)
```

#### Embedding Write Routing

```mermaid
sequenceDiagram
    participant EP as EmbeddingProcessor
    participant SES as ShardedEmbeddingStore
    participant IDX as Entity→Shard Index
    participant OLD as Shard A (old category)
    participant NEW as Shard B (new category)

    EP->>SES: replaceEntityEmbeddings(entityId, categoryId=B, ...)

    SES->>IDX: lookup(entityId)
    IDX-->>SES: current shard = A (or null)

    alt Entity exists in different shard
        SES->>OLD: deleteEntityEmbeddings(entityId)
        OLD-->>SES: ✓ removed
    end

    SES->>NEW: replaceEntityEmbeddings(entityId, ...)
    NEW-->>SES: ✓ stored

    SES->>IDX: update(entityId → B)
```

**Key design decisions:**
- `ShardedEmbeddingStore` implements `EmbeddingStore` — no changes needed upstream
- Each shard is a full `ObjectBoxEmbeddingStore` with its own `RealObjectBoxOps`
- Shards are created lazily on first write (dynamic sharding)
- The `search()` method no longer needs `k * 3` oversampling since each shard is homogeneous
- Distance cutoff is applied *before* returning to `VectorSearchRepository`
- No category filter is passed to individual shards (the shard *is* the filter)

#### 1b. Shard lifecycle management

```dart
/// Opens or creates the shard for [categoryId].
Future<ObjectBoxEmbeddingStore> _getOrCreateShard(String categoryId) async {
  final key = categoryId.isEmpty ? _defaultShardKey : categoryId;
  if (_shards.containsKey(key)) return _shards[key]!;

  final dir = p.join(_basePath, key);
  await Directory(dir).create(recursive: true);
  final store = await openStore(
    directory: dir,
    macosApplicationGroup: _macosApplicationGroup,
  );
  final shard = ObjectBoxEmbeddingStore(RealObjectBoxOps(store));
  _shards[key] = shard;
  return shard;
}

/// Determines which shards to query.
List<ObjectBoxEmbeddingStore> _resolveShardsToQuery(Set<String>? categoryIds) {
  if (categoryIds == null || categoryIds.isEmpty) {
    // Query ALL open shards
    return _shards.values.toList();
  }
  return [
    for (final id in categoryIds)
      if (_shards.containsKey(id)) _shards[id]!,
  ];
}
```

#### 1c. Migration from single store

A one-time migration reads all entities from the old single store and distributes them to
per-category shards:

```mermaid
flowchart TD
    START["App Launch"] --> CHECK{"'.migrated'<br/>marker exists?"}

    CHECK -->|"Yes"| SKIP["Skip migration<br/>Open sharded stores"]
    CHECK -->|"No"| OPEN["Open old single store<br/>objectbox_embeddings/"]

    OPEN --> READ["Read ALL EmbeddingChunkEntities<br/>from old store"]
    READ --> GROUP["Group entities by categoryId<br/>Map<String, List<Entity>>"]

    GROUP --> LOOP["For each categoryId group"]
    LOOP --> CREATE["Create shard directory<br/>objectbox_embeddings/<categoryId>/"]
    CREATE --> OPENSH["Open new ObjectBox store<br/>for shard"]
    OPENSH --> PUT["putMany(entities)<br/>in write transaction"]
    PUT --> MORE{"More<br/>groups?"}
    MORE -->|"Yes"| LOOP
    MORE -->|"No"| UNCATEGORIZED{"Entities with<br/>empty categoryId?"}

    UNCATEGORIZED -->|"Yes"| DEFAULT["Create _default/ shard<br/>putMany(uncategorized)"]
    UNCATEGORIZED -->|"No"| MARKER

    DEFAULT --> MARKER["Write '.migrated' marker file"]
    MARKER --> CLOSE_OLD["Close old store<br/>(preserve data.mdb as backup)"]
    CLOSE_OLD --> DONE["Migration complete ✓"]

    style START fill:#74c0fc,stroke:#1c7ed6
    style DONE fill:#51cf66,stroke:#2b8a3e,color:#fff
    style SKIP fill:#e9ecef,stroke:#adb5bd
    style MARKER fill:#ffd43b,stroke:#f59f00
```

```dart
static Future<void> migrateFromSingleStore({
  required String documentsPath,
  required String? macosApplicationGroup,
}) async {
  final oldDir = p.join(documentsPath, 'objectbox_embeddings');
  final markerFile = File(p.join(oldDir, '.migrated'));
  if (markerFile.existsSync()) return;  // already migrated

  // 1. Open old store, read all entities
  // 2. Group by categoryId
  // 3. For each group, open/create shard, putMany
  // 4. Write marker file
  // 5. Close old store (optionally delete old data.mdb)
}
```

### Phase 2: Update Embedding Pipeline

**Goal:** Route new embeddings to the correct shard.

#### 2a. EmbeddingProcessor changes

The `EmbeddingProcessor.processEntity()` method already receives `categoryId` from the entity's
metadata. Currently it passes this as a field on `EmbeddingChunkEntity`. With sharding, the
`categoryId` determines *which shard* receives the embedding.

**Change:** `EmbeddingStore.replaceEntityEmbeddings()` already accepts `categoryId` — the
`ShardedEmbeddingStore` will use it to route to the correct shard. No changes needed in
`EmbeddingProcessor`.

#### 2b. Category changes (re-categorization)

When a user moves an entry from category A to category B:
1. Delete embeddings from shard A: `shardA.deleteEntityEmbeddings(entityId)`
2. Re-insert into shard B: `shardB.replaceEntityEmbeddings(...)`

```mermaid
stateDiagram-v2
    state "Entity in Shard A" as InA
    state "Entity in Shard B" as InB
    state "Entity Uncategorized" as InDef
    state "No Embedding" as None

    [*] --> None: entity created
    None --> InA: first embedding<br/>(categoryId = A)
    None --> InDef: first embedding<br/>(categoryId = '')

    InA --> InB: re-categorized A→B<br/>delete from A, insert into B
    InB --> InA: re-categorized B→A<br/>delete from B, insert into A
    InA --> InDef: category removed<br/>move to _default
    InDef --> InA: category assigned<br/>move from _default to A

    InA --> None: entity deleted<br/>deleteEntityEmbeddings()
    InB --> None: entity deleted
    InDef --> None: entity deleted
```

```mermaid
graph TD
    subgraph "Entity→Shard Index (in-memory Map)"
        direction LR
        E1["entity-uuid-1 → cat-A"]
        E2["entity-uuid-2 → cat-B"]
        E3["entity-uuid-3 → _default"]
        E4["entity-uuid-4 → cat-A"]
        E5["entity-uuid-5 → cat-C"]
    end

    subgraph "Startup: Rebuild Index"
        SCAN["Scan all shard directories"]
        SCAN --> ITER["For each shard: query all entityIds"]
        ITER --> BUILD["Populate Map<entityId, shardKey>"]
    end

    subgraph "Write Path: O(1) Lookup"
        WRITE["replaceEntityEmbeddings(entityId, newCategoryId)"]
        WRITE --> LOOKUP["index[entityId] → oldShard"]
        LOOKUP --> DIFF{"oldShard ≠<br/>newShard?"}
        DIFF -->|"Yes"| DELETE["oldShard.delete(entityId)"]
        DELETE --> INSERT["newShard.put(embeddings)"]
        INSERT --> UPDATE["index[entityId] = newShard"]
        DIFF -->|"No"| REPLACE["shard.replace(embeddings)<br/>(same shard, just update)"]
    end

    style BUILD fill:#74c0fc,stroke:#1c7ed6
    style UPDATE fill:#51cf66,stroke:#2b8a3e,color:#fff
```

This can be handled transparently in `ShardedEmbeddingStore.replaceEntityEmbeddings()`:
- Before inserting into the target shard, scan all other shards for the entity and remove it
- Or maintain a lightweight `entityId → shardKey` index (in-memory map or small SQLite table)

**Recommended approach:** Maintain an in-memory `Map<String, String>` (`entityId → shardKey`)
rebuilt on startup from a scan of all shards. This avoids cross-shard queries on every write.

#### 2c. Category creation/deletion

- **New category:** No immediate action — shard created lazily on first embedding write
- **Category deletion:** Close and optionally delete the shard directory. Embeddings for entries
  in deleted categories can be moved to the `_default` shard or simply discarded (entries will be
  re-embedded if the category is restored)

### Phase 3: Relevance Cutoff Integration

**Goal:** Filter out "trash results" using the threshold from Phase 0.

#### 3a. Cutoff strategy options

| Strategy | Description | Pros | Cons |
|----------|-------------|------|------|
| **Fixed threshold** | Drop results with distance > T | Simple, predictable | Doesn't adapt to query quality |
| **Relative threshold** | Drop results > N× best distance | Adapts to query | Can be too aggressive for weak queries |
| **Adaptive** | Use fixed T, but if no results pass, relax to 2× best | Best of both | More complex |
| **Per-shard** | Apply cutoff independently per shard | Fair across categories | May drop entire categories |

**Recommended:** **Adaptive per-shard cutoff.**

```mermaid
flowchart TD
    START["Shard returns k raw results<br/>sorted by distance (ascending)"]

    START --> BEST{"Best result<br/>distance?"}

    BEST -->|"< T (e.g., 0.7)"| GOOD["Strong query match in this shard"]
    BEST -->|"≥ T"| WEAK["Weak/no match in this shard"]

    GOOD --> APPLY_ABS["Apply absolute cutoff: T = 0.8<br/>Drop results with distance > T"]
    GOOD --> APPLY_REL["Apply relative cutoff:<br/>Drop results > best × multiplier (2.0×)"]
    APPLY_ABS --> INTERSECT["Keep results passing BOTH cutoffs"]
    APPLY_REL --> INTERSECT

    WEAK --> KEEP_MIN["Keep only minResultsPerShard (1)<br/>= best result only"]

    INTERSECT --> EMIT["Emit filtered results for this shard"]
    KEEP_MIN --> EMIT

    EMIT --> MERGE["→ Merge with other shards' results"]

    style GOOD fill:#51cf66,stroke:#2b8a3e,color:#fff
    style WEAK fill:#ffa94d,stroke:#e67700
    style INTERSECT fill:#74c0fc,stroke:#1c7ed6
    style KEEP_MIN fill:#ffd43b,stroke:#f59f00
```

```mermaid
graph TD
    subgraph "Example: 3 shards queried, k=20, T=0.8"
        direction TB

        subgraph "Shard: Documents"
            DA["20 results: dist 0.12 – 0.58<br/>All below T ✓<br/>→ Keep all 20"]
        end

        subgraph "Shard: Profiles"
            DB["8 results: dist 0.25 – 0.91<br/>6 below T, 2 above<br/>→ Keep 6"]
        end

        subgraph "Shard: Recipes"
            DC["20 results: dist 0.85 – 1.42<br/>All above T ✗<br/>→ Keep 1 (best only)"]
        end

        DA --> MERGE["Merge: 20 + 6 + 1 = 27 results"]
        DB --> MERGE
        DC --> MERGE
        MERGE --> SORT["Global sort by distance"]
        SORT --> FINAL["Trim to k=20<br/>Balanced representation across categories"]
    end

    style DA fill:#51cf66,stroke:#2b8a3e,color:#fff
    style DB fill:#ffd43b,stroke:#f59f00
    style DC fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style FINAL fill:#74c0fc,stroke:#1c7ed6,color:#fff
```

For each shard:
1. Fetch top k results
2. If best result distance < T (e.g., 0.7): keep results up to T
3. If best result distance >= T: keep only the best result (user likely has a weak query,
   but showing the single best match per category is still useful)

This prevents both trash flooding and empty-result scenarios.

#### 3b. Configuration

```dart
/// Distance cutoff configuration.
class DistanceCutoffConfig {
  const DistanceCutoffConfig({
    this.absoluteThreshold = 0.8,
    this.relativeMultiplier = 2.0,
    this.minResultsPerShard = 1,
  });

  /// Maximum cosine distance to accept.
  final double absoluteThreshold;

  /// Drop results > best_distance * relativeMultiplier.
  final double relativeMultiplier;

  /// Always keep at least this many results per shard
  /// (even if above threshold), to avoid empty shards.
  final int minResultsPerShard;
}
```

#### 3c. UI indicator

Add a visual relevance indicator to search results:
- Green dot: distance < 0.3 (strong match)
- Yellow dot: 0.3 ≤ distance < 0.6 (related)
- Orange dot: 0.6 ≤ distance < 0.8 (weak)
- Results above cutoff are not shown

### Phase 4: Backfill & Cleanup

**Goal:** Populate shards from existing data and remove legacy code.

1. **Backfill controller update**: `EmbeddingBackfillController.backfillCategories()` already
   iterates by category. With sharding, each category's embeddings naturally go to its own shard.
   No logic change needed — `ShardedEmbeddingStore` routes internally.

2. **Remove oversampling**: In `VectorSearchRepository._prepareSearch()`, change `k: k * 3` to
   just `k: k`. The fan-out architecture handles per-category coverage without oversampling.

3. **Remove category filter passthrough**: The `categoryIds` parameter in `EmbeddingStore.search()`
   is still used by `ShardedEmbeddingStore` to select *which shards to query*, but individual
   shards no longer need the `categoryIds` filter in their `nearestNeighborSearch()` call.

4. **Deprecate old store**: After successful migration on all devices, the old single-store
   directory can be cleaned up.

## Class Hierarchy & Dependency Graph

```mermaid
classDiagram
    class EmbeddingStore {
        <<abstract>>
        +getContentHash(entityId) FutureOr~String?~
        +hasEmbedding(entityId) FutureOr~bool~
        +count FutureOr~int~
        +replaceEntityEmbeddings(...) FutureOr~void~
        +deleteEntityEmbeddings(entityId) FutureOr~void~
        +search(queryVector, k, entityTypeFilter?, categoryIds?) FutureOr~List~
        +deleteAll() FutureOr~void~
        +close() FutureOr~void~
    }

    class ShardedEmbeddingStore {
        -_basePath: String
        -_macosAppGroup: String?
        -_shards: Map~String, ObjectBoxEmbeddingStore~
        -_entityIndex: Map~String, String~
        -_cutoffConfig: DistanceCutoffConfig
        +search(...) Future~List~EmbeddingSearchResult~~
        +replaceEntityEmbeddings(...) Future~void~
        +deleteEntityEmbeddings(entityId) Future~void~
        -_getOrCreateShard(categoryId) Future~ObjectBoxEmbeddingStore~
        -_resolveShardsToQuery(categoryIds?) List~ObjectBoxEmbeddingStore~
        -_applyCutoff(results) List~EmbeddingSearchResult~
        -_rebuildEntityIndex() Future~void~
        +migrateFromSingleStore(...)$ Future~void~
    }

    class ObjectBoxEmbeddingStore {
        -_ops: ObjectBoxOps
        +open(documentsPath)$ Future~ObjectBoxEmbeddingStore~
        +search(...) List~EmbeddingSearchResult~
        +replaceEntityEmbeddings(...) void
        +deleteEntityEmbeddings(entityId) void
    }

    class ObjectBoxOps {
        <<abstract>>
        +count() int
        +close() void
        +nearestNeighborSearch(...) List~EmbeddingSearchHit~
        +putMany(entities) void
        +removeMany(ids) void
        +runInWriteTransaction(action) void
    }

    class RealObjectBoxOps {
        -_store: Store
        -_box: Box~EmbeddingChunkEntity~
    }

    class DistanceCutoffConfig {
        +absoluteThreshold: double
        +relativeMultiplier: double
        +minResultsPerShard: int
    }

    class VectorSearchRepository {
        -_embeddingStore: EmbeddingStore
        -_embeddingRepository: OllamaEmbeddingRepository
        -_journalDb: JournalDb
        +searchRelatedTasks(query, k, categoryIds?) Future~VectorSearchResult~
        +searchRelatedEntries(query, k, categoryIds?) Future~VectorSearchResult~
    }

    class EmbeddingService {
        -_embeddingStore: EmbeddingStore
        +start() void
        +stop() Future~void~
    }

    EmbeddingStore <|.. ShardedEmbeddingStore : implements
    EmbeddingStore <|.. ObjectBoxEmbeddingStore : implements
    ShardedEmbeddingStore *-- "0..*" ObjectBoxEmbeddingStore : manages shards
    ShardedEmbeddingStore *-- DistanceCutoffConfig
    ObjectBoxEmbeddingStore --> ObjectBoxOps : delegates to
    ObjectBoxOps <|.. RealObjectBoxOps : implements
    VectorSearchRepository --> EmbeddingStore : uses
    EmbeddingService --> EmbeddingStore : uses

    note for ShardedEmbeddingStore "NEW — replaces ObjectBoxEmbeddingStore<br/>as the DI-registered EmbeddingStore"
```

## Shard Lifecycle State Machine

```mermaid
stateDiagram-v2
    state "Not Exists" as NE
    state "Directory Created" as DC
    state "Store Open (Active)" as OPEN
    state "Store Closed (Idle)" as IDLE
    state "Deleted" as DEL

    [*] --> NE

    NE --> DC: first write to this categoryId<br/>Directory.create(recursive: true)
    DC --> OPEN: openStore(directory)<br/>RealObjectBoxOps wraps Store

    OPEN --> OPEN: read / write operations<br/>search(), replaceEntityEmbeddings()
    OPEN --> IDLE: LRU eviction<br/>(optional, if shard count > cap)
    IDLE --> OPEN: next read/write<br/>re-open store

    OPEN --> DEL: category permanently deleted<br/>close store, delete directory
    IDLE --> DEL: category permanently deleted<br/>delete directory

    NE --> OPEN: migration: putMany()<br/>(from old single store)
```

## File Change Summary

| File | Change |
|------|--------|
| `lib/features/ai/database/sharded_embedding_store.dart` | **New** — core sharding logic |
| `lib/features/ai/database/sharded_embedding_store_loader.dart` | **New** — production store opener with migration |
| `lib/features/ai/database/objectbox_embedding_store.dart` | Minor — remove category filter from search (shard is the filter) |
| `lib/features/ai/database/embedding_store.dart` | Add `distanceCutoff` config, add distance to results |
| `lib/features/ai/repository/vector_search_repository.dart` | Remove `k * 3` oversampling, leverage cutoff |
| `lib/get_it.dart` | Register `ShardedEmbeddingStore` instead of `ObjectBoxEmbeddingStore` |
| `lib/features/ai/service/embedding_service.dart` | No changes (routes through `EmbeddingStore` interface) |
| `lib/features/ai/service/embedding_processor.dart` | No changes (already passes `categoryId`) |
| `test/features/ai/database/sharded_embedding_store_test.dart` | **New** — comprehensive tests |
| `test/features/ai/repository/vector_search_repository_test.dart` | Update for new search behavior |

## Testing Strategy

```mermaid
graph TD
    subgraph "Unit Tests (MockObjectBoxOps)"
        UT1["ShardedEmbeddingStore<br/>shard creation/routing"]
        UT2["Fan-out search<br/>across N mock shards"]
        UT3["Distance cutoff<br/>fixed / relative / adaptive"]
        UT4["Re-categorization<br/>entity moves between shards"]
        UT5["Entity→Shard index<br/>rebuild from scan"]
        UT6["Edge cases<br/>empty shards, missing categories"]
    end

    subgraph "Integration Tests (Real ObjectBox)"
        IT1["Migration: single → sharded<br/>verify data integrity"]
        IT2["End-to-end search<br/>VectorSearchRepository + ShardedStore"]
        IT3["Backfill pipeline<br/>writes to correct shards"]
        IT4["Concurrent shard access<br/>parallel reads/writes"]
    end

    subgraph "TestFlight Validation"
        TF1["Phase 0: distance logging<br/>calibrate threshold"]
        TF2["Search quality<br/>rare categories visible"]
        TF3["Performance<br/>latency comparison"]
        TF4["Memory / file handles<br/>with many categories"]
    end

    UT1 --> IT1
    UT2 --> IT2
    UT3 --> IT2
    UT4 --> IT3
    IT1 --> TF1
    IT2 --> TF2
    IT2 --> TF3

    style UT1 fill:#74c0fc,stroke:#1c7ed6
    style UT2 fill:#74c0fc,stroke:#1c7ed6
    style UT3 fill:#74c0fc,stroke:#1c7ed6
    style UT4 fill:#74c0fc,stroke:#1c7ed6
    style UT5 fill:#74c0fc,stroke:#1c7ed6
    style UT6 fill:#74c0fc,stroke:#1c7ed6
    style IT1 fill:#ffd43b,stroke:#f59f00
    style IT2 fill:#ffd43b,stroke:#f59f00
    style IT3 fill:#ffd43b,stroke:#f59f00
    style IT4 fill:#ffd43b,stroke:#f59f00
    style TF1 fill:#51cf66,stroke:#2b8a3e,color:#fff
    style TF2 fill:#51cf66,stroke:#2b8a3e,color:#fff
    style TF3 fill:#51cf66,stroke:#2b8a3e,color:#fff
    style TF4 fill:#51cf66,stroke:#2b8a3e,color:#fff
```

1. **Unit tests for `ShardedEmbeddingStore`:**
   - Create/open/close shards dynamically
   - Route writes to correct shard by `categoryId`
   - Fan-out search across multiple shards
   - Distance cutoff filtering (fixed, relative, adaptive)
   - Entity re-categorization (move between shards)
   - Empty shard handling
   - Default shard for uncategorized entries

2. **Integration tests:**
   - Migration from single store to sharded
   - End-to-end search through `VectorSearchRepository`
   - Backfill with sharded store

3. **Manual TestFlight validation:**
   - Phase 0: distance distribution logging
   - Verify search quality improvement with real data
   - Performance comparison (should be faster due to smaller indexes)

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Many open stores = file handle exhaustion | Cap at ~50 open shards; LRU eviction for idle shards |
| Migration data loss | Marker file prevents re-migration; old data preserved until explicit cleanup |
| macOS sandbox semaphore limits | All shards share same `macosApplicationGroup`; ObjectBox handles internally |
| Re-categorization race conditions | Shard write operations are transactional per-store; entity-level locking via embeddingKey uniqueness |
| ObjectBox model must match across all shards | All shards use same `EmbeddingChunkEntity` model — generated code is shared |

## Open Questions

1. **Shard granularity:** Should we shard by category only, or also by entity type? (Recommendation:
   category-only for now; entity type filtering within a shard is cheap with an indexed column.)

2. **Concurrent shard queries:** Should fan-out queries run in parallel (via `Future.wait`) or
   sequentially? Parallel is faster but uses more memory. (Recommendation: parallel — each HNSW
   query is fast and memory-mapped.)

3. **Shard cleanup policy:** When a category is deleted, should we immediately delete the shard
   directory or defer to a maintenance task? (Recommendation: defer — soft-delete categories can
   be restored.)

4. **Distance threshold tuning:** Should the cutoff be user-configurable (settings UI) or fixed
   in code? (Recommendation: start fixed in code, add settings UI later if needed.)
