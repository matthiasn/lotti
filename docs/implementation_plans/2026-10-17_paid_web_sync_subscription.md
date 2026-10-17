# Paid sync via web checkout (Paddle) — plan

**Status:** in progress — backend, signing, production stack and app flow land together
**Date:** 2026-10-17
**Supersedes:** the provider recommendation in
[2026-08-07_matrix_provisioning_platform.md §7](2026-08-07_matrix_provisioning_platform.md#7-payment-providers)
**Builds on:** [2026-08-29_phase_b_play_sync_subscription.md](2026-08-29_phase_b_play_sync_subscription.md)

Take the first payment with Paddle's hosted checkout, launched from the app.
The provisioning service in `services/matrix-provisioning-service` already
handles anonymous entitlements, escrowed bundles, Matrix suspension and
retention; what this plan adds is a Paddle webhook, Ed25519-signed bundles, a
production compose stack behind nginx, and a subscribe screen in the app.
Paddle's domain review — not code — is the critical path, so it starts first.

## 1. Payment provider: Paddle

Paddle (UK, merchant of record) is the only established merchant of record
verified to renew **PayPal subscriptions** as well as cards, Apple Pay and
Google Pay. It handles EU VAT, UK VAT and US sales tax, ships a hosted overlay
checkout, signed webhooks and a self-service customer portal, and the UK has an
EU GDPR adequacy decision.

**Correction to the August plan.** Stripe Managed Payments, recommended there,
does not support PayPal (cards, Apple/Google Pay, Link and some local methods
only), is US-hosted and puts `LINK.COM*` on statements.

| Provider | Base | Merchant of record | PayPal on subscriptions | Fees | Payout | Verdict |
|---|---|---|---|---|---|---|
| **Paddle** | UK (GDPR adequacy) | Yes | Yes | 5% + $0.50 all-in; custom pricing under $10 on request | Monthly, $100 threshold | **Pick** |
| Mollie | NL (EU) | No — you file OSS VAT | Yes, via a PayPal mandate (may need PayPal reference transactions enabled) | ~€0.25 + 1.2–2.8% card; own PayPal fees | Weekly or daily SEPA | Runner-up |
| Stripe direct + Stripe Tax | US/IE | No | Yes (EU accounts enable it) | ~1.5% + €0.25 + Billing 0.7% + Tax 0.5% | Daily | Fallback |
| Stripe Managed Payments | US/IE | Yes | **No** | 3.5% on top of processing | Days | Rejected |
| Lemon Squeezy | US (Stripe-owned) | Yes | Limited | 5% + $0.50 | Twice monthly | Rejected: being folded into Stripe |
| Polar / Creem / Dodo | US / EE / — | Yes | No / unconfirmed / paused | ~4–5% + $0.40–0.50 | Varies | Recheck later |
| Digistore24 | DE | Yes (reseller) | Yes (unverified) | 7.9% + €1 | Delayed, 10% reserve | Too expensive |
| Adyen, Unzer, FastSpring | NL / DE / US | No / No / Yes | Yes | Sales-led contracts | — | Onboarding too slow |

**Price:** €4.99/month and €49/year, annual shown first. Paddle's fixed $0.50
(~€0.46) takes about 14% of a monthly charge and about 6% of an annual one.

**Paddle's go-live checklist** (submit on day 0, build against the sandbox
meanwhile): a public HTTPS page with price and product description, Terms
naming Paddle as merchant of record, a refund policy and a privacy policy.
Domain review is usually automatic and 5–7 business days when manual.

## 2. Current state (before this change)

- **Sync** is Matrix: one end-to-end encrypted (Megolm), non-federated room per
  account; keys are shared only with directly verified devices (ADR 0045) and
  inbound events from unverified devices are dropped (ADR 0116). The homeserver
  sees ciphertext plus metadata.
- **Provisioning bundle** `SyncProvisioningBundle {v, kind, homeServer, user,
  password, roomId}` (`lib/classes/config.dart`), base64url JSON, schema v2.
  `provisioned` bundles rotate the password on import and emit a `handover`
  bundle for further devices. `decodeBundle` checked format only — **no
  signature**.
- **Backend** already has anonymous entitlements, purchase intents, AES-GCM
  bundle escrow released only after an in-room rotation proof, Synapse
  suspension, a claim reaper, a reconciler, and the 30-day retention sweep —
  all wired to Google Play and off by default (`ENABLE_PLAY_SUBSCRIPTIONS`).
- **Missing:** any web payment provider, bundle signatures, app calls to the
  subscription routes, a production Synapse/nginx/compose configuration.

## 3. Backend design (Paddle adapter)

The paid machinery — `bundle_claims`, suspension, the reaper and the
reconciler — hangs off the subscription table through `token_fingerprint` and
`entitlement_state`. Rather than duplicate it, Paddle subscriptions are stored
in the same table with a new **`provider`** column (`google_play` | `paddle`):

- `token_fingerprint` = fingerprint of `paddle:<subscription id>`;
  `encrypted_purchase_token` holds the Paddle subscription and customer ids,
  sealed with the existing `SecretCipher`.
- Paddle status maps onto the Play state vocabulary already stored in
  `google_state` (`active`/`trialing` → ACTIVE, `active` with a scheduled
  cancel → CANCELED, `past_due` → IN_GRACE_PERIOD, `paused` → PAUSED,
  `canceled` → EXPIRED). `normalize_entitlement` then derives access exactly as
  for Play, so one state machine governs both.
- Access deadline = the billing period end plus a short delivery buffer while
  active, or the grace deadline while past due. A missed renewal webhook
  therefore fails closed at the deadline, and the reconciler refreshes Paddle
  rows from the Paddle API so missed webhooks self-heal.

Flow:

1. App creates an anonymous entitlement (existing route).
2. `POST /api/v1/client/web-checkout/sessions` (entitlement bearer auth, body:
   `entitlement_id`, `price_id`, `claim_secret`) stores the claim-secret hash
   and returns a one-time session id and the checkout URL.
3. The static checkout page opens Paddle.js with `customData.checkout_session_id`.
4. `POST /api/v1/webhooks/paddle` verifies `Paddle-Signature`
   (HMAC-SHA256 over `ts:rawBody`, constant-time, 5-minute window),
   deduplicates by event id, binds the first event to the session's entitlement
   and upserts the subscription row; later events resolve by subscription id.
   Out-of-order events are ignored by `occurred_at`.
5. The app polls `POST /api/v1/client/subscriptions/bundle-claims/deliver`; the
   first call that finds a granting Paddle subscription provisions the account
   and escrows the bundle (Play acknowledgement is skipped for Paddle rows).
6. The app imports, rotates, proves rotation in the room and calls
   `confirm-rotation` (existing).
7. `POST /api/v1/client/web-checkout/portal-sessions` returns a Paddle customer
   portal link for cancellation and payment-method changes.

Flags: `ENABLE_WEB_SUBSCRIPTIONS` gates the Paddle routes;
`ENABLE_PLAY_SUBSCRIPTIONS` keeps gating the Play routes; the shared
entitlement, deliver and confirm routes accept either.

## 4. Signed provisioning profiles

Bundle v3 wraps the v2 fields with an Ed25519 attestation:

```json
{"v":3,"kind":"provisioned","homeServer":"https://matrix.example","user":"@sync_ab12:matrix.example",
 "password":"…","roomId":"!x:matrix.example",
 "att":{"kid":"2026-10","iat":1792150000,"exp":1792236400,"sig":"<base64url Ed25519>"}}
```

- **Signed:** canonical JSON of `{exp, homeServer, iat, kid, roomId, user, v}`.
  The password is deliberately excluded so a `handover` bundle can carry the
  original attestation with the rotated password and still verify.
- **Client:** verifies against a compiled-in `kid → public key` list. For
  homeservers on the operator list a valid signature is mandatory, and an
  expired `provisioned` bundle is rejected; unsigned v2 bundles remain accepted
  for other homeservers so self-hosting keeps working.
- **What enforces payment** is the server: Synapse registration is closed and
  its admin API unreachable, so only paid provisioning creates accounts. The
  signature protects users from forged or phishing bundles.

## 5. Production stack

One Compose stack (`services/docker-compose.sync-prod.yml`) behind nginx:
Synapse + Postgres, the provisioning service, optionally the admin SPA bound to
`127.0.0.1`. nginx exposes only `/_matrix/client`, `/_matrix/media`,
`/.well-known/matrix/client`, `/api/v1/client/*`, `/api/v1/webhooks/paddle`
and the static site; `/_synapse/admin`, `/_matrix/federation` and every other
provisioning route return 404. Synapse: registration off, federation off,
retention on, `media_retention`, `delete_stale_devices_after`, presence and URL
previews off. Secrets are Docker secrets or a root-only env file.

## 6. Mailbox purging

30 days of history per sync room, at two layers (room `m.room.retention` +
Synapse purge jobs, and the service's daily `purge_all` of events and media),
plus Synapse `media_retention` and stale-device deletion. Accounts of lapsed
subscribers are suspended at the access deadline (existing) and erased
(`deactivate_user(erase=true)` after a room purge and media deletion) 30 days
later. Retention bounds how long a device may be offline and still catch up
from the room; beyond it, peer backfill repairs gaps.

## 7. Privacy

The operator never holds a key that decrypts memories. Paddle holds payment
identity as independent controller; the service stores only the Paddle
subscription and customer ids (encrypted), never name or email. Matrix
localparts are derived from the random entitlement id.

## 8. Decisions (defaults applied unless overridden)

- Provider: Paddle now; revisit Mollie above ~200 subscribers.
- Price: €4.99/month, €49/year, no free trial.
- Self-hosted homeservers keep the unsigned path.
- Web checkout off in Play and TestFlight builds (`LOTTI_WEB_CHECKOUT` define).
- Grace after a failed renewal: 7 days; erasure 30 days after suspension.
- Retention window: 30 days.
- **Open:** legal seller (person or GmbH), domains, storage cap.

## 9. Sources

- [Paddle pricing](https://www.paddle.com/pricing) ·
  [PayPal support](https://developer.paddle.com/concepts/payment-methods/paypal) ·
  [webhook signatures](https://developer.paddle.com/webhooks/signature-verification) ·
  [payouts](https://www.paddle.com/help/manage/get-paid/when-and-how-do-i-get-paid) ·
  [domain approval](https://www.paddle.com/help/start/account-verification/what-is-domain-approval)
- [Mollie recurring](https://docs.mollie.com/payments/recurring) ·
  [Mollie payouts](https://docs.mollie.com/docs/payouts)
- [Stripe Managed Payments](https://docs.stripe.com/payments/managed-payments) ·
  [Stripe PayPal subscriptions](https://docs.stripe.com/billing/subscriptions/paypal)
- [Lemon Squeezy PayPal subscriptions](https://docs.lemonsqueezy.com/help/orders/paypal-subscriptions)
- [Polar fees](https://polar.sh/docs/merchant-of-record/fees) ·
  [Creem payment methods](https://docs.creem.io/merchant-of-record/finance/payment-methods) ·
  [Dodo payment methods](https://docs.dodopayments.com/features/payment-methods)
