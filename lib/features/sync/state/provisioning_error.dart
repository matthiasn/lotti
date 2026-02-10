/// Typed error variants for the provisioning flow.
///
/// Used by `ProvisioningState.error` instead of raw strings so that the UI
/// layer can map each variant to a localized message.
enum ProvisioningError {
  /// Login with the bundle credentials was rejected.
  loginFailed,

  /// A catch-all for errors during room-join, password rotation, or config
  /// persistence. The original exception is already logged via the logging
  /// service.
  configurationError,
}
