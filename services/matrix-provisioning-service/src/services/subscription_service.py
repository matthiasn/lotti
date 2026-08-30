"""Security-critical Google Play subscription verification transaction."""

from __future__ import annotations

import asyncio
from dataclasses import replace
from datetime import datetime, timedelta, timezone
from typing import Any, Callable

from ..core.exceptions import (
    EntitlementAuthenticationException,
    GooglePlayVerificationException,
    InvalidSubscriptionProductException,
    PurchaseIntentExpiredException,
    PurchaseIntentNotFoundException,
    PurchaseVerificationRateLimitException,
    UnknownPurchaseTokenException,
)
from ..core.subscriptions import (
    AcknowledgementState,
    GooglePlayLineItem,
    GooglePlaySnapshot,
    GoogleSubscriptionState,
    PurchaseSubmission,
    StoredSubscription,
    VerifiedPurchaseResult,
    VerifiedSubscription,
    normalize_entitlement,
)
from .google_play_client import GooglePlayClient
from .secret_cipher import SecretCipher
from .subscription_identity_service import SubscriptionIdentityService
from .subscription_repository import (
    ATTEMPT_KIND_PURCHASE_VERIFICATION,
    SubscriptionRepository,
)
from .subscription_security import (
    SecretHasher,
    canonical_purchase_request_hash,
    fingerprint,
)


class SubscriptionService:
    """Verifies a client purchase and atomically binds it to an entitlement."""

    def __init__(
        self,
        repository: SubscriptionRepository,
        identity_service: SubscriptionIdentityService,
        google_play_client: GooglePlayClient,
        secret_cipher: SecretCipher,
        *,
        package_name: str,
        allowed_products: dict[str, frozenset[str]],
        certificate_sha256_digests: frozenset[str],
        allow_test_purchases: bool = False,
        integrity_max_age: timedelta = timedelta(minutes=5),
        integrity_future_skew: timedelta = timedelta(seconds=30),
        reconciliation_interval: timedelta = timedelta(hours=6),
        purchase_verification_attempt_limit: int = 10,
        purchase_verification_attempt_window: timedelta = timedelta(minutes=15),
        secret_hasher: SecretHasher | None = None,
        now_provider: Callable[[], datetime] | None = None,
    ):
        if not certificate_sha256_digests:
            raise ValueError("At least one Play signing certificate digest is required")
        if purchase_verification_attempt_limit <= 0:
            raise ValueError("Purchase verification attempt limit must be positive")
        if purchase_verification_attempt_window <= timedelta(0):
            raise ValueError("Purchase verification attempt window must be positive")
        self._repository = repository
        self._identity_service = identity_service
        self._google_play_client = google_play_client
        self._secret_cipher = secret_cipher
        self._package_name = package_name
        self._allowed_products = allowed_products
        self._certificate_digests = certificate_sha256_digests
        self._allow_test_purchases = allow_test_purchases
        self._integrity_max_age = integrity_max_age
        self._integrity_future_skew = integrity_future_skew
        self._reconciliation_interval = reconciliation_interval
        self._purchase_verification_attempt_limit = purchase_verification_attempt_limit
        self._purchase_verification_attempt_window = purchase_verification_attempt_window
        self._secret_hasher = secret_hasher or SecretHasher()
        self._now_provider = now_provider or (lambda: datetime.now(timezone.utc))

    async def verify_purchase(
        self,
        submission: PurchaseSubmission,
        *,
        entitlement_auth_secret: str,
        now: datetime,
    ) -> VerifiedPurchaseResult:
        """Verify every proof before persisting a replay-safe token binding."""
        known_entitlement = await self._repository.get_entitlement(submission.entitlement_id)
        if known_entitlement is None or known_entitlement.disabled_at is not None:
            raise EntitlementAuthenticationException("Invalid entitlement credentials")
        retry_after = await self._repository.consume_subscription_attempt_quota(
            submission.entitlement_id,
            ATTEMPT_KIND_PURCHASE_VERIFICATION,
            now=now,
            window=self._purchase_verification_attempt_window,
            max_requests=self._purchase_verification_attempt_limit,
        )
        if retry_after is not None:
            raise PurchaseVerificationRateLimitException(retry_after_seconds=retry_after)
        entitlement = await self._identity_service.authenticate(
            submission.entitlement_id,
            entitlement_auth_secret,
        )
        self._validate_requested_product(submission)

        intent = await self._repository.get_purchase_intent(submission.purchase_intent_id)
        if intent is None or intent.entitlement_id != entitlement.entitlement_id:
            raise PurchaseIntentNotFoundException("Unknown purchase intent")
        if now >= intent.expires_at:
            raise PurchaseIntentExpiredException("Purchase intent has expired")
        intent_secret_valid = await asyncio.to_thread(
            self._secret_hasher.verify,
            submission.intent_secret,
            intent.intent_secret_hash,
        )
        if (
            intent.product_id != submission.product_id
            or intent.base_plan_id != submission.base_plan_id
            or intent.obfuscated_account_id != entitlement.obfuscated_account_id
            or not intent_secret_valid
        ):
            raise GooglePlayVerificationException(
                "Purchase intent does not match the submitted purchase"
            )

        request_hash = canonical_purchase_request_hash(
            package_name=submission.package_name,
            product_id=submission.product_id,
            base_plan_id=submission.base_plan_id,
            entitlement_id=submission.entitlement_id,
            purchase_intent_id=submission.purchase_intent_id,
            purchase_token=submission.purchase_token,
            intent_secret=submission.intent_secret,
            claim_secret=submission.claim_secret,
        )
        integrity_payload = await self._google_play_client.decode_integrity_token(
            submission.package_name,
            submission.integrity_token,
        )
        self._validate_integrity(
            integrity_payload,
            request_hash=request_hash,
            now=max(now, self._now_provider()),
        )

        google_snapshot = await self._google_play_client.get_subscription(
            submission.package_name,
            submission.purchase_token,
        )
        verified_at = max(now, self._now_provider())
        line_item = self._select_line_item(
            google_snapshot,
            product_id=submission.product_id,
            base_plan_id=submission.base_plan_id,
        )
        self._validate_account_binding(
            google_snapshot,
            expected=entitlement.obfuscated_account_id,
        )
        if google_snapshot.test_purchase and not self._allow_test_purchases:
            raise GooglePlayVerificationException("Test purchases are disabled in this environment")

        token_fingerprint = fingerprint(submission.purchase_token)
        integrity_fingerprint = fingerprint(submission.integrity_token)
        await self._repository.consume_purchase_intent(
            intent_id=intent.intent_id,
            entitlement_id=entitlement.entitlement_id,
            expected_request_hash=request_hash,
            token_fingerprint=token_fingerprint,
            integrity_token_fingerprint=integrity_fingerprint,
            now=verified_at,
        )

        encrypted_token = self._secret_cipher.encrypt(
            submission.purchase_token.encode(),
            purpose="purchase-token",
            record_id=token_fingerprint,
        )
        stored = await self._repository.store_verified_subscription(
            self._build_verified_subscription(
                snapshot=google_snapshot,
                line_item=line_item,
                entitlement_id=entitlement.entitlement_id,
                token_fingerprint=token_fingerprint,
                encrypted_purchase_token=encrypted_token,
                encryption_key_id=self._secret_cipher.key_id,
                package_name=submission.package_name,
                product_id=submission.product_id,
                base_plan_id=submission.base_plan_id,
                now=verified_at,
            ),
            now=verified_at,
        )
        return VerifiedPurchaseResult(
            subscription=stored,
            request_hash=request_hash,
            claim_secret_hash=await asyncio.to_thread(
                self._secret_hasher.hash,
                submission.claim_secret,
            ),
        )

    async def refresh_known_purchase(
        self,
        purchase_token: str,
        *,
        now: datetime,
    ) -> StoredSubscription:
        """Refresh an already-bound token for RTDN and reconciliation workers."""
        token_fingerprint = fingerprint(purchase_token)
        existing = await self._repository.get_subscription_by_token(token_fingerprint)
        if existing is None:
            raise UnknownPurchaseTokenException(
                "Notification purchase token is not bound to an entitlement"
            )
        entitlement = await self._repository.get_entitlement(existing.entitlement_id)
        if entitlement is None:
            raise GooglePlayVerificationException("Subscription entitlement is missing")

        snapshot = await self._google_play_client.get_subscription(
            existing.package_name,
            purchase_token,
        )
        verified_at = max(now, self._now_provider())
        line_item = self._select_line_item(
            snapshot,
            product_id=existing.product_id,
            base_plan_id=existing.base_plan_id,
        )
        self._validate_account_binding(
            snapshot,
            expected=entitlement.obfuscated_account_id,
        )
        if snapshot.test_purchase and not self._allow_test_purchases:
            raise GooglePlayVerificationException("Test purchases are disabled in this environment")
        acknowledged_at = (
            existing.acknowledged_at
            if snapshot.acknowledgement_state is AcknowledgementState.ACKNOWLEDGED
            else None
        )
        if (
            existing.is_current
            and existing.bundle_id is not None
            and snapshot.acknowledgement_state is AcknowledgementState.PENDING
        ):
            # Provisioning is already durable, so a worker may safely recover
            # an acknowledgement that failed after the original response.
            await self._google_play_client.acknowledge_subscription(
                existing.package_name,
                existing.product_id,
                purchase_token,
            )
            snapshot = replace(
                snapshot,
                acknowledgement_state=AcknowledgementState.ACKNOWLEDGED,
            )
            acknowledged_at = max(verified_at, self._now_provider())
        encrypted_token = self._secret_cipher.encrypt(
            purchase_token.encode(),
            purpose="purchase-token",
            record_id=existing.token_fingerprint,
        )
        verified = self._build_verified_subscription(
            snapshot=snapshot,
            line_item=line_item,
            entitlement_id=existing.entitlement_id,
            token_fingerprint=existing.token_fingerprint,
            encrypted_purchase_token=encrypted_token,
            encryption_key_id=self._secret_cipher.key_id,
            package_name=existing.package_name,
            product_id=existing.product_id,
            base_plan_id=existing.base_plan_id,
            now=verified_at,
            bundle_id=existing.bundle_id,
            acknowledged_at=acknowledged_at,
            suspended_at=existing.suspended_at,
            unsuspended_at=existing.unsuspended_at,
        )
        return await self._repository.store_verified_subscription(verified, now=verified_at)

    def _build_verified_subscription(
        self,
        *,
        snapshot: GooglePlaySnapshot,
        line_item: GooglePlayLineItem,
        entitlement_id: str,
        token_fingerprint: str,
        encrypted_purchase_token: bytes,
        encryption_key_id: str,
        package_name: str,
        product_id: str,
        base_plan_id: str,
        now: datetime,
        bundle_id: str | None = None,
        acknowledged_at: datetime | None = None,
        suspended_at: datetime | None = None,
        unsuspended_at: datetime | None = None,
    ) -> VerifiedSubscription:
        normalized = normalize_entitlement(
            snapshot.state,
            expiry_time=line_item.expiry_time,
            now=now,
        )
        if (
            snapshot.acknowledgement_state is AcknowledgementState.ACKNOWLEDGED
            and acknowledged_at is None
        ):
            # Google exposes acknowledgement state but not its timestamp. The
            # first authoritative observation repairs a lost local marker.
            acknowledged_at = now
        next_reconciliation = now + self._reconciliation_interval
        if normalized.access_deadline is not None:
            next_reconciliation = min(next_reconciliation, normalized.access_deadline)
        return VerifiedSubscription(
            entitlement_id=entitlement_id,
            token_fingerprint=token_fingerprint,
            encrypted_purchase_token=encrypted_purchase_token,
            encryption_key_id=encryption_key_id,
            package_name=package_name,
            product_id=product_id,
            base_plan_id=base_plan_id,
            latest_order_id=line_item.latest_successful_order_id,
            google_state=snapshot.state,
            entitlement_state=normalized.state,
            start_time=snapshot.start_time,
            current_period_end=line_item.expiry_time,
            grace_deadline=(
                line_item.expiry_time
                if snapshot.state is GoogleSubscriptionState.IN_GRACE_PERIOD
                else None
            ),
            acknowledgement_state=snapshot.acknowledgement_state,
            acknowledged_at=acknowledged_at,
            binding_verified=True,
            bundle_id=bundle_id,
            suspended_at=suspended_at,
            unsuspended_at=unsuspended_at,
            last_verified_at=now,
            next_reconciliation_at=next_reconciliation,
            linked_token_fingerprint=(
                fingerprint(snapshot.linked_purchase_token)
                if snapshot.linked_purchase_token
                else None
            ),
            out_of_app_expired_token_fingerprint=(
                fingerprint(snapshot.expired_purchase_token)
                if snapshot.expired_purchase_token
                else None
            ),
        )

    def _validate_requested_product(self, submission: PurchaseSubmission) -> None:
        if submission.package_name != self._package_name:
            raise GooglePlayVerificationException("Unexpected Android package name")
        if submission.base_plan_id not in self._allowed_products.get(
            submission.product_id, frozenset()
        ):
            raise InvalidSubscriptionProductException(
                "Subscription product or base plan is not enabled"
            )

    def _validate_integrity(
        self,
        response: dict[str, Any],
        *,
        request_hash: str,
        now: datetime,
    ) -> None:
        try:
            payload = response["tokenPayloadExternal"]
            request_details = payload["requestDetails"]
            timestamp = datetime.fromtimestamp(
                int(request_details["timestampMillis"]) / 1000,
                tz=timezone.utc,
            )
            app_integrity = payload["appIntegrity"]
            certificate_digests = set(app_integrity["certificateSha256Digest"])
            licensing_verdict = payload["accountDetails"]["appLicensingVerdict"]
            device_verdicts = set(payload["deviceIntegrity"]["deviceRecognitionVerdict"])
        except (KeyError, TypeError, ValueError, OverflowError) as exc:
            raise GooglePlayVerificationException(
                "Play Integrity returned an incomplete verdict"
            ) from exc

        if (
            request_details.get("requestPackageName") != self._package_name
            or request_details.get("requestHash") != request_hash
            or timestamp < now - self._integrity_max_age
            or timestamp > now + self._integrity_future_skew
            or app_integrity.get("appRecognitionVerdict") != "PLAY_RECOGNIZED"
            or app_integrity.get("packageName") != self._package_name
            or not certificate_digests.intersection(self._certificate_digests)
            or licensing_verdict != "LICENSED"
            or "MEETS_DEVICE_INTEGRITY" not in device_verdicts
        ):
            raise GooglePlayVerificationException("Play Integrity verdict was not accepted")

    @staticmethod
    def _select_line_item(
        snapshot: GooglePlaySnapshot,
        *,
        product_id: str,
        base_plan_id: str,
    ) -> GooglePlayLineItem:
        matching = [
            item
            for item in snapshot.line_items
            if item.product_id == product_id and item.base_plan_id == base_plan_id
        ]
        if len(matching) != 1:
            raise GooglePlayVerificationException(
                "Google Play did not return exactly one requested line item"
            )
        return matching[0]

    @staticmethod
    def _validate_account_binding(snapshot: GooglePlaySnapshot, *, expected: str) -> None:
        current = [
            value
            for value in (
                snapshot.obfuscated_external_account_id,
                snapshot.obfuscated_external_profile_id,
            )
            if value is not None
        ]
        expired = [
            value
            for value in (
                snapshot.expired_obfuscated_external_account_id,
                snapshot.expired_obfuscated_external_profile_id,
            )
            if value is not None
        ]
        identifiers = current or expired
        if not identifiers or any(value != expected for value in identifiers):
            raise GooglePlayVerificationException(
                "Google Play purchase is not bound to this entitlement"
            )
