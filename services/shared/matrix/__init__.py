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
from .core import (
    AdminCredentials,
    ProvisioningError,
    SynapseClientBase,
    UserAlreadyExistsError,
    encode_mxid_for_path,
    encode_room_id_for_path,
)
from .provisioner import ProvisionResult, SynapseProvisioner

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
    "SynapseClientBase",
    "SynapseProvisioner",
    "UserActivity",
    "UserAlreadyExistsError",
    "UserMediaUsage",
    "encode_mxid_for_path",
    "encode_room_id_for_path",
]
