import 'package:glados/glados.dart' show Any, Generator, StringAnys, any;

// ---------------------------------------------------------------------------
// Generator helpers
// ---------------------------------------------------------------------------

extension AnyX on Any {
  /// Generates a string of printable ASCII letters/digits (no tag characters).
  Generator<String> get safeText => any.letterOrDigits;
}
