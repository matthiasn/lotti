import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/vector_clock.dart';

// ---------------------------------------------------------------------------
// Glados generator helpers for Metadata.
// ---------------------------------------------------------------------------

class GeneratedMetadata {
  const GeneratedMetadata({
    required this.idSlot,
    required this.dateSlot,
    required this.categorySlot,
    required this.labelCountSlot,
    required this.flagSlot,
    required this.optionalsSlot,
  });

  final int idSlot;
  final int dateSlot;
  final int categorySlot;
  final int labelCountSlot;
  final int flagSlot;
  final int optionalsSlot;

  Metadata get metadata {
    final date = DateTime.utc(2024, (dateSlot % 12) + 1, (dateSlot % 28) + 1);
    final categoryId = categorySlot.isEven ? null : 'cat-$categorySlot';
    final labelCount = labelCountSlot % 4;
    final labelIds = labelCount == 0
        ? null
        : List.generate(labelCount, (i) => 'lbl-$idSlot-$i');
    final flag = flagSlot % 4 == 0
        ? null
        : EntryFlag.values[flagSlot % EntryFlag.values.length];
    final vclock = optionalsSlot.isEven
        ? null
        : VectorClock({'node-$idSlot': optionalsSlot % 10});
    final deletedAt = optionalsSlot % 5 == 0 ? DateTime(2025) : null;

    return Metadata(
      id: 'meta-$idSlot',
      createdAt: date,
      updatedAt: date,
      dateFrom: date,
      dateTo: date,
      categoryId: categoryId,
      labelIds: labelIds,
      utcOffset: optionalsSlot % 3 == 0 ? null : (optionalsSlot % 720) - 360,
      timezone: optionalsSlot.isOdd ? 'UTC' : null,
      vectorClock: vclock,
      deletedAt: deletedAt,
      flag: flag,
      starred: optionalsSlot.isEven ? true : null,
      private: optionalsSlot % 3 == 0 ? false : null,
    );
  }

  @override
  String toString() =>
      'GeneratedMetadata(idSlot: $idSlot, dateSlot: $dateSlot, '
      'flagSlot: $flagSlot, optionalsSlot: $optionalsSlot)';
}

extension AnyJournalEntities on glados.Any {
  glados.Generator<GeneratedMetadata> get generatedMetadata =>
      glados.CombinableAny(this).combine6(
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 5),
        glados.IntAnys(this).intInRange(0, 15),
        (
          idSlot,
          dateSlot,
          categorySlot,
          labelCountSlot,
          flagSlot,
          optionalsSlot,
        ) => GeneratedMetadata(
          idSlot: idSlot,
          dateSlot: dateSlot,
          categorySlot: categorySlot,
          labelCountSlot: labelCountSlot,
          flagSlot: flagSlot,
          optionalsSlot: optionalsSlot,
        ),
      );
}
