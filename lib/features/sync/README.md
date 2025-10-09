# Sync Feature Documentation

## Overview

The sync feature enables end-to-end encrypted synchronization of journal entries, tags, and other
data across multiple devices using Matrix protocol. It leverages Matrix's encryption capabilities
and room-based messaging to ensure secure, private data transmission between devices.

## Architecture

### Core Components

#### 1. MatrixService (`matrix/matrix_service.dart`)

Central service managing all Matrix client operations:

- Client initialization and authentication
- Device key verification
- Room management
- Message sending/receiving
- Connection state monitoring

#### 2. Outbox Service (`outbox/outbox_service.dart`)

Handles reliable message delivery:

- Queues messages for transmission
- Retries failed sends with staged 5s/15s delays
- Tracks message status (pending, sent, error)
- Manages file attachments

#### 3. Sync Room Management (`matrix/sync_room_manager.dart`)

Handles sync-room persistence, invite filtering, and safe join/leave flows:

- Creates encrypted private rooms and persists their IDs
- Filters and validates room invitations via the gateway invite stream
- Emits `SyncRoomInvite` objects for explicit user confirmation before joining
- Hydrates cached rooms with retry/backoff logic and surfaces failures through logging
- ✅ Auto-join bug fixed in Milestone 6 by replacing the legacy room-state auto-join path

#### 4. Timeline Processing (`matrix/timeline.dart`)

Receives and processes incoming messages:

- Monitors timeline events
- Delegates sync payloads to `SyncEventProcessor`
- Handles file attachments
- Maintains read markers via `SyncReadMarkerService`

#### 5. Send Message (`matrix/send_message.dart`)

Sends data to sync room:

- Text messages (base64-encoded sync messages)
- File attachments (audio, images, JSON)
- Tracks sent message counts

### Provider Wiring

All sync-facing controllers and widgets now receive their collaborators through
Riverpod providers instead of `getIt`. The key providers live in
`lib/providers/service_providers.dart` and are overridden in `main.dart` and
tests. Reference `docs/architecture/sync_engine.md` for the up-to-date
dependency graph and data-flow diagram.

To prevent regressions, the custom lint rule `no_get_it_in_sync` (shipped via
`tool/lotti_custom_lint`) fails analysis if new sync code references `getIt`.

### Data Flow

#### Sending Data

1. Local change occurs (journal entry created/modified)
2. `OutboxService` enqueues `SyncMessage`
3. `OutboxService` calls `MatrixService.sendMatrixMsg()`
4. Message sent to Matrix room as encrypted event
5. Outbox item marked as sent

#### Receiving Data

1. Matrix room receives new event
2. `timeline.onNewEvent` callback fires
3. `processNewTimelineEvents()` processes events
4. `SyncEventProcessor` deserializes and applies changes using injected dependencies
5. Local database updated
6. Read marker updated

### `SyncEventProcessor`

`SyncEventProcessor` (see `matrix/sync_event_processor.dart`) is the dedicated component that decodes
incoming `SyncMessage`s and mutates persistence. It replaces the legacy `processMatrixMessage()`
implementation with a testable, dependency-injected service.

- **Dependencies:** `LoggingService`, `UpdateNotifications`, `AiConfigRepository`, and an optional
  `SyncJournalEntityLoader`. Production uses the default `FileSyncJournalEntityLoader` (which
  leverages `path.join`), while tests can supply an in-memory loader.
- **Responsibilities:** Decode the base64 payload, map it to a concrete `SyncMessage`, update the
  provided `JournalDb`, and notify listeners (e.g., vector-clock aware updates, outbox trunks).
- **Error handling:** Logs exceptions while allowing later events to continue processing.

> NOTE: `processMatrixMessage()` is now a thin wrapper around `SyncEventProcessor` and will be
> removed once all legacy call sites are migrated.

## Setup Flow

### Initial Setup (Single User, Multiple Devices)

1. **Device A (Primary)**
    - Settings → Matrix Sync
    - Login with Matrix credentials
    - Create new room
    - Display QR code with User ID

2. **Device B (Secondary)**
    - Settings → Matrix Sync
    - Login with its own Matrix credentials (one Matrix account per device)
    - Scan Device A's QR code (or manually enter Device A's user ID)
    - Device A invites Device B to the sync room
    - Device B accepts the invitation and joins that room

3. **Device Verification**
    - Both devices verify each other
    - Compare emoji sequences
    - Accept verification on both devices

4. **Sync Active**
    - Both devices now sync bidirectionally
    - Changes propagate within seconds

## Known Issues

### Resolved: Room Auto-Join Bug ✅

**Fixed in:** `lib/features/sync/matrix/sync_room_manager.dart`

Milestone 6 removes the legacy room-state listener behaviour that eagerly joined the first
room seen on `client.onRoomState`. The new `SyncRoomManager` listens to the gateway's filtered
invite stream, validates room IDs, and emits `SyncRoomInvite` objects that must be explicitly
accepted. The auto-join race is gone and the persisted room ID is only updated after a verified
join. Unit tests in `test/features/sync/matrix/room_test.dart` capture the regression scenario and
exercise declined invites, persistence caching, retry hydration, and failure logging.

### Resolved: Room Join Error Masking ✅

`SyncRoomManager.joinRoom` now propagates the underlying gateway exception without updating the
persistent room ID. Tests cover both the happy-path join and the thrown error case so the UI can
surface the failure instead of silently misreporting success.

### Current Status

- No open regressions are tracked for the refactored sync engine as of Milestone 10 completion.
- Memory profiling results and methodology are documented in
  `docs/architecture/sync_memory_audit.md`.
- Future issues should include failing tests and updated docs alongside fixes.
2. Calls `client.sync()` to ensure rooms are loaded
3. Gets the Room object via `getRoomById(savedRoomId)`
4. Sets `syncRoom` and `syncRoomId`
5. Retries up to 4 times with exponential backoff (1s, 2s, 4s delays) if room not found
6. Logs detailed diagnostics at each step

Added defensive checks in `listenToTimelineEvents()`:
- Returns early if `syncRoom` is null
- Logs warning with diagnostic information

**Status:** ✅ **FIXED** - Sync now works reliably on first restart

### Major: Listeners Not Attached After Fresh Login

**File:** `lib/features/sync/matrix/matrix_service.dart`

**Problem:**
`MatrixService.login()` only calls `matrixConnect()`. When a device logs in during the current app
session, no follow-up call to `listen()` happens, so the timeline and invite listeners never start.
Inbound events are ignored until the app restarts (when `init()` runs).

**Symptoms:**

- Outbox drains from the sending device, but the peer never receives updates
- Restarting the app suddenly shows all missing changes
- Logs show no `MATRIX_SERVICE` entry with `subDomain: 'listen'` after login

**Workaround:**

1. After logging in on a device, fully restart the app once to trigger `MatrixService.init()`
2. Confirm `listen()` ran by checking for the `subDomain: 'listen'` log entry or the diagnostic info
3. Keep the app running so the timeline listener stays attached

**Proper Fix (TODO):**
Call `listen()` (or subscribe to login state changes) inside `login()` once the client reaches
`LoginState.loggedIn`.

### Major: Room Join Error Masking

✅ **Resolved in Milestone 6.** `SyncRoomManager.joinRoom` no longer swallows failures and the room ID
is only persisted after a successful join. The updated tests assert that failed joins throw and that
the cached room ID remains untouched.

## Diagnostic Tools

### Diagnostic Info Button

**Location:** Settings → Matrix Sync → (After login on second page)

Shows:

- Device ID and name
- User ID
- Saved room ID (from settings database)
- Current sync room ID (in-memory)
- All joined rooms with details
- Login status

**Usage:**

1. Tap "Show Diagnostic Info" button
2. Review room IDs across devices
3. Verify both devices show same `savedRoomId` and `syncRoomId`
4. Check `joinedRooms` to see all rooms each device is in
5. Copy to clipboard for comparison

### Logging

Sync operations log through `LoggingService` with these domains:

- `MATRIX_SERVICE` – MatrixService lifecycle (`init`, `listen`, `diagnostics`, timeline processing)
- `SYNC_ROOM_MANAGER` – Invite filtering, hydration retries, join/leave actions
- `OUTBOX` – Message queuing and delivery events from `OutboxService`

**Key Log Messages:**

- `Received invite for room ...` – Filtered invite surfaced to the UI layer
- `Accepting invite to ...` – User-approved joins
- `Room ... not yet available, retrying ...` – Hydration backoff loop
- `Failed to resolve room ... after ... attempts` – Hydration exhaustion (device may still await invite)
- `Sending message - using roomId: ...` – Room used for outbound traffic
- `Received message from ... in room ...` – Room and sender for inbound events

## Testing

### Integration Tests

**File:** `integration_test/matrix_service_test.dart`

Comprehensive test covering:

- Room creation and joining
- Device verification with emoji comparison
- Bidirectional message sending (100 messages each direction)
- Message reception and persistence
- Encrypted communication

**Run via:** `./run_matrix_tests.sh`

### Manual Testing Checklist

1. ✅ Login on Device A
2. ✅ Create room on Device A
3. ✅ Login on Device B
4. ✅ Invite Device B from Device A
5. ✅ Join room on Device B
6. ✅ Verify devices (compare emojis)
7. ✅ Check diagnostic info on both devices
8. ✅ Verify both show same room IDs
9. ✅ Create journal entry on Device A
10. ✅ Verify appears on Device B
11. ✅ Create journal entry on Device B
12. ✅ Verify appears on Device A

## Configuration

### Matrix Config

Stored in secure storage:

- `homeServer` - Matrix homeserver URL
- `user` - Matrix user ID
- `password` - Matrix password (for UIA)

### Room ID Storage

Stored in settings database with key `MATRIX_ROOM`

### Feature Flag

`enableMatrixFlag` - Must be enabled for sync to operate

## Security

### Encryption

- All rooms use Matrix's end-to-end encryption
- Rooms created with `trustedPrivateChat` preset
- Device verification required before sending messages
- Unverified devices block message sending

### Data Format

- Sync messages are JSON serialized and base64 encoded
- Transmitted as encrypted Matrix events
- Attachments sent as encrypted files with metadata

## Troubleshooting

### One-Way Sync

**Symptoms:** Device A receives from B, but B doesn't receive from A

**Diagnosis:**

1. Check diagnostic info on both devices
2. Compare `savedRoomId` and `syncRoomId`
3. Look for `⚠️ AUTO-JOINING` in logs
4. Check `joinedRooms` - should be identical
5. Confirm `MATRIX_SERVICE` logs include a `subDomain: 'listen'` entry after login

**Fix:**

1. Leave all rooms on both devices
2. Clear room settings
3. Restart each app once immediately after login to ensure listeners attach
4. Start fresh with proper setup flow

### Messages Not Sending

**Check:**

- Outbox status (Settings → Advanced → Outbox Monitor)
- Unverified devices blocking sends
- Network connectivity
- `enableMatrixFlag` enabled
- Room ID properly saved

### Device Verification Fails

**Check:**

- Device accounts are correct (one Matrix account per device)
- Both devices are in the same room
- Network connectivity
- Emoji comparison done correctly

## Future Improvements

1. **Add architecture diagram** - Show how MatrixService delegates to SessionManager, SyncRoomManager, and MatrixTimelineListener
2. **Document invite confirmation flow** - Diagram gateway filtering → Stream emission → UI prompt → `acceptInvite()` join/persist
3. **Improve setup UX** - Guided wizard with validation steps
4. **Add sync health monitoring** - Dashboard showing sync status
5. **Support multiple sync rooms** - Different rooms for different data types
6. **Add conflict resolution** - Handle simultaneous edits gracefully
7. **Optimize bandwidth** - Delta sync instead of full objects
8. **Add sync pause/resume** - User control over when sync occurs

## References

- [Matrix Protocol](https://matrix.org/)
- [matrix-dart-sdk](https://pub.dev/packages/matrix)
- [End-to-End Encryption in Matrix](https://matrix.org/docs/guides/end-to-end-encryption-implementation-guide)
