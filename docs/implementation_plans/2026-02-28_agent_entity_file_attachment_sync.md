# Fix: Agent Entities Use File-Attachment Pattern for Sync

## Context
Matrix SDK enforces 60KB on text events (`matrix_api_lite/generated/api.dart:4794`). `SyncAgentEntity` and `SyncAgentLink` serialize the entire payload inline in the text event — no file upload. Large `AgentDomainEntity` variants (e.g., `AgentMessagePayloadEntity.content`, `ChangeSetEntity.items`) can exceed this limit. Journal entities already solve this by uploading the JSON as a file attachment and sending only a thin descriptor as the text event.

## Approach
Follow the exact same pattern as `SyncJournalEntity`: upload payload as file, send thin descriptor as text event.

## Changes

### 1. Model: `lib/features/sync/model/sync_message.dart`
- Added `String? jsonPath` to `SyncAgentEntity` and `SyncAgentLink`
- Made `agentEntity` and `agentLink` nullable (for descriptor-only messages)
- Ran `make build_runner` to regenerate

### 2. File path helpers: `lib/utils/file_utils.dart`
- Added `relativeAgentEntityPath(entityId)` → `/agent_entities/<id>.json`
- Added `relativeAgentLinkPath(linkId)` → `/agent_links/<id>.json`

### 3. Send path: `lib/features/sync/matrix/matrix_message_sender.dart`
- Added `_sendAgentEntityPayload()` and `_sendAgentLinkPayload()` following `_sendJournalEntityPayload()`:
  - Read entity/link JSON bytes from disk
  - Upload via `_sendFile()` (reuses existing method)
  - Return descriptor-only message (jsonPath set, entity/link nulled)
- Wired into `sendMatrixMessage()` after entry link handling, before text event encoding

### 4. Outbox: `lib/features/sync/outbox/outbox_service.dart`
- Updated `_enqueueAgentEntity` and `_enqueueAgentLink`:
  - Save entity/link JSON to disk before enqueuing
  - Set `outboxEntryId` for merge/dedup (like journal entities)
  - Use `findPendingByEntryId` to merge updates to same entity
  - Set `jsonPath` on the enriched message stored in outbox

### 5. Receive path: `lib/features/sync/matrix/sync_event_processor.dart`
- Added `_resolveAgentEntity()` and `_resolveAgentLink()` helper methods
- Updated `SyncAgentEntity` and `SyncAgentLink` cases:
  - If `agentEntity`/`agentLink` is present (old inline format) → use directly (backward compat)
  - If `jsonPath` is present → load from file on disk (file was already downloaded by `AttachmentIngestor` via existing pipeline)
  - If neither → log and skip

### 6. Tests
- Updated existing tests for changed model (nullable fields)
- Added descriptor-only round-trip tests for both entity and link
- Added tests for outbox merge/dedup for agent entities and links
- Verified backward compatibility with inline entity/link messages

## Backward Compatibility
- Old messages with inline `agentEntity`/`agentLink` still deserialize (nullable `jsonPath` defaults to null)
- New descriptor-only messages: old devices without the update won't process them (graceful skip)
- File events use existing `relativePath` metadata → already indexed by `AttachmentIngestor` and `AttachmentIndex`

## Verification
- `make build_runner` after model changes ✓
- `fvm dart analyze` — zero warnings ✓
- `fvm dart format .` — all formatted ✓
- Targeted tests: 280 tests passing across 5 test files ✓
