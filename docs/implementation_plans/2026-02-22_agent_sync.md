# Agent State Cross-Device Sync — Implementation Plan

**Date**: 2026-02-22
**Status**: Complete

## Overview

Add cross-device synchronization for agent entities and links via the existing Matrix-based sync infrastructure. Follows the AiConfig sync pattern (simple enqueue + direct upsert).

**What syncs**: `agent_entities` and `agent_links` tables.
**What does NOT sync**: `wake_run_log` and `saga_log` (device-local operational data).

## Steps

### Step 1: SyncMessage Variants + Build Runner
- [x] Add `SyncAgentEntity` and `SyncAgentLink` variants to `SyncMessage`
- [x] Run `make build_runner`
- [x] Handle exhaustive switch compilation errors

### Step 2: Outbox Wiring (Sending Side)
- [x] Add `_enqueueAgentEntity` and `_enqueueAgentLink` helpers
- [x] Add switch cases in `enqueueMessage`

### Step 3: Inbox Wiring (Receiving Side)
- [x] Add `agentRepository` field to `SyncEventProcessor`
- [x] Add handler cases in `_handleMessage`
- [x] Inject `AgentRepository` in `get_it.dart`

### Step 4: Bulk Queries
- [x] Add `getAllAgentEntities` and `getAllAgentLinks` named queries to `.drift`
- [x] Add `getAllEntities()` and `getAllLinks()` to `AgentRepository`
- [x] Run `make build_runner`

### Step 5: AgentSyncService
- [x] Create `AgentSyncService` wrapper
- [x] Add Riverpod provider
- [x] Update `AgentService` to use `AgentSyncService`
- [x] Update `TaskAgentWorkflow` to use `AgentSyncService`

### Step 6: Maintenance Sync Steps
- [x] Extend `SyncStep` enum
- [x] Extend `SyncMaintenanceRepository`
- [x] Extend `SyncMaintenanceController`
- [x] Update Sync Modal UI
- [x] Add localization labels (all 5 languages)

### Step 7: Tests
- [x] Update mocks and fallbacks
- [x] Serialization round-trip tests (`sync_message_agent_test.dart`)
- [x] AgentSyncService tests (`agent_sync_service_test.dart`)
- [x] Inbox/SyncEventProcessor tests (12 new tests in existing file)
- [x] Existing test updates (sync_modal_test, sync_maintenance_repository_test)

### Final Verification
- [x] `make build_runner` succeeds
- [x] `make l10n` + `make sort_arb_files`
- [x] Analyzer: zero warnings
- [x] Formatter: all files formatted
- [x] All tests pass (1810 sync+agent tests green)

## Files Modified

| File | Change |
|------|--------|
| `lib/features/sync/model/sync_message.dart` | +2 variants |
| `lib/features/sync/outbox/outbox_service.dart` | +2 switch cases, +2 helpers |
| `lib/features/sync/matrix/sync_event_processor.dart` | +`agentRepository` field, +2 handler cases |
| `lib/features/sync/matrix/matrix_service.dart` | +2 sent type map entries |
| `lib/features/sync/ui/view_models/outbox_list_item_view_model.dart` | +2 payload kind labels |
| `lib/features/agents/database/agent_database.drift` | +2 named queries |
| `lib/features/agents/database/agent_repository.dart` | +`getAllEntities()`, +`getAllLinks()` |
| `lib/features/sync/models/sync_models.dart` | +2 enum values |
| `lib/features/sync/repository/sync_maintenance_repository.dart` | +`AgentRepository` dep, +2 operations |
| `lib/features/sync/state/sync_maintenance_controller.dart` | +2 steps |
| `lib/features/sync/ui/sync_modal.dart` | +2 steps, +2 label cases |
| `lib/l10n/app_*.arb` (5 files) | +4 labels each |
| `lib/get_it.dart` | Inject AgentRepository into SyncEventProcessor |
| `lib/features/agents/state/agent_providers.dart` | +agentSyncServiceProvider, update DB provider |
| `lib/features/agents/service/agent_service.dart` | Use AgentSyncService for writes |
| `lib/features/agents/workflow/task_agent_workflow.dart` | Use AgentSyncService for writes |
| **NEW** `lib/features/agents/sync/agent_sync_service.dart` | Sync-aware write wrapper |

## New Test Files

| File | Tests |
|------|-------|
| `test/features/sync/model/sync_message_agent_test.dart` | 14 tests: serialization round-trips for all entity/link variants, null vectorClock |
| `test/features/agents/sync/agent_sync_service_test.dart` | 20 tests: all write paths, fromSync flag, error paths, all entity/link variants |

## Updated Test Files

| File | Additions |
|------|-----------|
| `test/features/sync/matrix/sync_event_processor_test.dart` | 12 new tests: all entity variants, all link variants, null-repo skip, error propagation |
| `test/features/sync/ui/sync_modal_test.dart` | Updated for 9 sync steps (was 7), added agent stubs |
| `test/features/sync/repository/sync_maintenance_repository_test.dart` | Added MockAgentRepository dependency |
