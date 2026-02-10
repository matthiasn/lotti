# Matrix Provisioning — Flutter FE Implementation

**Date:** 2026-02-10
**Status:** Planned
**Author:** Claude (with human direction)
**Parent plan:** `2026-02-10_matrix_provisioning_simplified_sync_setup.md`

## Context

The Python CLI provisioning tool outputs a Base64-encoded bundle containing `{homeServer, user (MXID), password, roomId}`. The Flutter client needs to:
- **Desktop:** Ingest this bundle → login → join room → rotate password → display QR with new creds
- **Mobile:** Scan QR → login → join room → done (no rotation)

This is a **completely new wizard** added to `sync_settings_page.dart` alongside the existing `MatrixSettingsCard`. No NEW feature flag — the existing `enableMatrixFlag` already gates the sync settings page via `SyncFeatureGate` (`lib/features/sync/ui/widgets/sync_feature_gate.dart:15`) and `settings_page.dart:97`. The old flow will be removed soon. No modifications to the existing wizard or its pages.

---

## Data Model

### `SyncProvisioningBundle` — add to `lib/classes/config.dart`

```dart
@freezed
abstract class SyncProvisioningBundle with _$SyncProvisioningBundle {
  const factory SyncProvisioningBundle({
    required int v,
    required String homeServer,
    required String user,       // Full MXID: @user:server
    required String password,
    required String roomId,     // !room:server
  }) = _SyncProvisioningBundle;

  factory SyncProvisioningBundle.fromJson(Map<String, dynamic> json) =>
      _$SyncProvisioningBundleFromJson(json);
}
```

After adding, run `make build_runner` to generate freezed/json code.

---

## Gateway Layer — `changePassword`

### `lib/features/sync/gateway/matrix_sync_gateway.dart` — add method

```dart
/// Changes the password for the currently logged-in user.
Future<void> changePassword({
  required String oldPassword,
  required String newPassword,
});
```

### `lib/features/sync/gateway/matrix_sdk_gateway.dart` — implement

```dart
@override
Future<void> changePassword({
  required String oldPassword,
  required String newPassword,
}) async {
  await _client.changePassword(newPassword, oldPassword: oldPassword);
}
```

### `lib/features/sync/matrix/matrix_service.dart` — expose

```dart
Future<void> changePassword({
  required String oldPassword,
  required String newPassword,
}) async {
  // Load config BEFORE the server call — if missing, the user isn't
  // configured and we must not change the password on the server without
  // being able to persist the new one locally.
  final config = await loadConfig();
  if (config == null) {
    throw StateError(
      'Cannot change password: no local Matrix configuration found.',
    );
  }

  // Persist the new password locally BEFORE the server call.
  // If the server call then fails, the client holds the new password but
  // the server still has the old one — recoverable by retrying with the
  // old password.  The reverse (server changed, local stale) would lock
  // the user out permanently.
  await setConfig(config.copyWith(password: newPassword));

  try {
    await _gateway.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  } catch (e) {
    // Server rejected the change — roll the local config back so the
    // client can still authenticate with the old (still-valid) password.
    await setConfig(config);
    rethrow;
  }
}
```

Note: `MatrixConfig` is freezed so `copyWith` is available (see `lib/classes/config.dart:7-16`).

**Atomicity rationale:** The local config is updated first so that a crash
between the two operations leaves the client with the new password while the
server still has the old one (recoverable by retrying).  If the server call
fails cleanly, the local config is rolled back immediately.  The reverse
order (server first, local second) risks permanent lock-out if the local
persist fails after the server has already accepted the new password.

---

## Provisioning Controller

### `lib/features/sync/state/provisioning_controller.dart`

Riverpod codegen controller (`@riverpod`). Uses `Ref ref` per project convention.

```dart
@freezed
sealed class ProvisioningState with _$ProvisioningState {
  const factory ProvisioningState.initial() = _Initial;
  const factory ProvisioningState.bundleDecoded(SyncProvisioningBundle bundle) = _BundleDecoded;
  const factory ProvisioningState.loggingIn() = _LoggingIn;
  const factory ProvisioningState.joiningRoom() = _JoiningRoom;
  const factory ProvisioningState.rotatingPassword() = _RotatingPassword;
  const factory ProvisioningState.ready(String handoverBase64) = _Ready;
  const factory ProvisioningState.done() = _Done;
  const factory ProvisioningState.error(String message) = _Error;
}

@riverpod
class ProvisioningController extends _$ProvisioningController {
  @override
  ProvisioningState build() => const ProvisioningState.initial();
}
```

**Methods:**

#### `decodeBundle(String base64String) → SyncProvisioningBundle`
1. Base64url decode (accept both padded and unpadded)
2. UTF-8 decode → JSON decode
3. `SyncProvisioningBundle.fromJson()`
4. Validate: `v == 1`, `user` starts with `@`, `roomId` starts with `!`, `homeServer` is valid URL
5. Update state to `bundleDecoded(bundle)`
6. Throws `FormatException` on invalid input

#### `configureFromBundle(SyncProvisioningBundle bundle, {bool rotatePassword = true})`
1. **Login:** state → `loggingIn()`, call `matrixService.setConfig(MatrixConfig(homeServer: bundle.homeServer, user: bundle.user, password: bundle.password))` then `matrixService.login()`. If login returns false → state `error('Login failed')`.
2. **Join room:** state → `joiningRoom()`, call `matrixService.joinRoom(bundle.roomId)`. (No separate `saveRoom` call needed — `joinRoom` already persists via `SyncRoomManager.joinRoom` at `sync_room_manager.dart:127`.)
3. If `!rotatePassword` → state `done()`, return null.
4. **Rotate password:** state → `rotatingPassword()`:
   - Generate new password: `Random.secure()` + base64url encode (32 bytes).
   - **Build the handover bundle immediately** (before the server call) so the new password is captured in `handoverBase64` even if the app crashes mid-rotation.
   - Call `matrixService.changePassword(oldPassword: bundle.password, newPassword: newPw)`. The service method persists the new password locally *before* calling the server (see atomicity rationale above). If the server call fails, the local config is rolled back and the error is surfaced.
5. **Handover ready:** State → `ready(handoverBase64)`. The QR/copyable text already contains the rotated password from step 4.

#### `reset()`
State → `initial()`. Called when user dismisses wizard or wants to re-import.

**Existing services accessed via ref:**
- `ref.read(matrixServiceProvider)` — from `lib/providers/service_providers.dart`

---

## Wizard UI — New Files

All under `lib/features/sync/ui/provisioned/`.

### A. `provisioned_sync_modal.dart` — Settings Card + Modal Assembly

**Settings card:** `ProvisionedSyncSettingsCard extends ConsumerStatefulWidget`

Follows pattern from `matrix_settings_modal.dart:41-143`:
- `ValueNotifier<int> pageIndexNotifier` initialized in `initState`
- If `matrixService.isLoggedIn()` and room is configured → start at page 2 (status)
- Otherwise start at page 0 (import)
- On tap: `ModalUtils.showMultiPageModal<void>(...)` with 3 pages

```dart
AnimatedModernSettingsCardWithIcon(
  title: context.messages.provisionedSyncTitle,
  subtitle: context.messages.provisionedSyncSubtitle,
  icon: Icons.qr_code_scanner,
  onTap: () { /* open modal */ },
)
```

**Page list:**
```dart
pageListBuilder: (modalContext) => [
  bundleImportPage(context: modalContext, pageIndexNotifier: pageIndexNotifier),      // 0
  provisionedConfigPage(context: modalContext, pageIndexNotifier: pageIndexNotifier), // 1
  provisionedStatusPage(context: modalContext, pageIndexNotifier: pageIndexNotifier), // 2
],
```

### B. `bundle_import_page.dart` — Page 0

**Desktop layout:**
- Title: localized "Import Sync Configuration"
- `TextField` for pasting Base64 string (single line, `maxLines: 1`)
- "Import" button (enabled when text non-empty)
- On import → `ref.read(provisioningControllerProvider.notifier).decodeBundle(text)`
- **On success:** Show summary card:
  - Homeserver: `bundle.homeServer`
  - User: `bundle.user`
  - Room: `bundle.roomId`
  - "Configure" button → navigates to page 1
- **On error:** Show inline error text (red, below text field)

**Mobile layout:**
- Same as desktop, PLUS "Scan QR Code" button that toggles `MobileScanner`
- Use `isMobile` from `lib/utils/platform.dart` to gate scanner visibility
- Follow scanner pattern from `room_config_page.dart:154-163`
- On scan → same decode flow as paste

**Sticky action bar:** Close button only (this is page 0, no back)

**Pattern reference:** `ModalUtils.modalSheetPage()` from `room_config_page.dart:20-32`

### C. `provisioned_config_page.dart` — Page 1

Watches `provisioningControllerProvider` state. Calls `configureFromBundle()` on entry.

**Desktop (rotatePassword: true):**
- Step-by-step progress with status text:
  - `loggingIn` → "Logging in..."
  - `joiningRoom` → "Joining sync room..."
  - `rotatingPassword` → "Securing account..."
  - `ready(base64)` → Show QR + copyable text
- QR display: `QrImageView(data: base64, size: 240)` inside white `Container` with `ClipRRect(borderRadius: 16)` — same as `matrix_logged_in_config_page.dart:113-125`
- Below QR: `SelectableText(base64)` for manual copy
- Label: "Scan this QR code on your mobile device"
- "Next" button → page 2

**Mobile (rotatePassword: false):**
- Steps loggingIn → joiningRoom → done
- Show checkmark + "Sync configured successfully"
- "Next" button → page 2

**Error state:** Show error message + "Retry" button (calls `configureFromBundle()` again)

**Sticky action bar:** Back (→ page 0) + Next (→ page 2, only enabled when ready/done)

### D. `provisioned_status_page.dart` — Page 2

- Show logged-in user MXID, room ID
- "Show Diagnostic Info" button — reuse `DiagnosticInfoButton` pattern from `matrix_logged_in_config_page.dart:150-198`
- "Disconnect" button → `matrixService.deleteConfig()`, `provisioningController.reset()`, navigate to page 0

**Sticky action bar:** Back (→ page 0) + Close

---

## Integration Point — `sync_settings_page.dart`

Add the new card directly after the existing `MatrixSettingsCard` (line 24). No additional flag gating (beyond existing `enableMatrixFlag` page gate):

```dart
// After line 24: const MatrixSettingsCard(),
const ProvisionedSyncSettingsCard(),
```

Import: `import 'package:lotti/features/sync/ui/provisioned/provisioned_sync_modal.dart';`

---

## Files NOT Modified

The existing onboarding flow is preserved exactly:
- `lib/features/sync/ui/matrix_settings_modal.dart` — wizard page list (indices 0–5)
- `lib/features/sync/ui/login/sync_login_form.dart` — login page
- `lib/features/sync/ui/matrix_logged_in_config_page.dart` — userId QR display
- `lib/features/sync/ui/room_config_page.dart` — invite scanner
- `lib/features/sync/ui/room_discovery_page.dart` — room discovery
- `lib/features/settings/ui/pages/settings_page.dart` — settings page layout
- All existing test files for these

---

## Existing Code Reuse Reference

| What | File | Method/Widget |
|------|------|---------------|
| Set config | `matrix_service.dart:670` | `setConfig(MatrixConfig config)` → `Future<void>` |
| Login | `matrix_service.dart:465` | `login()` → `Future<bool>` |
| Join room | `matrix_service.dart:469` | `joinRoom(String roomId)` → `Future<String?>` |
| Save room | `matrix_service.dart:474` | `saveRoom(String roomId)` → `Future<void>` |
| Load config | `matrix_service.dart:662` | `loadConfig()` → `Future<MatrixConfig?>` |
| Check login | `matrix_service.dart:476` | `isLoggedIn()` → `bool` |
| Delete config | `matrix_service.dart:666` | `deleteConfig()` → `Future<void>` |
| `MatrixConfig` | `config.dart:7-16` | `MatrixConfig({homeServer, user, password})` |
| QR display | `matrix_logged_in_config_page.dart:113-125` | `QrImageView(data:, size: 240)` |
| Scanner | `room_config_page.dart:154-163` | `MobileScanner(controller:, onDetect:)` |
| Modal assembly | `matrix_settings_modal.dart:106-134` | `ModalUtils.showMultiPageModal` |
| Modal page | `room_config_page.dart:20-32` | `ModalUtils.modalSheetPage()` |
| Platform check | `lib/utils/platform.dart` | `isMobile` |
| Service provider | `lib/providers/service_providers.dart` | `matrixServiceProvider` |

---

## Localization Keys

Add to all `app_*.arb` files (`app_en.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_ro.arb`):

- `provisionedSyncTitle` — "Provisioned Sync"
- `provisionedSyncSubtitle` — "Set up sync from a provisioning bundle"
- `provisionedSyncImportTitle` — "Import Sync Configuration"
- `provisionedSyncImportHint` — "Paste provisioning code here"
- `provisionedSyncImportButton` — "Import"
- `provisionedSyncScanButton` — "Scan QR Code"
- `provisionedSyncConfigureButton` — "Configure"
- `provisionedSyncInvalidBundle` — "Invalid provisioning code"
- `provisionedSyncLoggingIn` — "Logging in..."
- `provisionedSyncJoiningRoom` — "Joining sync room..."
- `provisionedSyncRotatingPassword` — "Securing account..."
- `provisionedSyncReady` — "Scan this QR code on your mobile device"
- `provisionedSyncDone` — "Sync configured successfully"
- `provisionedSyncError` — "Configuration failed"
- `provisionedSyncRetry` — "Retry"
- `provisionedSyncDisconnect` — "Disconnect"
- `provisionedSyncSummaryHomeserver` — "Homeserver"
- `provisionedSyncSummaryUser` — "User"
- `provisionedSyncSummaryRoom` — "Room"

---

## Tests

### Unit: `test/features/sync/state/provisioning_controller_test.dart`
- `decodeBundle`: valid Base64 → correct `SyncProvisioningBundle`
- `decodeBundle`: invalid Base64 → `FormatException`
- `decodeBundle`: valid Base64 but invalid JSON → `FormatException`
- `decodeBundle`: missing required fields → `FormatException`
- `decodeBundle`: user without `@` prefix → `FormatException`
- `configureFromBundle` desktop: mock MatrixService → state progression: loggingIn → joiningRoom → rotatingPassword → ready
- `configureFromBundle` mobile: mock MatrixService → state progression: loggingIn → joiningRoom → done
- `configureFromBundle` login failure: → state error
- `configureFromBundle` join failure: → state error
- `configureFromBundle` password change failure: → state error
- `reset()`: → state initial
- Base64 encode/decode roundtrip

### Widget: `test/features/sync/ui/provisioned/bundle_import_page_test.dart`
- Renders text field and import button
- Import button disabled when text empty
- Valid Base64 paste → shows summary card
- Invalid paste → shows error text
- Configure button visible after successful decode

### Widget: `test/features/sync/ui/provisioned/provisioned_config_page_test.dart`
- Desktop: shows progress steps → QR code when ready
- Mobile: shows progress steps → success when done
- Error state → shows retry button
- QR code renders correct data

### Widget: `test/features/sync/ui/provisioned/provisioned_sync_modal_test.dart`
- Settings card renders
- Tap opens modal
- Page navigation works (0 → 1 → 2)

---

## Verification

1. Analyzer green for entire project: `dart-mcp.analyze_files`
2. Formatter clean: `dart-mcp.dart_format`
3. All new tests pass: `dart-mcp.run_tests` on `test/features/sync/`
4. All existing sync tests still pass unchanged
5. Manual: paste valid Base64 → full flow completes → QR displayed
6. Manual: paste invalid Base64 → error shown inline
