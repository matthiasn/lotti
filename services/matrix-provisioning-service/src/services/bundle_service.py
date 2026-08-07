"""Bundle creation, redemption and revocation orchestration."""

from __future__ import annotations

import hashlib
import logging

import httpx

from shared.matrix import (
    ProvisioningError,
    SynapseAdminClient,
    SynapseProvisioner,
    UserAlreadyExistsError,
)

from ..core.exceptions import (
    SynapseUnavailableException,
    UsernameAlreadyProvisionedException,
)
from ..core.models import (
    CreateBundleRequest,
    CreateBundleResponse,
    ProvisionedUser,
)
from .provisioning_repository import ProvisioningRepository

logger = logging.getLogger(__name__)


def fingerprint_bundle(encoded_bundle: str) -> str:
    """Return a SHA-256 hex digest of an encoded bundle.

    The bundle contains a live password, so it is never persisted. The
    fingerprint lets an admin confirm that a bundle string a user has pasted
    into a support conversation matches a particular record, without the server
    ever holding the credential.
    """
    return hashlib.sha256(encoded_bundle.encode()).hexdigest()


class BundleService:
    """Provisions accounts and keeps the persistent record in step with Synapse."""

    def __init__(
        self,
        provisioner: SynapseProvisioner,
        repository: ProvisioningRepository,
        admin_client: SynapseAdminClient,
    ) -> None:
        self._provisioner = provisioner
        self._repository = repository
        self._admin_client = admin_client

    async def create_bundle(self, request: CreateBundleRequest) -> CreateBundleResponse:
        """Provision a new account and return its bundle exactly once.

        The bundle string is returned to the caller and then discarded — only
        its fingerprint is stored. If it is lost before reaching the user, the
        record must be revoked and a new account provisioned.

        Args:
            request: The validated creation request.

        Returns:
            The bundle string and the stored record.

        Raises:
            UsernameAlreadyProvisionedException: If the username is taken,
                either in our own records or already on the homeserver.
            SynapseUnavailableException: If the homeserver rejects the request.
        """
        # Fail before touching Synapse when we already know the name is taken,
        # so the common case does not leave an account to roll back. The unique
        # index is still the authority for the concurrent case.
        #
        # This checks our own records only, which is not the same question as
        # "is the localpart free on the homeserver" — accounts created by the
        # CLI, or any ordinary Synapse user, have no row here. The provisioner
        # asks Synapse itself before creating, and raises below.
        if await self._repository.find_by_username(request.username) is not None:
            raise UsernameAlreadyProvisionedException(f"{request.username} is already provisioned")

        # Take the name before touching Synapse. The homeserver existence check
        # and the account creation are two separate calls, and the creation is
        # an upsert — so without a claim two concurrent requests for the same
        # localpart both see "free", and the second resets the account the first
        # just made, handing its owner a bundle whose password no longer works.
        if not await self._repository.claim_username(request.username):
            raise UsernameAlreadyProvisionedException(
                f"{request.username} is already being provisioned by another request"
            )

        try:
            return await self._provision_claimed(request)
        finally:
            await self._repository.release_username(request.username)

    async def _provision_claimed(self, request: CreateBundleRequest) -> CreateBundleResponse:
        """Provision and record an account whose name this run already holds.

        Split out so the claim is released on every exit path, including the
        orphan-rollback one, without wrapping the whole body in another level of
        indentation.
        """
        try:
            result = await self._provisioner.provision(
                username=request.username,
                display_name=request.display_name,
            )
        except UserAlreadyExistsError as exc:
            # Ahead of the ProvisioningError branch it inherits from: an
            # occupied localpart is a 409 the admin can act on, not a
            # homeserver failure.
            raise UsernameAlreadyProvisionedException(str(exc)) from exc
        except httpx.HTTPStatusError as exc:
            raise SynapseUnavailableException(
                f"Synapse rejected provisioning for {request.username}: "
                f"HTTP {exc.response.status_code}"
            ) from exc
        except (httpx.RequestError, ProvisioningError) as exc:
            raise SynapseUnavailableException(
                f"Could not reach Synapse to provision {request.username}: {exc}"
            ) from exc

        encoded = result.encoded_bundle

        try:
            user = await self._repository.create(
                username=request.username,
                user_mxid=result.user_mxid,
                home_server=result.bundle.home_server,
                server_name=result.server_name,
                room_id=result.room_id,
                display_name=request.display_name,
                bundle_fingerprint=fingerprint_bundle(encoded),
                notes=request.notes,
            )
        except Exception:
            # The account exists on Synapse but we cannot record it. An
            # untracked live account is worse than none, so roll it back.
            logger.exception(
                "Failed to persist %s after provisioning; deactivating the account",
                result.user_mxid,
            )
            try:
                await self._admin_client.deactivate_user(result.user_mxid)
            except Exception:  # noqa: BLE001 - rollback is best-effort
                logger.exception(
                    "Could not deactivate orphan account %s — needs manual cleanup",
                    result.user_mxid,
                )
            raise

        return CreateBundleResponse(bundle=encoded, user=user)

    async def confirm_rotation(self, bundle_id: str) -> ProvisionedUser:
        """Mark a bundle rotated in response to a client callback (Phase 2)."""
        return await self._repository.mark_rotated(bundle_id)

    async def revoke(
        self, bundle_id: str, reason: str = "", deactivate_account: bool = False
    ) -> ProvisionedUser:
        """Revoke a bundle, optionally deactivating the Matrix account.

        Args:
            bundle_id: The bundle to revoke.
            reason: Free-text reason recorded in the audit trail.
            deactivate_account: When true, also deactivate the account on
                Synapse. Use for an unredeemed bundle that leaked; leave false
                to retire the record while the user keeps their account.

        Raises:
            BundleNotFoundException: If the bundle does not exist.
            SynapseUnavailableException: If deactivation was requested and failed.
        """
        user = await self._repository.get(bundle_id)
        if user is None:
            from ..core.exceptions import BundleNotFoundException

            raise BundleNotFoundException(bundle_id)

        if deactivate_account:
            try:
                await self._admin_client.deactivate_user(user.user_mxid)
            except (httpx.HTTPError, ProvisioningError) as exc:
                raise SynapseUnavailableException(
                    f"Could not deactivate {user.user_mxid}: {exc}"
                ) from exc

        detail = reason or "Revoked by admin"
        if deactivate_account:
            detail = f"{detail} (account deactivated)"
        return await self._repository.revoke(bundle_id, detail)
