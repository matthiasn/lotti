import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';

/// Generators for `extractTaskText` property tests.
extension AnyExtractTask on glados.Any {
  /// Short titles (1–25 chars) from safe ASCII letters.
  glados.Generator<String> get taskTitle =>
      glados.any.stringOf('abcdefghijklmnopqrstuvwxyzABCDEFG ');

  /// Label names: each 3–10 chars.
  glados.Generator<String> get labelName =>
      glados.any.stringOf('abcdefghijklmnopqrstuvwxyz');

  /// Lists of 0–4 label names.
  glados.Generator<List<String>> get labelNameList =>
      glados.ListAnys(this).listWithLengthInRange(0, 4, labelName);

  /// Body text: a distinctive, trim-stable, always-non-empty marker followed
  /// by generated lowercase letters. The fixed `BODY_` prefix guarantees the
  /// body is non-empty, never collides with the title/labels alphabet, and
  /// has no leading/trailing whitespace (so `.trim()` is a no-op on it).
  glados.Generator<String> get taskBody => glados.StringAnys(
    this,
  ).stringOf('abcdefghijklmnopqrstuvwxyz').map((suffix) => 'BODY_$suffix');
}

/// Builds a minimal [Metadata] for test entities.
Metadata hMeta({String id = 'test-id'}) => Metadata(
  id: id,
  createdAt: DateTime(2024, 3, 15),
  updatedAt: DateTime(2024, 3, 15),
  dateFrom: DateTime(2024, 3, 15),
  dateTo: DateTime(2024, 3, 15),
);

/// Text that is long enough to pass the minimum length threshold.
const hLongText = 'This is a sufficiently long text for embedding generation.';

/// Text that is too short to embed.
const hShortText = 'Too short';
