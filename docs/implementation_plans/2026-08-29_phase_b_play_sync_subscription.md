# Phase B — Google Play SYNC subscription provisioning

**Status:** plan only; blocked on Phase A acceptance
**Date:** 2026-08-29

## Existing service to extend

`services/matrix-provisioning-service` is already a FastAPI service backed by a
SQLite repository. `BundleService` provisions a Matrix account plus encrypted,
non-federated sync room through `services/shared/matrix`, stores only a bundle
fingerprint, and returns the live credential once. The service already has
background-task patterns (`RedemptionPoller`, `RetentionScheduler`), audit
events, admin/client API-key separation, and Synapse admin operations.

The Android application id is `com.matthiasn.lotti`. There is currently no Play
Billing client or user-account identity layer in the Flutter app.

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

1. queries the two base plans and launches the Play purchase flow;
2. sends `purchaseToken`, product id, package name, and a client-generated
   idempotency/claim secret to the provisioner over TLS;
3. never treats the local `PurchaseDetails` state as entitlement;
4. waits for the server to verify and provision, then imports the returned v2
   bundle through the existing `ProvisioningController`; and
5. completes the Play purchase only after the server confirms it has granted
   entitlement.

The app must not contain the service's current shared `API_KEYS` value. The
purchase token is a high-entropy proof presented only over TLS, and the server
must additionally validate it with Google. Add Play Integrity binding before
public launch if the endpoint is exposed without an authenticated Lotti account.

### Server verification

Add a `GooglePlayClient` service using Google service-account credentials and
the Android Publisher scope. For every client submission and RTDN:

1. call `purchases.subscriptionsv2.get` for `com.matthiasn.lotti` and the token;
2. require an allowed product/base-plan line item and a grantable subscription
   state (`ACTIVE` or `IN_GRACE_PERIOD`);
3. reject pending, paused, on-hold, expired, revoked, unknown-product, test (in
   production), and package-mismatch results;
4. verify `externalAccountIdentifiers` when the client supplied an obfuscated
   account/profile id;
5. follow `linkedPurchaseToken` on upgrades, downgrades, and re-signups so one
   entitlement cannot provision two Matrix accounts; and
6. acknowledge a new, verified token server-side after the entitlement and
   bundle claim are durably recorded. Renewals do not need acknowledgement.

Never trust RTDN state directly. Verify the Pub/Sub push JWT/audience, decode
the notification, then re-query `subscriptionsv2.get`; notifications are only a
signal that authoritative state may have changed.

## Reliable one-time bundle delivery

The current return-once bundle rule is unsafe for a paid network request: a
dropped response after provisioning would consume the purchase but lose the
credential. Keep the plaintext prohibition, but add short-lived encrypted
escrow for paid provisioning:

- The client generates a random claim secret and sends only its hash for the
  server record.
- Store the raw Play token encrypted with a KMS/envelope key and a separate
  SHA-256 token fingerprint for uniqueness/lookups.
- Store the generated bundle encrypted until the client confirms successful
  import/password rotation, with a strict TTL and audit trail.
- Idempotent retries with the same purchase token and claim proof return the
  same pending claim; they never create a second Matrix user.
- Delete escrow ciphertext immediately after rotation confirmation, or revoke
  an abandoned unrotated account after the claim TTL.

This requires replacing the currently unusable
`/client/bundles/{bundle_id}/rotated` address with a purchase/claim-scoped
rotation endpoint or adding the bundle id to a backward-compatible v3 bundle.

## Data model

Add repository migrations and models for:

### `play_subscriptions`

- token fingerprint (unique), encrypted token, package name
- product id, base plan id, latest order id (audit only, never the primary key)
- verified Play state and normalized entitlement state
- purchase/start time, current period end, grace deadline
- acknowledgement state/time
- linked/replaced token fingerprint
- provisioned `bundle_id` foreign key
- suspended/unsuspended timestamps
- last verified time, next reconciliation time, last error
- created/updated timestamps

### `bundle_claims`

- `bundle_id` (unique), claim-secret hash
- encrypted bundle ciphertext and KMS key metadata
- expires, first delivered, confirmed, and destroyed timestamps

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

- `ACTIVE`, including voluntary cancellation before period end: keep sync.
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
- `services/matrix-provisioning-service/src/services/provisioning_repository.py`
- `services/matrix-provisioning-service/src/services/bundle_service.py`
- new `google_play_client.py`, `subscription_service.py`,
  `subscription_reconciler.py`, and `bundle_claim_service.py`
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
- Least-privilege Google Play and Synapse service accounts.
- Constant-time claim-secret verification and encryption key separation.
- Metrics/alerts for verification failures, unacknowledged purchases nearing
  Google's three-day refund deadline, RTDN lag, reconciliation drift, escrow
  age, and failed suspend/unsuspend operations.
- Backups and tested restore for subscription/audit data; encrypted token and
  bundle fields excluded from ordinary support exports.

## Testing

- Pure state-table tests for every Play state, cancellation, grace boundary,
  recovery, linked tokens, out-of-order/duplicate RTDN, and exact UTC deadlines.
- Mocked Android Publisher tests for verification, acknowledgement, retryable
  errors, invalid product/package, and token replay.
- Repository migration/transaction/concurrency tests with unique-token races.
- Route tests for Pub/Sub JWT failures, malformed notifications, idempotent
  purchase submission, lost-response retry, and claim authorization.
- Bundle lifecycle tests proving a network retry provisions exactly one account
  and confirmed rotation destroys escrow.
- Synapse integration tests proving suspend blocks sync sends and unsuspend
  restores them without replacing devices/room membership.
- Google Play license-tester scenarios for initial purchase, pending payment,
  renewal, cancellation, three-day grace, account hold, expiry, refund/revoke,
  upgrade/downgrade, reinstall, and RTDN redelivery.

No Phase B code should be merged until Phase A's macOS/Linux camera acceptance
is complete.
