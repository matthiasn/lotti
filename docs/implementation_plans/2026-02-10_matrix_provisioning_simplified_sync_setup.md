# Simplify Matrix Account Sync and Room Creation Flow

**Date:** 2026-02-10
**Status:** Planned
**Author:** Claude (with human direction)

## Decisions
- **QR payload:** Plain Base64 (no encryption) — password is already rotated before display
- **Mobile password rotation:** No — trust that desktop already rotated
- **Phasing:** Python CLI first → Desktop import/rotate/QR → Mobile scan
- **User identity format:** Full MXID (`@user:server`) everywhere — never bare localpart
- **Room marker:** CLI sets `m.lotti.sync_room` state event for discovery consistency
- **No feature flag:** New wizard is a second entry in sync settings alongside the old one. Old flow will be removed soon.

## Context

The current Matrix sync setup requires users to manually create accounts, log in on each device, create rooms, and invite other devices via QR-scanned user IDs. This flow is fragile — room creation requires admin rights on the server, and the invite-based multi-device handshake is error-prone. We need a "pre-provisioned" approach where an admin tool creates the account + room upfront, and devices simply ingest the credentials.

**This is a completely new onboarding flow.** The existing sync wizard (`matrix_settings_modal.dart`) and all its pages remain untouched. No page indices change, no existing tests break.

## Architecture Overview

```
┌─────────────────┐     Base64 string     ┌──────────────────┐
│  Python CLI      │ ──────────────────▸  │  Desktop Client   │
│  (Admin Tool)    │   (@user:server,     │  (NEW Wizard)      │
│                  │    password,          │                    │
│  Creates:        │    room_id,          │  1. Ingest string  │
│  - User account  │    homeserver)       │  2. Login          │
│  - Sync room     │                      │  3. Rotate password│
│  - Room marker   │                      │  4. Generate QR    │
└─────────────────┘                       │     with NEW creds │
                                          └────────┬───────────┘
                                                   │ QR code
                                                   ▼
                                          ┌──────────────────┐
                                          │  Mobile Client    │
                                          │  (NEW Wizard)      │
                                          │  Scan QR → auto   │
                                          │  configure sync   │
                                          └──────────────────┘
```

**Critical sequence:** Password rotation happens BEFORE the QR code is displayed. The QR code only ever contains the rotated password.

## Related Plans
- **FE implementation:** `2026-02-10_matrix_provisioning_fe_implementation.md`

---

## Python CLI Provisioning Tool

### Synapse Admin API Endpoints

| Step | Endpoint | Method | Auth |
|------|----------|--------|------|
| Admin login | `/_matrix/client/v3/login` | POST | admin user+pass |
| Create user | `/_synapse/admin/v2/users/<user_id>` | PUT | admin token |
| Login-as-user | `/_synapse/admin/v1/users/<user_id>/login` | POST | admin token |
| Create room (as user) | `/_matrix/client/v3/createRoom` | POST | user token |

**Key detail:** There is no "create room" in the Synapse Admin API. We use the admin "login-as-user" endpoint to get a short-lived token for the new user, then use the standard Client-Server APIs with that token.

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
       {"type": "m.room.encryption", "state_key": "", "content": {"algorithm": "m.megolm.v1.aes-sha2"}},
       {"type": "m.lotti.sync_room", "state_key": "", "content": {"version": 1}}
     ]
   }
   ```
   → obtain `room_id`. The `m.lotti.sync_room` state marker is set at creation time so room discovery (`sync_room_discovery.dart`) works consistently.
6. **Output provisioning bundle** → JSON → URL-safe Base64 (no padding):
   ```json
   {
     "v": 1,
     "homeServer": "https://matrix.example.com",
     "user": "@lotti_sync_user42:example.com",
     "password": "<generated>",
     "roomId": "!abcdef:example.com"
   }
   ```
   Note: `user` is always the full MXID (`@localpart:server`), never a bare localpart.

**Files to create:**
- `tools/matrix_provisioner/provision.py`
- `tools/matrix_provisioner/requirements.txt` — `httpx>=0.27`
- `tools/matrix_provisioner/README.md`

### Security Notes
- Admin password used transiently for token; never stored
- User's generated password included in output — intentional since desktop rotates it immediately
- Short-lived user token (10 min) for room creation expires quickly, not included in output

### Verification
1. Run provisioning script against dev Synapse server
2. Verify: user created, room created with `m.lotti.sync_room` marker, user is member
3. Verify: Base64 output decodes to valid JSON with full MXID
4. Verify: user can log in with generated password
