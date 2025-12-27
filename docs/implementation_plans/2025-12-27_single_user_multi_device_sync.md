# Single-User Multi-Device Sync Implementation Plan

**Date:** 2025-12-27
**Status:** ✅ Implemented (Phase 1-2 complete, Phases 3-4 optional)
**Author:** Claude (with human direction)

## Executive Summary

This document outlines the implementation plan to refactor Lotti's sync system from requiring separate Matrix user accounts per device to supporting a **single user account across multiple devices**.

**Key Finding:** The current architecture already supports single-user multi-device sync at the core level. The vector clock host IDs are device-specific (UUID v4), not tied to Matrix user identity, and local read markers are stored per-device. The main changes required are **UX/flow modifications** rather than fundamental architectural changes.

## Background & Investigation Results

### Original Hypothesis
The original belief was that the "one user per device" model was implemented to manage "global read markers" stored on the server for specific user accounts.

### Investigation Findings

#### 1. Vector Clock Host IDs Are Device-Specific

The `hostId` used in vector clocks is a **UUID v4 generated per device installation**, completely independent of the Matrix user:

```dart
// lib/services/vector_clock_service.dart
Future<String> setNewHost() async {
  final host = uuid.v4();  // Device-specific UUID
  await getIt<SettingsDb>().saveSettingsItem(hostKey, host);
  await setNextAvailableCounter(0);
  _host = host;
  return host;
}
```

**Stored as:** `VC_HOST` in SettingsDb (device-local storage)

**Implication:** Gap detection, backfill, and sequence tracking already work correctly with device-specific hosts regardless of which Matrix user is used.

#### 2. Read Markers: Local vs Remote

| Marker Type | Storage | Scope | Used For |
|-------------|---------|-------|----------|
| **Local** | SettingsDb (`LAST_READ_MATRIX_EVENT_ID`, `LAST_READ_MATRIX_EVENT_TS`) | Device-specific | Pipeline catch-up, session resumption |
| **Remote** | Matrix server (`room.fullyRead`) | Per-user, per-room | Optimization only (prevents marker regression) |

**Critical Finding:** The sync pipeline uses the **LOCAL** read marker for catch-up, not the remote one:

```dart
// lib/features/sync/matrix/pipeline/matrix_stream_consumer.dart:186
_startupLastProcessedEventId = await getLastReadMatrixEventId(_settingsDb);
```

**Implication:** Multiple devices sharing the same Matrix user would NOT conflict on read markers. Each device tracks its own position locally. The shared remote marker is only used for an optimization guard.

#### 3. Matrix SDK Multi-Device Support

The Matrix SDK fully supports multiple devices per user:

- Each login creates a unique `deviceId` assigned by the server
- `deviceDisplayName` is auto-generated with timestamp and UUID suffix
- Key verification works identically (emoji SAS between devices)
- E2E encryption operates per-device with cross-device key verification

#### 4. Current Multi-Device Flow (Different Users)

1. Device A creates account, logs in, creates encrypted room, displays QR
2. Device B creates **different** account, scans QR/enters Device A's Matrix ID
3. Device A invites Device B to room
4. Device B accepts invite
5. Both devices verify via emoji SAS
6. Sync operates

#### 5. Why Multi-User Was Originally Used

No technical reason was found in the codebase that requires separate users. The most likely explanation is that the original design didn't consider the simpler single-user flow, or the invite-based discovery was the natural UX pattern when first implemented.

## Proposed Solution

### Single-User Multi-Device Flow

1. **Device A** (first device):
   - User logs in with Matrix credentials
   - Creates encrypted sync room
   - Normal operation

2. **Device B** (additional device):
   - User logs in with **same** Matrix credentials
   - System detects existing sync rooms (user is already a member)
   - User selects/confirms which room to use (or auto-select if only one)
   - Devices verify via emoji SAS for E2E encryption
   - Sync operates

### Key Differences from Current Flow

| Aspect | Current (Multi-User) | Proposed (Single-User) |
|--------|---------------------|------------------------|
| Account creation | New account per device | Same account on all devices |
| Room discovery | Via invite from other device | Via existing membership |
| UX complexity | Higher (QR scan, invite accept) | Lower (just log in) |
| Invite flow | Required | Not needed |

## Implementation Plan

### Phase 1: Room Discovery for Existing Members

**Goal:** Allow Device B to discover and select sync rooms when logged in as the same user.

#### 1.1 Add Room Discovery Service

Create a new service to discover existing sync-eligible rooms:

```dart
// lib/features/sync/matrix/sync_room_discovery.dart
class SyncRoomDiscoveryService {
  /// Returns list of rooms that appear to be Lotti sync rooms.
  /// Criteria: encrypted, private, this user is a member.
  Future<List<SyncRoomCandidate>> discoverSyncRooms();

  /// Checks if user is already a member of any sync-eligible rooms.
  Future<bool> hasExistingSyncRooms();
}
```

**Files to modify:**
- Create: `lib/features/sync/matrix/sync_room_discovery.dart`
- Update: `lib/features/sync/matrix.dart` (exports)

#### 1.2 Integrate Discovery into Room Manager

The discovery service is integrated into `SyncRoomManager` which provides it to the UI layer:

```dart
// lib/features/sync/matrix/sync_room_manager.dart
class SyncRoomManager {
  final SyncRoomDiscoveryService _discoveryService;

  /// Discovers existing sync rooms for the current user.
  Future<List<SyncRoomCandidate>> discoverSyncRooms() async {
    final client = await _matrixService.getClient();
    if (client == null) return [];
    return _discoveryService.discoverSyncRooms(client);
  }
}
```

**Files modified:**
- `lib/features/sync/matrix/sync_room_manager.dart` - Added discovery delegation
- `lib/get_it.dart` - Wire discovery service into room manager

### Phase 2: UI Flow Changes

**Goal:** Update the setup UI to handle both first-device and additional-device scenarios.

#### 2.1 Detect Setup Scenario

When user enters Matrix credentials:

1. **No existing rooms found:** First device setup (current flow)
2. **Existing rooms found:** Additional device setup (new flow)

#### 2.2 Room Discovery UI Components

The room discovery flow is implemented as a new page in the setup wizard modal:

```dart
// lib/features/sync/ui/widgets/room_discovery_widget.dart
class RoomDiscoveryWidget extends ConsumerStatefulWidget {
  final VoidCallback onRoomSelected;
  final VoidCallback onSkip;
  // Displays room cards with confidence indicators
  // Handles loading, error, and empty states
}

// lib/features/sync/ui/room_discovery_page.dart
SliverWoltModalSheetPage roomDiscoveryPage({...}) {
  // Integrates RoomDiscoveryWidget into the modal wizard
  // Uses responsive height based on screen size
}
```

**Files created:**
- `lib/features/sync/ui/widgets/room_discovery_widget.dart` - Room selection UI
- `lib/features/sync/ui/room_discovery_page.dart` - Modal page wrapper
- `lib/features/sync/state/room_discovery_provider.dart` - Riverpod state management

**Files modified:**
- `lib/features/sync/ui/matrix_settings_modal.dart` - Insert discovery page into wizard

#### 2.3 Smart Navigation

The setup wizard includes intelligent navigation:

- **Room discovery page** inserted after login, before room config
- **Smart back button** in room config: skips discovery when a room is already configured
- **Conditional discovery trigger**: Only runs discovery if state is initial (prevents redundant calls)

**Key implementation details:**
- `_RoomConfigActionBar` is a `ConsumerWidget` that watches room state
- Back navigation goes to page 1 (logged-in config) if room exists, page 2 (discovery) otherwise
- Discovery only triggers on `RoomDiscoveryInitial` state to avoid redundant network calls

### Phase 3: Verification Flow Adjustments

**Goal:** Ensure device verification works correctly for same-user multi-device.

The verification flow should work identically since it's device-to-device, not user-to-user. However, we should:

#### 3.1 Update Verification UI Labels

Adjust text to clarify "verify this device" rather than "verify this user":

```dart
// Before: "Verify @user:server.com"
// After: "Verify device: MacBook Pro 2025-12-27"
```

**Files to modify:**
- `lib/widgets/sync/matrix/verification_modal.dart`
- Related verification UI files

#### 3.2 Test Cross-Device Key Sharing

Verify that:
- E2E encryption keys are properly shared between devices of same user
- Room history is accessible after verification
- No "undecryptable messages" errors

### Phase 4: Remove Invite-Only Requirement (Optional)

**Goal:** Clean up invite-related code paths for the single-user scenario.

This phase is optional as the invite flow still works. However, for cleaner UX:

#### 4.1 Conditional Invite Logic

Make invite-related UI optional when same-user scenario is detected:

```dart
if (isSameUserSetup) {
  // Skip invite UI, go directly to room selection
} else {
  // Show existing invite flow for different-user setups
}
```

**Files to modify:**
- `lib/features/sync/matrix/sync_room_manager.dart`
- Related UI files

### Phase 5: Documentation & Migration

#### 5.1 Update User Documentation

- Rewrite sync setup guide for single-user model
- Add troubleshooting section for multi-device issues
- Update screenshots/videos

#### 5.2 Update README Files

- `lib/features/sync/README.md` - Update setup flow documentation
- This implementation plan document

#### 5.3 Migration Notes

Existing users with multi-user setups:
- **Continue working:** No breaking changes to existing setups
- **Optional migration:** Users can manually transition to single-user model
- **No automated migration:** Would require account credential changes

##### Manual Migration Path (Optional)

For users who want to transition from multi-user (device-specific accounts) to single-user (primary account on all devices):

1. **On the primary device:**
   - Note the Matrix account credentials (homeserver, username, password)
   - The existing sync room already contains all synced data

2. **On secondary devices:**
   - Log out of the device-specific Matrix account (Settings → Sync → Logout)
   - Log in with the primary account credentials
   - Room Discovery will find the existing sync room
   - Select the room to join it

3. **Data handling during migration:**
   - **Local data is preserved:** All journal entries on the device remain in the local database
   - **Sync state resets:** The device will perform a fresh catch-up from the sync room
   - **No data loss:** Entries already in the sync room will be deduplicated via vector clocks
   - **Unsynced entries:** Any entries not yet synced will sync once the new connection is established

4. **After migration:**
   - Device verification is required for E2E encryption keys
   - All devices share the same sync room and receive updates in real-time
   - The old device-specific Matrix accounts can be deactivated if desired

##### When NOT to Migrate

- **Different users:** If devices belong to different people, keep separate accounts
- **Working setup:** If current multi-device sync works, migration is optional
- **Limited time:** Migration requires re-verification on each device

## File Change Summary

### New Files
| File | Purpose |
|------|---------|
| `lib/features/sync/matrix/sync_room_discovery.dart` | Room discovery service with confidence scoring |
| `lib/features/sync/ui/room_discovery_page.dart` | Modal wizard page for discovery |
| `lib/features/sync/ui/widgets/room_discovery_widget.dart` | Room selection UI with cards |
| `lib/features/sync/state/room_discovery_provider.dart` | Riverpod state management |

### Modified Files
| File | Changes |
|------|---------|
| `lib/features/sync/matrix/sync_room_manager.dart` | Add discovery service integration, mark new rooms |
| `lib/features/sync/matrix.dart` | Export new service and models |
| `lib/features/sync/ui/matrix_settings_modal.dart` | Insert discovery page into wizard |
| `lib/features/sync/ui/room_config_page.dart` | Smart back navigation, invite error handling |
| `lib/get_it.dart` | Wire discovery service into room manager |
| `lib/l10n/app_*.arb` | Add localization strings (all 5 locales) |
| `lib/features/sync/README.md` | Document single-user flow |
| `CHANGELOG.md` | Version 0.9.775 entry |
| `flatpak/com.matthiasn.lotti.metainfo.xml` | Release notes |

### Test Files
| File | Purpose |
|------|---------|
| `test/features/sync/matrix/sync_room_discovery_test.dart` | Unit tests for discovery (28 tests) |
| `test/features/sync/state/room_discovery_provider_test.dart` | Provider state tests |
| `test/features/sync/ui/room_discovery_page_test.dart` | Page integration tests |
| `test/features/sync/ui/widgets/room_discovery_widget_test.dart` | Widget tests |
| `test/features/sync/ui/room_config_page_test.dart` | Updated with error handling tests |

## Risk Assessment

### Low Risk
- **Core sync logic:** No changes needed; already device-independent
- **Vector clocks:** Already use device-specific UUIDs
- **Local read markers:** Already device-specific

### Medium Risk
- **E2E encryption:** Requires testing that cross-device key sharing works
- **Room discovery:** Needs robust filtering to identify sync rooms

### Mitigations
1. Add comprehensive integration tests for single-user multi-device
2. Test with real Matrix homeserver (not just mocks)
3. Implement feature flag for gradual rollout

## Success Criteria

1. **Functional:**
   - Device B can log in with same credentials as Device A
   - Device B discovers and selects existing sync room
   - Sync operates correctly between devices
   - E2E encryption works without "undecryptable" errors

2. **UX:**
   - Setup flow is simpler (fewer steps)
   - Clear feedback during room discovery
   - Verification flow clearly indicates device identity

3. **Compatibility:**
   - Existing multi-user setups continue working
   - No data loss or sync interruption during upgrade

## Timeline Estimate

| Phase | Effort | Dependencies |
|-------|--------|--------------|
| Phase 1 (Room Discovery) | 2-3 days | None |
| Phase 2 (UI Flow) | 2-3 days | Phase 1 |
| Phase 3 (Verification) | 1 day | Phase 2 |
| Phase 4 (Cleanup) | 1 day | Phase 3 |
| Phase 5 (Docs) | 1 day | Phase 4 |
| Testing & Polish | 2-3 days | All phases |

**Total:** ~10-14 days of development effort

## Open Questions

1. **Room identification:** How to reliably identify Lotti sync rooms vs other Matrix rooms? Options:
   - Room name pattern matching (current: `yyyy-MM-dd_HH-mm-ss`)
   - Custom room state event
   - Specific room tag

2. **Multiple sync rooms:** Should we support multiple sync rooms per account (e.g., work/personal separation)?

3. **Cross-signing:** Should we implement Matrix cross-signing for smoother device verification?

## Conclusion

The investigation confirms that switching to a single-user multi-device sync model is **feasible and straightforward**. The core sync architecture already supports device-independent operation through device-specific vector clock host IDs and local read markers.

The main work is in the **UX layer**: adding room discovery, updating the setup flow, and potentially simplifying the invite process. The fundamental sync mechanisms require no changes.

This refactor will result in a significantly simpler and more intuitive user experience for setting up sync between devices.
