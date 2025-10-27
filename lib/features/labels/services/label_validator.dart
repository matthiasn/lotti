import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

/// Validates proposed label IDs against current definitions.
///
/// Ensures that only existing and non-deleted labels are considered valid.
class LabelValidator {
  LabelValidator({JournalDb? db}) : _db = db ?? getIt<JournalDb>();

  final JournalDb _db;

  /// Splits the requested IDs into valid and invalid buckets.
  Future<({List<String> valid, List<String> invalid})> validate(
      List<String> requested) async {
    final valid = <String>[];
    final invalid = <String>[];
    for (final id in requested) {
      final def = await _db.getLabelDefinitionById(id);
      if (def == null || def.deletedAt != null) {
        invalid.add(id);
      } else {
        valid.add(id);
      }
    }
    return (valid: valid, invalid: invalid);
  }
}
