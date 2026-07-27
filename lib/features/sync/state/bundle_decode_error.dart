/// Why a pairing code could not be read.
///
/// The distinction the user needs is not which field failed validation but
/// what they should do next, and those collapse to two answers: update the
/// apps, or get a fresh code.
enum BundleDecodeError {
  /// The payload parsed but announced a schema version this build does not
  /// speak — the two devices are on different Lotti releases.
  unsupportedVersion,

  /// The payload is not a pairing code at all, or is truncated/corrupt.
  malformedPayload,
}

/// A decode failure that carries [error] so the UI can name a real remedy.
///
/// Extends [FormatException] so every existing `on FormatException` catch
/// keeps working; callers that want the specific cause catch this first.
class BundleDecodeException extends FormatException {
  const BundleDecodeException(this.error, String message) : super(message);

  final BundleDecodeError error;
}
