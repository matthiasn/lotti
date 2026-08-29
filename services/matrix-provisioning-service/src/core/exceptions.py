"""Custom exceptions for the matrix provisioning service"""


class ProvisioningServiceException(Exception):
    """Base exception for all provisioning service errors"""

    pass


class BundleNotFoundException(ProvisioningServiceException):
    """Raised when a bundle ID does not exist"""

    pass


class UsernameAlreadyProvisionedException(ProvisioningServiceException):
    """Raised when a username has already been provisioned on this homeserver"""

    pass


class InvalidBundleStateException(ProvisioningServiceException):
    """Raised when a state transition is not legal for a bundle's current status"""

    pass


class SynapseUnavailableException(ProvisioningServiceException):
    """Raised when the homeserver cannot be reached or rejects admin credentials"""

    pass


class PurchaseTokenConflictException(ProvisioningServiceException):
    """Raised when a Play identity or token is already bound elsewhere."""

    pass


class SubscriptionLineageException(ProvisioningServiceException):
    """Raised when a replacement token does not belong to its entitlement."""

    pass


class PurchaseIntentNotFoundException(ProvisioningServiceException):
    """Raised when a purchase intent does not exist for an entitlement."""

    pass


class PurchaseIntentExpiredException(ProvisioningServiceException):
    """Raised when a purchase intent is submitted after its deadline."""

    pass


class PurchaseIntentReplayException(ProvisioningServiceException):
    """Raised when a consumed intent is reused for a different request."""

    pass


class GooglePlayVerificationException(ProvisioningServiceException):
    """Raised when Google rejects or returns an invalid purchase proof."""

    pass


class GooglePlayUnavailableException(ProvisioningServiceException):
    """Raised when a Google API cannot be reached or is temporarily failing."""

    pass


class EntitlementAuthenticationException(ProvisioningServiceException):
    """Raised when an entitlement credential is absent, disabled, or invalid."""

    pass


class EntitlementRateLimitException(ProvisioningServiceException):
    """Raised when one anonymous client creates too many entitlements."""

    def __init__(self, *, retry_after_seconds: int):
        super().__init__("Entitlement creation rate limit exceeded")
        self.retry_after_seconds = retry_after_seconds


class InvalidSubscriptionProductException(ProvisioningServiceException):
    """Raised when a product or base plan is not configured for SYNC."""

    pass


class BundleClaimConflictException(ProvisioningServiceException):
    """Raised when paid provisioning would create a second bundle claim."""

    pass


class PubSubAuthenticationException(ProvisioningServiceException):
    """Raised when an RTDN push JWT or envelope cannot be trusted."""

    pass
