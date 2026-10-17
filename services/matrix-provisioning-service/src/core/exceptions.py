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


class PurchaseIntentRateLimitException(ProvisioningServiceException):
    """Raised when one entitlement creates too many purchase intents."""

    def __init__(self, *, retry_after_seconds: int):
        super().__init__("Purchase intent creation rate limit exceeded")
        self.retry_after_seconds = retry_after_seconds


class PurchaseVerificationRateLimitException(ProvisioningServiceException):
    """Raised when one entitlement submits too many purchase verifications."""

    def __init__(self, *, retry_after_seconds: int):
        super().__init__("Purchase verification rate limit exceeded")
        self.retry_after_seconds = retry_after_seconds


class BundleClaimRateLimitException(ProvisioningServiceException):
    """Raised when one entitlement submits too many escrow operations."""

    def __init__(self, *, retry_after_seconds: int):
        super().__init__("Bundle claim operation rate limit exceeded")
        self.retry_after_seconds = retry_after_seconds


class UnknownPurchaseTokenException(GooglePlayVerificationException):
    """Raised when a Play token has no local entitlement binding."""


class InvalidSubscriptionProductException(ProvisioningServiceException):
    """Raised when a product or base plan is not configured for SYNC."""

    pass


class BundleClaimConflictException(ProvisioningServiceException):
    """Raised when paid provisioning would create a second bundle claim."""

    pass


class PubSubAuthenticationException(ProvisioningServiceException):
    """Raised when an RTDN push JWT or envelope cannot be trusted."""

    pass


class PaddleWebhookException(ProvisioningServiceException):
    """Raised when a Paddle notification is unsigned, replayed or malformed."""

    pass


class PaddleUnavailableException(ProvisioningServiceException):
    """Raised when the Paddle API cannot be reached or answers unexpectedly."""

    pass


class CheckoutSessionException(ProvisioningServiceException):
    """Raised when a web checkout session is unknown, expired or unbound."""

    pass


class AlreadySubscribedException(ProvisioningServiceException):
    """Raised when a checkout is requested for an entitlement that already pays."""

    pass


class PaymentPendingException(ProvisioningServiceException):
    """Raised when no web subscription grants access to the entitlement yet."""

    pass


class WebCheckoutRateLimitException(ProvisioningServiceException):
    """Raised when an entitlement exceeds its web-checkout attempt quota."""

    def __init__(self, *, retry_after_seconds: int):
        super().__init__("Web checkout rate limit exceeded")
        self.retry_after_seconds = retry_after_seconds
