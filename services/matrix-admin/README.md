# Lotti Matrix Admin

Admin UI for `matrix-provisioning-service`: provision Lotti sync accounts, hand
out one-time bundles, and track redemption and contribution status.

Kept separate from `services/dashboard` (credits + AI proxy) so the two deploy
independently. It runs on port **5174**; the dashboard keeps 5173.

## Pages

| Route | Purpose |
|---|---|
| `/bundles` | Roster of provisioned users, with inline payment-status editing |
| `/bundles/new` | Provision an account and reveal its bundle **once** |
| `/overview` | Sign-up and contribution stats |

## The one-time bundle

The bundle contains a live password and is never stored server-side. The reveal
screen says so, and requires an explicit "I have saved this bundle"
acknowledgement before it disappears — losing it means revoking the record and
provisioning a new account.

## Development

```bash
npm install --legacy-peer-deps   # matches services/dashboard's resolved versions
npm run dev                      # http://localhost:5174, proxies /api → :8003
npm test
npm run build
```

`--legacy-peer-deps` is needed because `@vitejs/plugin-react@4` does not declare
Vite 8 as a supported peer, the same combination `services/dashboard` ships.

## Configuration

| Variable | Default | Description |
|---|---|---|
| `VITE_ADMIN_API_KEY` | `dev-admin-key` | Admin key sent as a bearer token |

⚠️ **This key is embedded in the built JS bundle** and grants account
provisioning on your homeserver — the same tradeoff `services/dashboard` makes.
Put this app behind a reverse proxy with its own authentication, or replace it
with session-based auth, before it is reachable from an untrusted network.
