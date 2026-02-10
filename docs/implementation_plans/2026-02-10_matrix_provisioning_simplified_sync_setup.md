# Simplify Matrix Account Sync and Room Creation Flow

**Date:** 2026-02-10
**Status:** Planned
**Author:** Claude (with human direction)

## Decisions
- **QR payload:** Plain Base64 (no encryption) — password is already rotated before display
- **Mobile password rotation:** No — trust that desktop already rotated
- **Phasing:** Python CLI first → Desktop import/rotate/QR → Mobile scan

## Implementation Phases
- **Phase 1:** Python CLI provisioning tool (standalone, testable against dev server)
- **Phase 2:** Desktop client — bundle import, password rotation, QR generation
- **Phase 3:** Mobile client — scan provisioning QR, auto-configure

## Context

The current Matrix sync setup requires users to manually create accounts, log in on each device, create rooms, and invite other devices via QR-scanned user IDs. This flow is fragile — room creation requires admin rights on the server, and the invite-based multi-device handshake is error-prone. We need a "pre-provisioned" approach where an admin tool creates the account + room upfront, and devices simply ingest the credentials.

## Architecture Overview

```
┌─────────────────┐     Base64 string     ┌──────────────────┐
│  Python CLI      │ ──────────────────▸  │  Desktop Client   │
│  (Admin Tool)    │   (username,         │  (Setup Assistant) │
│                  │    password,          │                    │
│  Creates:        │    room_id,          │  1. Ingest string  │
│  - User account  │    homeserver)       │  2. Login          │
│  - Sync room     │                      │  3. Rotate password│
└─────────────────┘                       │  4. Generate QR    │
                                          │     with NEW creds │
                                          └────────┬───────────┘
                                                   │ QR code
                                                   ▼
                                          ┌──────────────────┐
                                          │  Mobile Client    │
                                          │  Scan QR → auto   │
                                          │  configure sync   │
                                          └──────────────────┘
```

**Critical sequence:** Password rotation happens BEFORE the QR code is displayed. The QR code only ever contains the rotated password — the original CLI-generated password is invalidated before anything is shown on screen.

---

## Part 1: Python CLI Provisioning Tool

### Synapse Admin API Endpoints

| Step | Endpoint | Method | Auth |
|------|----------|--------|------|
| Admin login | `/_matrix/client/v3/login` | POST | admin user+pass |
| Create user | `/_synapse/admin/v2/users/<user_id>` | PUT | admin token |
| Login-as-user | `/_synapse/admin/v1/users/<user_id>/login` | POST | admin token |
| Create room (as user) | `/_matrix/client/v3/createRoom` | POST | user token |

**Key detail:** There is no "create room" in the Synapse Admin API. We use the admin "login-as-user" endpoint (`/_synapse/admin/v1/users/<user_id>/login`) to get a short-lived token for the new user, then use the standard Client-Server `createRoom` API with that token.

### Implementation: `tools/matrix_provisioner/provision.py`

**Dependencies** (minimal): `httpx` (async HTTP), `argparse` (CLI), standard lib (`json`, `base64`, `secrets`).

**CLI interface:**
```
python provision.py \
  --homeserver https://matrix.example.com \
  --admin-user admin \
  --admin-password <secret> \
  --username lotti_sync_user42 \
  [--display-name "Lotti Sync"]
```

**Script steps:**
1. **Login as admin** → `POST /_matrix/client/v3/login` → obtain `admin_access_token`
2. **Generate random password** → `secrets.token_urlsafe(32)` (44 chars, cryptographically random)
3. **Create user** → `PUT /_synapse/admin/v2/users/@{username}:{server}` with `{"password": generated, "admin": false, "displayname": "Lotti Sync"}`
4. **Login as user** → `POST /_synapse/admin/v1/users/@{username}:{server}/login` with `{"valid_until_ms": <now + 10 minutes>}` → obtain short-lived `user_token`
5. **Create room as user** → `POST /_matrix/client/v3/createRoom` with:
   ```json
   {
     "visibility": "private",
     "name": "Lotti Sync",
     "preset": "trusted_private_chat",
     "creation_content": {"m.federate": false},
     "initial_state": [
       {"type": "m.room.encryption", "state_key": "", "content": {"algorithm": "m.megolm.v1.aes-sha2"}}
     ]
   }
   ```
6. **Output provisioning bundle** → JSON → URL-safe Base64 (no padding):
   ```json
   {
     "v": 1,
     "homeServer": "https://matrix.example.com",
     "user": "lotti_sync_user42",
     "password": "<generated>",
     "roomId": "!abcdef:example.com"
   }
   ```

**Files to create:**
- `tools/matrix_provisioner/provision.py`
- `tools/matrix_provisioner/requirements.txt` — `httpx>=0.27`
- `tools/matrix_provisioner/README.md`

### Security Notes
- Admin password used transiently for token; never stored
- User's generated password included in output — intentional since desktop rotates it immediately
- Short-lived user token (10 min) for room creation expires quickly, not included in output

---

## Part 2: Desktop Client — Ingest, Rotate, Generate QR

### New Data Model: `SyncProvisioningBundle`

**File:** `lib/classes/config.dart` (extend existing file alongside `MatrixConfig`)

```dart
@freezed
abstract class SyncProvisioningBundle with _$SyncProvisioningBundle {
  const factory SyncProvisioningBundle({
    required int v,
    required String homeServer,
    required String user,
    required String password,
    required String roomId,
  }) = _SyncProvisioningBundle;

  factory SyncProvisioningBundle.fromJson(Map<String, dynamic> json) =>
      _$SyncProvisioningBundleFromJson(json);
}
```

### Modified Wizard Flow

**Current:** Login → Logged-In Config → Room Discovery → Room Config

**New:** adds an alternative entry point before the Login page:

1. **Setup Method Page (NEW)** — Choose: "Manual Login" or "Import Provisioning Bundle"
2. If "Import": **Bundle Import Page (NEW)**
   - Text field to paste Base64 string (desktop)
   - QR scanner (mobile — reuses existing `mobile_scanner` infra from `room_config_page.dart`)
   - Decodes → validates → shows summary (homeserver, username, room)
   - "Configure" button proceeds
3. **Password Rotation + QR Generation** — automatic after import:
   - Login with provisioned credentials → reuse `MatrixService.setConfig()` + `login()`
   - Join the pre-created room → reuse `SyncRoomManager.joinRoom()`
   - Generate new random password (32 bytes, base64url)
   - Change password via `Client.changePassword()` (Matrix SDK, calls `POST /_matrix/client/v3/account/password`)
   - Update stored `MatrixConfig` with new password
   - Build new `SyncProvisioningBundle` with rotated password → encode to Base64
   - **Display QR code** (now contains only the rotated password)
4. Existing flow continues for manual-login users

### Key Files to Modify

| File | Change |
|------|--------|
| `lib/classes/config.dart` | Add `SyncProvisioningBundle` freezed class |
| `lib/features/sync/ui/setup_method_page.dart` | **NEW** — choice between manual login and bundle import |
| `lib/features/sync/ui/bundle_import_page.dart` | **NEW** — paste/scan Base64, decode, validate, show summary |
| `lib/features/sync/state/provisioning_controller.dart` | **NEW** — Riverpod controller: import, configure, rotate, generate QR |
| `lib/features/sync/matrix/matrix_service.dart` | Add `changePassword()` method |
| `lib/features/sync/gateway/matrix_sync_gateway.dart` | Add `changePassword()` to abstract interface |
| `lib/features/sync/gateway/matrix_sdk_gateway.dart` | Implement `changePassword()` via `_client.changePassword()` |
| `lib/features/sync/ui/matrix_logged_in_config_page.dart` | After provisioning flow: show bundle QR instead of userId QR |
| Wizard page assembly (WoltModalSheet pages) | Insert new pages at the beginning |
| `lib/l10n/app_*.arb` | Localization strings for new UI |

### Existing Code to Reuse

| What | Where |
|------|-------|
| `MatrixService.setConfig()` + `login()` | `lib/features/sync/matrix/matrix_service.dart` |
| `SyncRoomManager.joinRoom()` | `lib/features/sync/matrix/sync_room_manager.dart` |
| `MatrixConfig` model | `lib/classes/config.dart` |
| `SecureStorage` for credential persistence | `lib/features/sync/secure_storage.dart` |
| `QrImageView` widget | Already in `matrix_logged_in_config_page.dart` |
| `MobileScanner` + barcode handling | Already in `room_config_page.dart` |
| `LoginFormController.login()` pattern | `lib/features/sync/state/login_form_controller.dart` |

### Password Change Implementation

```dart
// In MatrixSdkGateway
Future<void> changePassword(String oldPassword, String newPassword) async {
  await _client.changePassword(newPassword, oldPassword: oldPassword);
}
```

### QR Code Format Detection

The QR code now encodes the full `SyncProvisioningBundle` as URL-safe Base64. For backward compatibility:
- Starts with `@` → legacy userId format (existing invite flow)
- Otherwise → Base64-decode as `SyncProvisioningBundle` JSON

---

## Part 3: Mobile Client — Scan and Configure

Modify `_handleBarcode()` in `lib/features/sync/ui/room_config_page.dart`:

1. Detect if scanned data is a Base64 provisioning bundle (not a `@userId`)
2. If bundle: decode → `ProvisioningController.configureFromBundle()` which:
   - Sets config (homeServer + user + password)
   - Logs in
   - Joins the room
   - Does NOT rotate password (desktop already did)
3. Auto-navigate to "configured" state

---

## Verification Plan

### Python CLI Tool
1. Run provisioning script against dev Synapse server
2. Verify: user created, room created, user is member, Base64 output decodes to valid JSON

### Desktop Client
1. Paste Base64 string into import page
2. Verify: login succeeds, room is joined, password rotation completes
3. Verify: QR code displayed with updated credentials
4. Verify: old password no longer works

### Mobile Client
1. Scan QR from desktop
2. Verify: auto-configures with correct homeserver, user, room
3. Verify: sync messages flow between desktop and mobile

### Existing Flow Preservation
1. Manual login flow still works unchanged
2. Existing QR invite flow (userId format) still works
3. Run existing tests: `test/features/sync/`

### Automated Tests
- Unit: `SyncProvisioningBundle` serialization/deserialization roundtrip
- Unit: `ProvisioningController` (mock MatrixService) — import, rotate, generate
- Unit: Base64 encode/decode roundtrip
- Unit: barcode format detection (userId vs bundle)
- Widget: new wizard pages (setup method, bundle import)
