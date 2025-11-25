"""Custom exceptions for the credits service"""


class CreditsServiceException(Exception):
    """Base exception for all credits service errors"""

    pass


class AccountNotFoundException(CreditsServiceException):
    """Raised when an account is not found"""

    pass


class AccountAlreadyExistsException(CreditsServiceException):
    """Raised when attempting to create an account that already exists"""

    pass


class InsufficientBalanceException(CreditsServiceException):
    """Raised when an account has insufficient balance for a transaction"""

    pass


class InvalidAmountException(CreditsServiceException):
    """Raised when an invalid amount is provided"""

    pass


class TigerBeetleException(CreditsServiceException):
    """Raised when TigerBeetle returns an error"""

    pass


class DatabaseConnectionException(CreditsServiceException):
    """Raised when unable to connect to TigerBeetle"""

    pass
