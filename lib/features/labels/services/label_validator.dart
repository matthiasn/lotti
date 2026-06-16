import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

/// Validates proposed label IDs against current definitions.
///
/// Ensures that only existing and non-deleted labels are considered valid.
class LabelValidator {
  LabelValidator({JournalDb? db}) : _db = db ?? getIt<JournalDb>();

  final JournalDb _db;

  /// Validate requested label IDs for a specific task, taking both category
  /// scope and per-task suppression into account.
  ///
  /// Returns three buckets:
  /// - valid: assignable (exist, not deleted, in scope, not suppressed)
  /// - invalid: unknown or deleted, or out of category scope
  /// - suppressed: explicitly suppressed for this task
  Future<
    ({
      List<String> valid,
      List<String> invalid,
      List<String> suppressed,
    })
  >
  validateForTask(
    List<String> requested, {
    String? categoryId,
    Set<String>? suppressedIds,
  }) async {
    final valid = <String>[];
    final invalid = <String>[];
    final suppressed = <String>[];

    final suppressedSet = suppressedIds ?? const <String>{};

    for (final id in requested) {
      final def = await _db.getLabelDefinitionById(id);
      if (def == null || def.deletedAt != null) {
        invalid.add(id);
        continue;
      }

      // Category scope check
      final cats = def.applicableCategoryIds;
      final isGlobal = cats == null || cats.isEmpty;
      final inCategory =
          categoryId != null && (cats?.contains(categoryId) ?? false);
      final inScope = isGlobal || inCategory;
      if (!inScope) {
        invalid.add(id);
        continue;
      }

      // Suppression check (after scope check so deleted/out-of-scope remain invalid)
      if (suppressedSet.contains(id)) {
        suppressed.add(id);
        continue;
      }

      valid.add(id);
    }

    return (valid: valid, invalid: invalid, suppressed: suppressed);
  }
}
