"""Reliable encrypted bundle provisioning for verified Play subscriptions."""

from __future__ import annotations

import asyncio
import base64
import hashlib
import hmac
import uuid
from datetime import datetime, timedelta

from ..core.exceptions import (
    BundleClaimConflictException,
    GooglePlayVerificationException,
    UsernameAlreadyProvisionedException,
)
from ..core.models import CreateBundleRequest
from ..core.subscriptions import (
    AcknowledgementState,
    BundleClaim,
    EntitlementState,
    PaidBundleDelivery,
    PurchaseSubmission,
    VerifiedPurchaseResult,
)
from .bundle_service import BundleService, fingerprint_bundle
from .google_play_client import GooglePlayClient
from .secret_cipher import SecretCipher
from .subscription_repository import SubscriptionRepository
from .subscription_security import SecretHasher

_ACCESS_STATES = {
    EntitlementState.ACTIVE,
    EntitlementState.GRACE,
    EntitlementState.CANCELED_ACTIVE,
}


class PaidBundleService:
    """Provision exactly one Matrix account and escrow its bootstrap bundle."""

    def __init__(
        self,
        bundle_service: BundleService,
        repository: SubscriptionRepository,
        google_play_client: GooglePlayClient,
        secret_cipher: SecretCipher,
        *,
        claim_ttl: timedelta = timedelta(hours=24),
        secret_hasher: SecretHasher | None = None,
    ):
        self._bundle_service = bundle_service
        self._repository = repository
        self._google_play_client = google_play_client
        self._secret_cipher = secret_cipher
        self._claim_ttl = claim_ttl
        self._secret_hasher = secret_hasher or SecretHasher()
        self._provisioning_locks = tuple(asyncio.Lock() for _ in range(64))

    async def provision_or_deliver(
        self,
        verified: VerifiedPurchaseResult,
        submission: PurchaseSubmission,
        *,
        now: datetime,
    ) -> PaidBundleDelivery:
        """Return the same escrowed bundle across network retries."""
        if not _grants_access(verified.subscription, now=now):
            raise GooglePlayVerificationException(
                "Subscription does not currently grant SYNC access"
            )
        if not await asyncio.to_thread(
            self._secret_hasher.verify,
            submission.claim_secret,
            verified.claim_secret_hash,
        ):
            raise BundleClaimConflictException("Invalid bundle claim secret")

        lock_index = self._lock_index(verified.subscription.entitlement_id)
        async with self._provisioning_locks[lock_index]:
            return await self._provision_or_deliver_locked(verified, submission, now=now)

    async def _provision_or_deliver_locked(
        self,
        verified: VerifiedPurchaseResult,
        submission: PurchaseSubmission,
        *,
        now: datetime,
    ) -> PaidBundleDelivery:
        """Provision or reuse escrow while the entitlement stripe is held."""

        current = await self._repository.get_current_subscription(
            verified.subscription.entitlement_id
        )
        if current is None or current.token_fingerprint != verified.subscription.token_fingerprint:
            raise GooglePlayVerificationException("Verified purchase is no longer current")
        if not _grants_access(current, now=now):
            raise GooglePlayVerificationException(
                "Subscription does not currently grant SYNC access"
            )
        existing = await self._repository.get_bundle_claim_for_entitlement(
            verified.subscription.entitlement_id
        )
        reprovisioning = False
        if (
            existing is not None
            and existing.confirmed_at is None
            and existing.destroyed_at is not None
        ):
            await self._repository.release_abandoned_bundle_claim(
                verified.subscription.entitlement_id,
                now=now,
            )
            existing = None
            reprovisioning = True
        if existing is not None:
            if existing.confirmed_at is not None:
                # A rotated Matrix account is already the durable sync identity.
                # Replacement purchases restore access to it; the destroyed
                # bootstrap credential must never be recreated or redelivered.
                delivery = PaidBundleDelivery(
                    bundle_id=existing.bundle_id,
                    bundle=None,
                    expires_at=None,
                    rotation_challenge=None,
                    bundle_import_required=False,
                )
            else:
                if existing.claim_secret_hash != verified.claim_secret_hash:
                    existing = await self._repository.reauthorize_pending_bundle_claim(
                        verified.subscription.entitlement_id,
                        token_fingerprint=current.token_fingerprint,
                        claim_secret_hash=verified.claim_secret_hash,
                    )
                delivery = await self._deliver_existing(
                    existing,
                    claim_secret=submission.claim_secret,
                    now=now,
                )
        else:
            initial_username = self._username(
                verified.subscription.entitlement_id,
                retry_suffix=(uuid.uuid4().hex[:8] if reprovisioning else None),
            )
            try:
                claim = await self._provision_claim(
                    verified,
                    username=initial_username,
                    now=now,
                )
            except UsernameAlreadyProvisionedException:
                claim = await self._provision_claim(
                    verified,
                    username=self._username(
                        verified.subscription.entitlement_id,
                        retry_suffix=uuid.uuid4().hex[:8],
                    ),
                    now=now,
                )
            delivery = await self._deliver_existing(
                claim,
                claim_secret=submission.claim_secret,
                now=now,
            )

        if current.acknowledgement_state is AcknowledgementState.PENDING:
            await self._google_play_client.acknowledge_subscription(
                submission.package_name,
                submission.product_id,
                submission.purchase_token,
            )
            await self._repository.mark_subscription_acknowledged(
                current.token_fingerprint,
                now=now,
            )
        return delivery

    async def _provision_claim(
        self,
        verified: VerifiedPurchaseResult,
        *,
        username: str,
        now: datetime,
    ) -> BundleClaim:
        """Provision and atomically persist one paid claim for a chosen localpart."""
        request = CreateBundleRequest(
            username=username,
            display_name="Lotti SYNC",
            notes="Verified Google Play subscription",
        )

        async def persist(result, encoded):
            bundle_id = str(uuid.uuid4())
            encrypted_bundle = self._secret_cipher.encrypt(
                encoded.encode(),
                purpose="bundle",
                record_id=bundle_id,
            )
            _, claim = await self._repository.store_paid_bundle(
                token_fingerprint=verified.subscription.token_fingerprint,
                bundle_id=bundle_id,
                username=username,
                user_mxid=result.user_mxid,
                home_server=result.bundle.home_server,
                server_name=result.server_name,
                room_id=result.room_id,
                display_name=request.display_name,
                bundle_fingerprint=fingerprint_bundle(encoded),
                notes=request.notes,
                claim_secret_hash=verified.claim_secret_hash,
                encrypted_bundle=encrypted_bundle,
                encryption_key_id=self._secret_cipher.key_id,
                expires_at=now + self._claim_ttl,
                now=now,
            )
            return claim

        return await self._bundle_service.create_bundle_with_persistence(request, persist)

    async def deliver_existing_claim(
        self,
        *,
        entitlement_id: str,
        claim_secret: str,
        now: datetime,
    ) -> PaidBundleDelivery:
        """Retry delivery without replaying a Play purchase or Integrity token."""
        async with self._provisioning_locks[self._lock_index(entitlement_id)]:
            claim = await self._repository.get_bundle_claim_for_entitlement(entitlement_id)
            if claim is None:
                raise BundleClaimConflictException("No bundle claim exists")
            await self._authorize_claim_secret(claim, claim_secret)
            subscription = await self._repository.get_current_subscription(entitlement_id)
            if subscription is None or not _grants_access(subscription, now=now):
                raise GooglePlayVerificationException(
                    "Subscription does not currently grant SYNC access"
                )
            return await self._deliver_authorized(claim, claim_secret=claim_secret, now=now)

    async def _deliver_existing(
        self,
        claim,
        *,
        claim_secret: str,
        now: datetime,
    ) -> PaidBundleDelivery:
        await self._authorize_claim_secret(claim, claim_secret)
        return await self._deliver_authorized(claim, claim_secret=claim_secret, now=now)

    async def _authorize_claim_secret(self, claim: BundleClaim, claim_secret: str) -> None:
        if not await asyncio.to_thread(
            self._secret_hasher.verify,
            claim_secret,
            claim.claim_secret_hash,
        ):
            raise BundleClaimConflictException("Invalid bundle claim secret")

    async def _deliver_authorized(
        self,
        claim: BundleClaim,
        *,
        claim_secret: str,
        now: datetime,
    ) -> PaidBundleDelivery:
        if now >= claim.expires_at or claim.encrypted_bundle is None:
            raise BundleClaimConflictException("Bundle claim is expired or already destroyed")
        bundle = self._secret_cipher.decrypt(
            claim.encrypted_bundle,
            purpose="bundle",
            record_id=claim.bundle_id,
            key_id=claim.encryption_key_id,
        ).decode()
        await self._repository.mark_bundle_delivered(claim.bundle_id, now=now)
        return PaidBundleDelivery(
            bundle_id=claim.bundle_id,
            bundle=bundle,
            expires_at=claim.expires_at,
            rotation_challenge=rotation_challenge(claim_secret, claim.bundle_id),
        )

    def _lock_index(self, entitlement_id: str) -> int:
        return int(hashlib.sha256(entitlement_id.encode()).hexdigest(), 16) % len(
            self._provisioning_locks
        )

    @staticmethod
    def _username(entitlement_id: str, *, retry_suffix: str | None = None) -> str:
        source = entitlement_id if retry_suffix is None else f"{entitlement_id}_{retry_suffix}"
        compact = "".join(character for character in source if character.isalnum())
        return f"sync_{compact.lower()}"[:64]


def rotation_challenge(claim_secret: str, bundle_id: str) -> str:
    """Derive the Matrix room proof expected for one paid bundle claim."""
    digest = hmac.new(
        claim_secret.encode(),
        f"lotti-sync-rotation-v1\0{bundle_id}".encode(),
        hashlib.sha256,
    ).digest()
    return base64.urlsafe_b64encode(digest).rstrip(b"=").decode()


def _grants_access(subscription, *, now: datetime) -> bool:
    return subscription.entitlement_state in _ACCESS_STATES and (
        subscription.current_period_end is None or now < subscription.current_period_end
    )
