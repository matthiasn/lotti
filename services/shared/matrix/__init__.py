"""Shared Matrix provisioning core.

Used by both the ``tools/matrix_provisioner`` CLI and the
matrix-provisioning-service web API so the two can never drift apart.
"""

from .admin_client import (
    MediaDeletion,
    PurgeHandle,
    PurgeStatus,
    SynapseAdminClient,
    UserActivity,
    UserMediaUsage,
)
from .bundle import (
    BUNDLE_SCHEMA_VERSION,
    BundleDecodeError,
    BundleKind,
    SyncBundle,
)
from .provisioner import (
    AdminCredentials,
    ProvisioningError,
    ProvisionResult,
    SynapseProvisioner,
)

__all__ = [
    "BUNDLE_SCHEMA_VERSION",
    "AdminCredentials",
    "BundleDecodeError",
    "BundleKind",
    "MediaDeletion",
    "ProvisionResult",
    "ProvisioningError",
    "PurgeHandle",
    "PurgeStatus",
    "SyncBundle",
    "SynapseAdminClient",
    "SynapseProvisioner",
    "UserActivity",
    "UserMediaUsage",
]
