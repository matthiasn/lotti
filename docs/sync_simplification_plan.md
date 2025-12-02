# Sync Pipeline Simplification Plan

**Date:** 2025-12-02
**Updated:** 2025-12-02
**Goal:** Remove unnecessary complexity from the sync pipeline while keeping the battle-tested core

## Revised Approach: Incremental Simplification

After reviewing recent commits (wake detection fix, media download fix) and the actual codebase metrics, the original plan to rewrite was overly aggressive. Instead, we'll surgically remove the components that exist only to handle lazy loading - since **all attachments must be downloaded for sync to work anyway**.

### Actual Codebase Metrics

| Component | Actual Lines | Plan Estimate |
|-----------|-------------|---------------|
| Pipeline total | 3,073 | ~1,500 |
| Pipeline tests | 11,420 | N/A |
| `MatrixStreamConsumer` | 1,601 | N/A |
| `AttachmentIndex` | 65 | ~80 |
| `DescriptorCatchUpManager` | 207 | ~120 |
| `SmartJournalEntityLoader` | ~250 (in sync_event_processor.dart) | ~150 |

## Components to REMOVE (Option A: Simplest)

| Component | Lines | Why Remove |
|-----------|-------|------------|
| `AttachmentIndex` | 65 | Not needed - files are eagerly downloaded to disk |
| `DescriptorCatchUpManager` | 207 | Only exists because of lazy loading dance |
| `SmartJournalEntityLoader` | ~250 | Replace with simple `FileSyncJournalEntityLoader` |

**Total removal: ~522 lines** (plus ~700 lines of related tests)

## Components to KEEP

| Component | Lines | Why Keep |
|-----------|-------|----------|
| `MatrixStreamConsumer` | ~1,400 (after cleanup) | Battle-tested, well-tested core |
| `AttachmentIngestor` | ~150 (simplified) | Already does eager download correctly |
| Wake detection | ~100 | Just fixed and tested - handles real complexity |
| Retry/Circuit breaker | 107 | Useful for transient failures |
| Metrics | 246 | Nice observability, low cost |
| Read marker | 104 | Essential for progress tracking |

## New Architecture

### Core Insight

Since `AttachmentIngestor` already downloads attachments eagerly to disk, we don't need:
- `AttachmentIndex` to map paths to events
- `DescriptorCatchUpManager` to rescan for missing descriptors
- `SmartJournalEntityLoader` to fetch from Matrix on-demand

Instead:
1. **Attachment arrives** → `AttachmentIngestor` downloads to disk immediately
2. **Sync payload arrives** → `FileSyncJournalEntityLoader` reads from disk
3. **File not found?** → Event processing fails, retry on next catch-up cycle

### Simplified Flow

```
Event arrives (ordered batch)
        │
        ▼
┌─────────────────────────────────────┐
│ First pass: Download all attachments│
│ (AttachmentIngestor - already works)│
└─────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────┐
│ Second pass: Process sync payloads  │
│ - Read JSON from disk (simple)      │
│ - If file missing, fail & retry     │
│   on next catch-up cycle            │
└─────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────┐
│ Advance read marker                 │
│ (only for successfully processed)   │
└─────────────────────────────────────┘
```

## Implementation Steps

### Step 1: Remove AttachmentIndex
- [x] Delete `lib/features/sync/matrix/pipeline/attachment_index.dart`
- [x] Delete `test/features/sync/matrix/pipeline/attachment_index_test.dart`
- [x] Remove references from `MatrixStreamConsumer`
- [x] Remove references from `AttachmentIngestor`
- [x] Remove from `get_it.dart`

### Step 2: Remove DescriptorCatchUpManager
- [x] Delete `lib/features/sync/matrix/pipeline/descriptor_catch_up_manager.dart`
- [x] Delete `test/features/sync/matrix/pipeline/descriptor_catch_up_manager_test.dart`
- [x] Remove references from `MatrixStreamConsumer`
- [x] Remove references from `AttachmentIngestor`

### Step 3: Simplify SyncEventProcessor
- [x] Remove `SmartJournalEntityLoader` class
- [x] Remove `DescriptorDownloader` class
- [x] Remove `VectorClockValidator` class (for descriptor fetching)
- [x] Update `SyncEventProcessor` to use `FileSyncJournalEntityLoader` directly
- [x] Update tests

### Step 4: Update Integration Points
- [x] Update `get_it.dart` registrations
- [x] Run analyzer, fix, format
- [x] Verify all tests pass

## Trade-offs

### Accepted Trade-off
When a sync payload event arrives before its corresponding attachment event (different batches), the sync payload processing will fail on first attempt. It will succeed on the next catch-up cycle after the attachment has been downloaded.

**Why this is acceptable:**
- Personal app, not high-frequency trading
- Catch-up cycles are cheap
- Simpler code is more maintainable
- Edge case (cross-batch out-of-order) is rare

### Preserved Benefits
- Eager attachment download (already working)
- Ordered batch processing (already working)
- Wake detection (recently fixed)
- Retry with circuit breaker (keeps transient failures manageable)
- Full test coverage for core consumer

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Sync payload fails when attachment in later batch | Low | Low | Retries on next catch-up |
| Regression in existing behavior | Low | Medium | Extensive existing test suite |
| Performance impact from extra catch-ups | Very Low | Low | Monitor; optimize if needed |

## Success Criteria

1. All existing tests pass (after updating for removed components)
2. Analyzer clean
3. ~500 lines of code removed
4. No functional regression in sync behavior
