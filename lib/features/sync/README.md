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

#### 3. Matrix Room Management (`matrix/room.dart`)

Room creation, joining, and invitation handling:

- Creates encrypted private rooms
- Handles room invitations
- Manages room state
- **⚠️ Contains known bug in `listenToMatrixRoomInvites()` (see Known Issues)**

#### 4. Timeline Processing (`matrix/timeline.dart`)

Receives and processes incoming messages:

- Monitors timeline events
- Processes sync messages
- Handles file attachments
- Maintains read markers

#### 5. Send Message (`matrix/send_message.dart`)

Sends data to sync room:

- Text messages (base64-encoded sync messages)
- File attachments (audio, images, JSON)
- Tracks sent message counts

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
4. `processMatrixMessage()` deserializes and applies changes
5. Local database updated
6. Read marker updated

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

### Critical: Room Auto-Join Bug

**File:** `lib/features/sync/matrix/room.dart:111-146`

**Problem:**
The `listenToMatrixRoomInvites()` function listens to `client.onRoomState.stream` which fires for **ANY** room state change in **ANY** room, not just invite events. When `syncRoom?.id == null`, it automatically saves and joins the **first** room that emits a state event.

**Symptoms:**

- During simultaneous setup on multiple devices, each device may join different rooms
- One-way sync: Device A sends to Room X, Device B sends to Room Y
- Mobile shows "outbox empty" but desktop doesn't receive messages
- Devices appear configured but messages don't sync

**Example Scenario:**

1. Device A creates Room X, invites Device B
2. Device B's `onRoomState` fires for Room X
3. Before Device B joins Room X, another state event fires for Room Y (could be any room)
4. Device B auto-joins Room Y instead of Room X
5. Device A sends to Room X, Device B sends to Room Y → no sync

**Diagnostic Logging:**
Added comprehensive logging to detect this issue:

- Logs every `onRoomState` trigger with event type and room ID
- Logs warning when auto-join is about to occur
- Shows which room is being joined and why

**Temporary Workaround:**

1. Manually verify both devices are in the same room (use diagnostic info button)
2. If in different rooms, have both devices leave all rooms
3. Follow setup flow carefully with Device A creating room first
4. Device B manually enters specific room ID instead of relying on auto-join

**Proper Fix (TODO):**
Replace `listenToMatrixRoomInvites()` with proper invite handling:

- Listen to actual invite events specifically
- Verify room ID matches expected sync room
- Prompt user before auto-joining
- Add room validation/verification

### Major: syncRoom Not Loaded on Restart - FIXED ✅

**File:** `lib/features/sync/matrix/matrix_service.dart:96-167`

**Problem (FIXED):**
After login/restart, `syncRoom` was never loaded from the saved room ID. The `init()` method called
`connect()` then immediately called `listen()`, but `syncRoom` remained null. Timeline listeners
silently failed because they tried to call `syncRoom?.getTimeline()` on a null object.

**Symptoms:**
- "Works after the Nth restart" - classic race condition
- One-way sync after fresh restart
- No timeline events received even though outbox sends successfully
- Logs showed `Timeline is null` errors

**Root Cause:**
The Matrix client needs time after `connect()` to sync with the server and populate the `client.rooms`
list. Calling `listen()` immediately meant `getRoomById(savedRoomId)` returned null.

**Fix Applied:**
Added `_loadSyncRoom()` method that:
1. Runs after `connect()` but before `listen()`
2. Calls `client.sync()` to ensure rooms are loaded
3. Gets the Room object via `getRoomById(savedRoomId)`
4. Sets `syncRoom` and `syncRoomId`
5. Retries up to 3 times with exponential backoff (1s, 2s, 4s delays) if room not found
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

**File:** `lib/features/sync/matrix/room.dart:9-52`

**Problem:**
`joinMatrixRoom()` catches join errors, converts them to strings, and still sets `syncRoomId`. When a
join fails (for example, wrong room ID or revoked invite), the device believes it joined even though
Matrix rejected the request.

**Symptoms:**

- Devices report a room ID, but `syncRoom` is `null`
- Messages "send" but never reach the room because the client never joined
- Logs contain `MatrixService join error ...` followed by `'joined ...'`

**Workaround:**

1. Watch logs for join errors during setup
2. If an error occurs, manually remove the saved room ID (Settings → Matrix Sync → Delete config)
3. Recreate/invite using a confirmed room ID

**Proper Fix (TODO):**
Throw the join exception (or surface it in the UI) and avoid persisting the room ID on failure.

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

- `MATRIX_SERVICE` – Matrix client lifecycle, with `subDomain` values such as `init`, `listen`,
  `listenToMatrixRoomInvites`, `sendMatrixMsg`, `processNewTimelineEvents`, and `diagnostics`
- `OUTBOX` – Message queuing and delivery events from `OutboxService`

**Key Log Messages:**

- `⚠️ AUTO-JOINING room ...` – Critical warning that room auto-join occurred
- `onRoomState triggered ...` – Every room state event observed by the listener
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

1. **Fix room auto-join bug** - Replace with proper invite handling
2. **Add room validation** - Verify devices joined correct room
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
