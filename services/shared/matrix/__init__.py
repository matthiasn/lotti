"""Shared Matrix provisioning core.

The provisioning flow, admin client and bundle codec behind the
``tools/matrix_provisioner`` self-hosting CLI.
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
from .provisioner import SYNC_ROOM_RETENTION_DAYS, ProvisionResult, SynapseProvisioner

__all__ = [
    "BUNDLE_SCHEMA_VERSION",
    "SYNC_ROOM_RETENTION_DAYS",
    "AdminCredentials",
    "BundleDecodeError",
    "BundleKind",
    "MediaDeletion",
    "ProvisionResult",
    "ProvisioningError",
    "PurgeHandle",
    "PurgeStatus",
    "SynapseAdminClient",
    "SynapseClientBase",
    "SynapseProvisioner",
    "SyncBundle",
    "UserActivity",
    "UserAlreadyExistsError",
    "UserMediaUsage",
    "encode_mxid_for_path",
    "encode_room_id_for_path",
]
