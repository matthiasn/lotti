# Fix Sync Backfill & Optimize Inbox Filtering

**Date**: 2026-03-07
**Branch**: `feat/improve_agent_sync`
**Status**: Implementation in progress

## Problem Overview

Sync backfill is failing due to three bugs introduced when agent entities/links were added to vector clock tracking. The sequence log auto-population at startup only covers journal entries and entry links, leaving agent counters unrecorded. When backfill requests arrive for these counters, the originating device marks them as permanently "unresolvable" (2,778 entries). Additionally, there is no self-request guard in the backfill handler, creating a hot-loop risk. 50 requested entries remain stuck because no device can resolve them.

## Bug 1: Missing Agent Data in Sequence Log Population

### What's Wrong

The startup population function (`_checkAndPopulateSequenceLog` in `get_it.dart`) only populates from two sources: journal entries and entry links. When agent entities and agent links were added to the sync system with their own vector clock counters, the population function was never updated to include them.

```mermaid
flowchart TB
    subgraph "V1 Population (Current - Broken)"
        Start[App Startup] --> Check{Already populated?}
        Check -->|No| PopJournal[Populate from Journal Entries]
        PopJournal --> PopLinks[Populate from Entry Links]
        PopLinks --> Done[Mark as done]
        Check -->|Yes| Skip[Skip]

        style PopJournal fill:#90EE90
        style PopLinks fill:#90EE90
    end

    subgraph "Missing Sources"
        AgentEntities[Agent Entities ❌ NOT POPULATED]
        AgentLinks[Agent Links ❌ NOT POPULATED]
        style AgentEntities fill:#FFB6C1
        style AgentLinks fill:#FFB6C1
    end
```

### The Fix

```mermaid
flowchart TB
    subgraph "V2 Population (Fixed)"
        Start[App Startup] --> Check{V2 key set?}
        Check -->|No| PopJournal[Populate from Journal Entries]
        PopJournal --> PopLinks[Populate from Entry Links]
        PopLinks --> PopAgentEnt[Populate from Agent Entities ✅]
        PopAgentEnt --> PopAgentLinks[Populate from Agent Links ✅]
        PopAgentLinks --> Done["Mark V2 as done"]
        Check -->|Yes| Skip[Skip]

        style PopJournal fill:#90EE90
        style PopLinks fill:#90EE90
        style PopAgentEnt fill:#90EE90
        style PopAgentLinks fill:#90EE90
    end

    Note["Settings key bumped from<br/>maintenance_sequenceLogPopulated<br/>to maintenance_sequenceLogPopulatedV2<br/>so V1 devices re-run with full data"]
    style Note fill:#FFFACD
```

## Bug 2: Self-Request Hot Loop

### What's Wrong

When a device sends a backfill request via the Matrix room, the message echoes back to the sender after the `SentEventRegistry` TTL expires. Without a self-request guard, the device processes its own request, potentially generating more outbox traffic.

```mermaid
sequenceDiagram
    participant Device as Device A
    participant Matrix as Matrix Room
    participant Echo as Device A (echo)

    Device->>Matrix: BackfillRequest(requesterId=A, entries=[...])
    Note over Matrix: Message persisted in room
    Matrix-->>Echo: BackfillRequest echoed back
    Note over Echo: ⚠️ No self-check!
    Echo->>Echo: processBackfillEntry() for own entries
    Echo->>Matrix: Send responses/unresolvable for own counters
    Note over Echo: Creates unnecessary outbox traffic
```

### The Fix

```mermaid
sequenceDiagram
    participant Device as Device A
    participant Matrix as Matrix Room
    participant Echo as Device A (echo)

    Device->>Matrix: BackfillRequest(requesterId=A, entries=[...])
    Matrix-->>Echo: BackfillRequest echoed back
    Note over Echo: ✅ requesterId == myHost → skip
    Echo-->>Echo: Early return, log "skipping own request"
```

## Bug 3: Unresolvable Entries Stuck Permanently

### What's Wrong

Due to Bug 1 (missing agent population), when a device receives a backfill request for its own agent-related counters that aren't in the sequence log, it marks them as "unresolvable" (permanent). After repopulation fixes the sequence log, these entries remain stuck in unresolvable status.

```mermaid
stateDiagram-v2
    [*] --> missing: Gap detected
    missing --> requested: Backfill request sent
    requested --> backfilled: Response received + verified
    requested --> deleted: Payload purged
    requested --> unresolvable: Originator can't resolve

    unresolvable --> [*]: ❌ STUCK FOREVER

    note right of unresolvable
        2,778 entries stuck here
        because agent counters
        weren't in sequence log
        when request was processed
    end note
```

### The Fix

Add a manual "Reset Unresolvable" action (in sync diagnostics UI) that resets entries back to `missing` when they now have a known `entryId` (meaning repopulation found them).

```mermaid
stateDiagram-v2
    [*] --> missing: Gap detected
    missing --> requested: Backfill request sent
    requested --> backfilled: Response received + verified
    requested --> deleted: Payload purged
    requested --> unresolvable: Originator can't resolve

    unresolvable --> missing: ✅ Manual reset (entryId now known)

    note right of unresolvable
        After V2 repopulation,
        entries that now have entryId
        can be reset to missing
        and re-requested
    end note
```

## Optimization: Host Activity Cache

### What's Wrong

`recordReceivedEntry` performs O(hosts_in_VC) DB queries for `getHostLastSeen()` and `getLastCounterForHost()`. With 9 devices, that's ~18 DB roundtrips per incoming entry.

```mermaid
flowchart LR
    subgraph "Per Incoming Entry (9 hosts in VC)"
        Entry[Received Entry] --> H1[getHostLastSeen host1]
        H1 --> C1[getLastCounter host1]
        C1 --> H2[getHostLastSeen host2]
        H2 --> C2[getLastCounter host2]
        C2 --> Dots[... x7 more hosts]
        Dots --> H9[getHostLastSeen host9]
        H9 --> C9[getLastCounter host9]
    end

    Note["18 DB roundtrips per entry!"]
    style Note fill:#FFB6C1
```

### The Fix

```mermaid
flowchart LR
    subgraph "With Cache (5min TTL)"
        Entry[Received Entry] --> Cache{In cache?}
        Cache -->|Hit| Use[Use cached value]
        Cache -->|Miss| DB[Query DB]
        DB --> Store[Store in cache]
        Store --> Use
    end

    Invalidate[Cache auto-expires after 5min<br/>Also invalidated per-host after writes]
    style Invalidate fill:#FFFACD
```

## Complete Backfill Flow (After All Fixes)

```mermaid
sequenceDiagram
    participant A as Device A
    participant M as Matrix Room
    participant B as Device B

    Note over A: App startup — V2 population runs
    A->>A: Populate journal + links + agent entities + agent links

    Note over A: Gap detected during sync
    A->>M: BackfillRequest(requesterId=A, entries=[(hostB, 42), (hostB, 43)])

    Note over A: Echo arrives back
    M-->>A: BackfillRequest (own echo)
    A->>A: requesterId == myHost → SKIP ✅

    M-->>B: BackfillRequest
    B->>B: Look up (hostB, 42) in sequence log
    B->>M: Send entry + BackfillResponse(hint)

    M-->>A: Entry arrives via sync
    A->>A: recordReceivedEntry (with cache) ✅
    A->>A: Resolve pending hints → mark backfilled

    Note over A: User triggers "Reset Unresolvable" in UI
    A->>A: Reset 2,778 entries → missing (entryId now known)
    A->>M: New BackfillRequests for reset entries
```

## Files Modified

| File | Change |
|------|--------|
| `lib/get_it.dart` | Add agent entity/link population, bump settings key to V2 |
| `lib/features/sync/backfill/backfill_response_handler.dart` | Add self-request guard |
| `lib/database/sync_db.dart` | Add `resetUnresolvableWithKnownPayload()` |
| `lib/features/sync/sequence/sync_sequence_log_service.dart` | Add reset method + host activity cache |
| `lib/features/sync/ui/backfill_settings_page.dart` | Add "Reset Unresolvable" UI section |
| `lib/features/sync/state/backfill_stats_controller.dart` | Add reset action + isResetting state |
| `lib/l10n/app_*.arb` | Add labels for reset button |

## Verification

1. `make analyze` — zero warnings
2. `make test` — all sync tests pass
3. New tests for: self-request guard, unresolvable reset, host activity cache
4. Post-deploy: trigger "Reset Unresolvable" manually in sync diagnostics, then verify the unresolvable count drops
