"""Server validation of paid bundle import and password rotation."""

from __future__ import annotations

import asyncio
from datetime import datetime

from shared.matrix import SyncBundle, SynapseAdminClient

from ..core.exceptions import BundleClaimConflictException
from ..core.subscriptions import BundleClaim
from .paid_bundle_service import rotation_challenge
from .secret_cipher import SecretCipher
from .subscription_identity_service import SubscriptionIdentityService
from .subscription_repository import SubscriptionRepository
from .subscription_security import SecretHasher


ROTATION_EVENT_TYPE = "com.lotti.sync.provisioning.rotation"


class BundleRotationService:
    """Destroy escrow only after room proof and bootstrap-password invalidation."""

    def __init__(
        self,
        repository: SubscriptionRepository,
        identity_service: SubscriptionIdentityService,
        admin_client: SynapseAdminClient,
        secret_cipher: SecretCipher,
        *,
        secret_hasher: SecretHasher | None = None,
    ):
        self._repository = repository
        self._identity_service = identity_service
        self._admin_client = admin_client
        self._secret_cipher = secret_cipher
        self._secret_hasher = secret_hasher or SecretHasher()

    async def confirm_rotation(
        self,
        *,
        entitlement_id: str,
        entitlement_auth_secret: str,
        bundle_id: str,
        claim_secret: str,
        now: datetime,
    ) -> BundleClaim:
        """Validate the exact Matrix proof and confirm idempotently."""
        await self._identity_service.authenticate(
            entitlement_id,
            entitlement_auth_secret,
        )
        claim = await self._repository.get_bundle_claim_for_entitlement(entitlement_id)
        valid_claim_secret = (
            False
            if claim is None
            else await asyncio.to_thread(
                self._secret_hasher.verify,
                claim_secret,
                claim.claim_secret_hash,
            )
        )
        if claim is None or claim.bundle_id != bundle_id or not valid_claim_secret:
            raise BundleClaimConflictException("Invalid bundle claim credentials")
        if claim.destroyed_at is not None:
            return claim
        if now >= claim.expires_at or claim.encrypted_bundle is None:
            raise BundleClaimConflictException("Bundle claim has expired")

        user = await self._repository.get(bundle_id)
        if user is None:
            raise BundleClaimConflictException("Provisioned Matrix account is missing")
        state = await self._admin_client.get_room_state_as_user(
            user.user_mxid,
            user.room_id,
            ROTATION_EVENT_TYPE,
            state_key=bundle_id,
        )
        expected_challenge = rotation_challenge(claim_secret, bundle_id)
        if state.get("challenge") != expected_challenge:
            raise BundleClaimConflictException("Matrix rotation challenge does not match")

        encoded = self._secret_cipher.decrypt(
            claim.encrypted_bundle,
            purpose="bundle",
            record_id=bundle_id,
            key_id=claim.encryption_key_id,
        ).decode()
        bootstrap_password = SyncBundle.decode(encoded).password
        if await self._admin_client.password_authenticates(
            user.user_mxid,
            bootstrap_password,
        ):
            raise BundleClaimConflictException("Bootstrap password still authenticates")

        _, confirmed = await self._repository.confirm_paid_bundle_rotation(
            bundle_id,
            now=now,
        )
        return confirmed
