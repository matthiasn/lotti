# Phase B — Google Play SYNC subscription provisioning

**Status:** backend implemented; Android Billing client and production rollout pending
**Date:** 2026-08-29

## Existing service to extend

`services/matrix-provisioning-service` is already a FastAPI service backed by a
SQLite repository. `BundleService` provisions a Matrix account plus encrypted,
non-federated sync room through `services/shared/matrix`, stores only a bundle
fingerprint, and returns the live credential once. The service already has
background-task patterns (`RedemptionPoller`, `RetentionScheduler`), audit
events, admin/client API-key separation, and Synapse admin operations.

The Android application id is `com.matthiasn.lotti`. There is currently no Play
Billing client or user-account identity layer in the Flutter app. A stable
server-side entitlement identity is therefore a launch prerequisite, not
something a purchase token or claim secret may substitute.

The backend portion now lives in this service behind
`ENABLE_PLAY_SUBSCRIPTIONS=false`: stable anonymous entitlements, one-time
purchase intents, Play Integrity and Android Publisher verification, encrypted
token and bundle persistence, RTDN, reconciliation, reversible Matrix
suspension and abandoned-claim cleanup are implemented. The remaining Phase B
work is the Android Billing/Integrity client, production Play/Google/Synapse
configuration, and end-to-end license-tester validation; the feature flag must
remain off until those are complete.

## Purchase and provisioning flow

### Play Console

Create one subscription product (for example `lotti_sync`) with monthly and
annual auto-renewing base plans. Configure the displayed prices in Play Console
(approximately USD 4.99/month and 44.99/year); the backend validates product and
base-plan IDs, not a hard-coded currency amount. Configure the Play grace period
to exactly three days so Google and Lotti have one entitlement deadline rather
than two overlapping grace calculations.

Enable the Google Play Developer API, grant a least-privilege service account
access to the Lotti app, and connect Real-time Developer Notifications (RTDN) to
a dedicated Pub/Sub topic and authenticated push subscription.

### Android client

Add the Flutter `in_app_purchase` plugin behind a small sync-subscription
repository. The client:

1. creates an authenticated purchase intent bound to a stable Lotti account or
   server-issued entitlement identity before opening Play Billing;
2. attaches the server-derived obfuscated account/profile identifier to the
   Billing flow;
3. obtains a signed Play Integrity token whose `requestHash` covers a canonical
   serialization of the purchase-token fingerprint, product/base-plan,
   entitlement id, purchase-intent id, and claim-secret hash;
4. sends the signed Play Integrity token together with `purchaseToken`, product
   and base-plan ids, package name, entitlement id, purchase-intent id, and a
   client-generated delivery/claim secret over TLS;
5. never treats the local `PurchaseDetails` state as entitlement;
6. waits for the server to verify and provision, then imports the returned v2
   bundle through the existing `ProvisioningController`; and
7. completes the Play purchase only after the server confirms it has granted
   entitlement.

The app must not contain the service's current shared `API_KEYS` value. The
purchase token is a high-entropy proof presented only over TLS, and the server
must additionally validate it with Google. The claim secret authorizes delivery
retries only; it does not prove who owns the purchase. If Lotti still has no
authenticated account at launch, the provisioner must issue and retain a stable
entitlement identity plus one-time purchase intent, require its server-derived
obfuscated identifier in the Play purchase, and validate a Play Integrity
verdict bound to the exact submission through `requestHash` (or a server nonce
for the classic API). A public token-plus-claim-secret endpoint is not
acceptable.

### Server verification

Add a `GooglePlayClient` service using Google service-account credentials and
the Android Publisher scope.

For a client purchase submission:

1. verify the authenticated account and one-time purchase intent, decode and
   verify the submitted signed Play Integrity token, recompute the canonical
   request hash from the submitted fields, and require exact
   `requestHash`/nonce matching with replay controls;
2. call `purchases.subscriptionsv2.get` for `com.matthiasn.lotti` and the token;
3. require an allowed product/base-plan line item and a grantable state:
   `ACTIVE`, `IN_GRACE_PERIOD`, or `CANCELED` only while the authoritative
   line-item `expiryTime` is still in the future;
4. reject pending, paused, on-hold, expired, revoked, canceled-at-or-after-
   expiry, unknown-product, test (in production), and package-mismatch results;
5. require `externalAccountIdentifiers` to match the server-derived obfuscated
   identifier for the bound entitlement; a missing or mismatched binding cannot
   create or move an entitlement;
6. follow `linkedPurchaseToken` on upgrades, downgrades, and non-lapsed
   re-signups. For a post-expiry resubscription with no linked token, process
   `outOfAppPurchaseContext.expiredPurchaseToken` and expired external account
   identifiers when present, but still require the stable entitlement binding;
7. atomically attach the new token to that entitlement and mark every linked or
   replaced token non-grantable before any bundle can be provisioned; and
8. acknowledge a new, verified token server-side after the entitlement and
   bundle claim are durably recorded. Renewals do not need acknowledgement.

For RTDN, do not apply client-only account, purchase-intent, Play Integrity, or
claim-secret checks: `SubscriptionNotification` does not carry those proofs.
Instead, verify the Pub/Sub push JWT including issuer, audience, and service
account identity; decode the notification; resolve its `purchaseToken` through
the stored token-to-entitlement binding; and call
`purchases.subscriptionsv2.get` with that notification token before changing
state. An unknown token cannot create or rebind an entitlement. Never trust the
notification's state directly: RTDN is only a signal that authoritative Google
state may have changed.

## Reliable one-time bundle delivery

The current return-once bundle rule is unsafe for a paid network request: a
dropped response after provisioning would consume the purchase but lose the
credential. Keep the plaintext prohibition, but add short-lived encrypted
escrow for paid provisioning:

- The client generates a random claim secret and sends only its hash for the
  server record. This secret protects delivery, never purchase ownership.
- Store the raw Play token encrypted with a KMS/envelope key and a separate
  SHA-256 token fingerprint for uniqueness/lookups.
- Store the generated bundle encrypted until the server validates successful
  import/password rotation, with a strict TTL and audit trail.
- Idempotent retries with the same purchase token and claim proof return the
  same pending claim; they never create a second Matrix user.
- Once rotation is confirmed and escrow is destroyed, a linked replacement
  purchase returns an explicit recovery result with no bundle payload, then
  restores Matrix access before the verification response succeeds. Bootstrap
  credentials are never recreated for an established account.
- Do not trust a bare `bundle_id` rotation callback. After import, issue a
  one-time rotation challenge; require the bound Matrix user to publish it in
  the provisioned non-federated room and verify that the escrowed bootstrap
  password no longer authenticates before recording rotation.
- Delete escrow ciphertext only after that proof succeeds. A pre-import
  confirmation leaves escrow intact, repeated valid confirmations are
  idempotent, and an abandoned unrotated account is revoked after the claim TTL.

This requires replacing the currently unusable
`/client/bundles/{bundle_id}/rotated` address with a purchase/claim-scoped
rotation endpoint or adding the bundle id to a backward-compatible v3 bundle.

## Data model

Add repository migrations and models for:

### `play_subscriptions`

- stable entitlement id and server-derived obfuscated account/profile id
- token fingerprint (unique), encrypted token, package name
- product id, base plan id, latest order id (audit only, never the primary key)
- verified Play state and normalized entitlement state
- purchase/start time, current period end, grace deadline
- acknowledgement state/time
- linked/replaced token fingerprint
- out-of-app expired token fingerprint and binding-verification result
- provisioned `bundle_id` foreign key
- suspended/unsuspended timestamps
- last verified time, next reconciliation time, last error
- created/updated timestamps

### `bundle_claims`

- `bundle_id` (unique), claim-secret hash
- encrypted bundle ciphertext and KMS key metadata
- expires, first delivered, confirmed, and destroyed timestamps

### `purchase_intents`

- opaque intent id, stable entitlement id, one-time secret hash, requested
  product/base plan, expiry, consumed timestamp, and replay metadata
- expected Play Integrity request hash/nonce and the server-derived obfuscated
  account/profile identifier used to launch Billing

### Events

Extend `BundleEventType` (or add a subscription event table) for verified,
acknowledged, renewed, grace-entered, suspended, recovered, expired, revoked,
claim-delivered, and claim-destroyed transitions. Do not store tokens, bundle
plaintext, authorization headers, or Google credentials in event detail/logs.

SQLite remains acceptable only for the current single-instance deployment:
enable WAL, foreign keys, busy timeout, explicit transactions, and unique
constraints. A multi-replica/HA deployment must move the repository interface
to PostgreSQL before adding workers; local SQLite cannot coordinate duplicate
RTDN processing across hosts safely.

## Expiry and three-day grace

Normalize Google states into a small entitlement state machine:

```text
pending -> active -> grace -> suspended -> active
                    |          |
                    +--------> expired
active  -> canceled_active -> suspended/expired at entitlement end
```

- `ACTIVE`: keep sync.
- `CANCELED` with a future authoritative `expiryTime`: keep sync as
  `canceled_active`; suspend when that timestamp is reached. A canceled result
  whose `expiryTime` is already past loses entitlement immediately.
- `IN_GRACE_PERIOD`: keep sync through the Play-configured three-day deadline.
- `ON_HOLD`, `PAUSED`, `EXPIRED`, or revoked: remove entitlement immediately
  once the authoritative Google response says access is no longer valid.
- Recovery/renewal: restore entitlement idempotently.

Use RTDN for prompt transitions plus a periodic reconciliation worker for
missed/out-of-order notifications and deadline enforcement. Compare UTC
timestamps supplied by Google; never infer expiry from local receipt time.

## Enforcing sync access

Do **not** deactivate expired Matrix accounts: Synapse deactivation removes
devices, E2EE keys, tokens, room membership, and other account state, making a
normal subscription recovery destructive.

Extend `services/shared/matrix/admin_client.py` with reversible account
suspension and query methods. At entitlement loss, suspend the Matrix user;
Synapse then rejects message sends, joins, invites, and profile changes, which
stops Lotti's cross-device replication while preserving the account and room.
On renewal/recovery, unsuspend it. Record desired and observed suspension state
so retries converge after Synapse outages.

Before launch, verify the deployed Synapse version supports the suspension API
and add an end-to-end test showing that a suspended account cannot send a sync
event. If stronger read/login denial is required, use a Synapse authorization
module tied to the entitlement store; do not approximate it by password reset
or device deletion, both of which break recoverability.

## Service files

Expected additions/changes:

- `services/matrix-provisioning-service/src/core/models.py`
- `services/matrix-provisioning-service/src/core/constants.py`
- `services/matrix-provisioning-service/src/api/routes.py`
- `services/matrix-provisioning-service/src/services/subscription_repository.py`
- `services/matrix-provisioning-service/src/services/bundle_service.py`
- new `google_play_client.py`, `subscription_service.py`,
  `subscription_reconciler.py`, `paid_bundle_service.py`,
  `bundle_rotation_service.py`, and `bundle_claim_reaper.py`
- `services/matrix-provisioning-service/src/container.py`, `src/main.py`
- `services/shared/matrix/admin_client.py`
- dependency/configuration/Docker/README updates
- mirrored unit, route, repository, scheduler, and integration tests
- Flutter billing repository/controller/UI and localized catalog changes

## Security and operations

- Secret Manager/KMS-mounted Google credentials; never a JSON key in the image
  or repository. Rotate service and envelope keys.
- TLS only, strict request sizes, schema validation, rate limits, replay-safe
  idempotency, redacted structured logs, and no permissive CORS on client APIs.
- Authenticated Pub/Sub push with issuer/audience/email verification.
- Mandatory stable account/entitlement binding for purchase submission and
  restoration; Play Integrity `requestHash`/nonce validation must bind every
  security-relevant request field and reject replays.
- Least-privilege Google Play and Synapse service accounts.
- Constant-time claim-secret verification and encryption key separation.
- Metrics/alerts for verification failures, unacknowledged purchases nearing
  Google's three-day refund deadline, RTDN lag, reconciliation drift, escrow
  age, and failed suspend/unsuspend operations.
- Backups and tested restore for subscription/audit data; encrypted token and
  bundle fields excluded from ordinary support exports.

## Testing

- Pure state-table tests for every Play state, cancellation before and after
  `expiryTime`, grace boundary, recovery, linked tokens, out-of-order/duplicate
  RTDN, and exact UTC deadlines.
- Mocked Android Publisher tests for verification, acknowledgement, retryable
  errors, invalid product/package, and token replay.
- Repository migration/transaction/concurrency tests with unique-token races.
- Client-submission route tests for a missing/invalid signed Play Integrity
  token, server recomputation of the canonical request hash from every submitted
  field, mismatched hashes/nonces, idempotent submission, lost-response retry,
  claim authorization, stolen-token rebinding attempts, and replayed purchase
  intents.
- RTDN route tests for Pub/Sub JWT issuer/audience/service-account failures,
  malformed notifications, unknown token bindings, duplicate/out-of-order
  delivery, and proof that the notification token is re-queried through
  `purchases.subscriptionsv2.get` before a bound entitlement changes.
- Token-lineage tests for cancellation before expiry and post-expiry
  resubscription without `linkedPurchaseToken`, including
  `outOfAppPurchaseContext`, stable entitlement reuse, and atomic retirement of
  the replaced token.
- Bundle lifecycle tests proving a network retry provisions exactly one account
  and only server-validated rotation destroys escrow; cover pre-import and
  repeated rotation confirmations explicitly.
- Synapse integration tests proving suspend blocks sync sends and unsuspend
  restores them without replacing devices/room membership.
- Google Play license-tester scenarios for initial purchase, pending payment,
  renewal, cancellation, three-day grace, account hold, expiry, refund/revoke,
  upgrade/downgrade, reinstall, and RTDN redelivery.

No Phase B code should be merged until Phase A's macOS/Linux camera acceptance
is complete.

## Primary references

- Google Play Billing security and purchase attribution:
  <https://developer.android.com/google/play/billing/security>
- Subscription cancellation, expiry, and entitlement lifecycle:
  <https://developer.android.com/google/play/billing/lifecycle/subscriptions>
- `purchases.subscriptionsv2`, including external identifiers and
  `outOfAppPurchaseContext`:
  <https://developers.google.com/android-publisher/api-ref/rest/v3/purchases.subscriptionsv2>
- Play Integrity request content binding:
  <https://developer.android.com/google/play/integrity/standard>
