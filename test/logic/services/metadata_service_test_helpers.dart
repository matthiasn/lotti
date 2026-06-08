import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';


class GeneratedMetadataUpdateScenario {
  const GeneratedMetadataUpdateScenario({
    required this.mask,
    required this.seed,
  });

  final int mask;
  final int seed;

  bool get hasDateFrom => _bit(0);

  bool get hasDateTo => _bit(1);

  bool get hasCategoryId => _bit(2);

  bool get clearCategoryId => _bit(3);

  bool get hasLabelIds => _bit(4);

  bool get clearLabelIds => _bit(5);

  bool get hasDeletedAt => _bit(6);

  bool get originalIsDeleted => _bit(7);

  DateTime? get dateFrom =>
      hasDateFrom ? DateTime(2024, 2, 1 + (seed % 20), 8) : null;

  DateTime? get dateTo =>
      hasDateTo ? DateTime(2024, 2, 1 + (seed % 20), 18) : null;

  String? get categoryId => hasCategoryId ? 'category-$seed' : null;

  List<String>? get labelIds {
    if (!hasLabelIds) return null;
    return [
      'label-${seed % 7}',
      'label-${(seed + 1) % 7}',
    ];
  }

  DateTime? get deletedAt =>
      hasDeletedAt ? DateTime(2024, 3, 1 + (seed % 20), 12) : null;

  DateTime? get originalDeletedAt =>
      originalIsDeleted ? DateTime(2024, 1, 20, 9) : null;

  DateTime expectedDateFrom(Metadata original) => dateFrom ?? original.dateFrom;

  DateTime expectedDateTo(Metadata original) => dateTo ?? original.dateTo;

  String? expectedCategoryId(Metadata original) =>
      clearCategoryId ? null : categoryId ?? original.categoryId;

  List<String>? expectedLabelIds(Metadata original) =>
      clearLabelIds ? null : labelIds ?? original.labelIds;

  DateTime? expectedDeletedAt(Metadata original) =>
      deletedAt ?? original.deletedAt;

  bool _bit(int bit) => (mask & (1 << bit)) != 0;

  @override
  String toString() {
    return 'GeneratedMetadataUpdateScenario('
        'mask: $mask, '
        'seed: $seed)';
  }
}

extension AnyGeneratedMetadataUpdateScenario on glados.Any {
  glados.Generator<GeneratedMetadataUpdateScenario>
  get metadataUpdateScenario => glados.CombinableAny(this).combine2(
    glados.IntAnys(this).intInRange(0, 1 << 8),
    glados.IntAnys(this).intInRange(0, 10000),
    (int mask, int seed) => GeneratedMetadataUpdateScenario(
      mask: mask,
      seed: seed,
    ),
  );
}
