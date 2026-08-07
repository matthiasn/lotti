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
