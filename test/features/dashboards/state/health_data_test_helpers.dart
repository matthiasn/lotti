import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/journal_entities.dart';

import '../test_utils.dart';

// ---------------------------------------------------------------------------
// Generators for Glados property tests.
// ---------------------------------------------------------------------------

/// A single generated entry spec: (dayOffset in [0..6], value in [1..1000]).
typedef EntrySpec = ({int dayOffset, int value});

extension AnyHealthData on glados.Any {
  glados.Generator<EntrySpec> get entrySpec =>
      glados.CombinableAny(this).combine2(
        glados.any.intInRange(0, 6),
        glados.any.intInRange(1, 1000),
        (int dayOffset, int value) => (dayOffset: dayOffset, value: value),
      );

  glados.Generator<List<EntrySpec>> get entrySpecs =>
      glados.ListAnys(this).listWithLengthInRange(1, 12, entrySpec);

  /// A non-empty list of minute values in [1..6000] (for transformToHours).
  glados.Generator<List<int>> get minuteValues =>
      glados.ListAnys(this).listWithLengthInRange(
        1,
        12,
        glados.any.intInRange(1, 6000),
      );

  /// A threshold-to-hex-color map with 1–4 entries.
  glados.Generator<Map<num, String>> get thresholdMap =>
      glados.CombinableAny(this).combine4(
        glados.any.intInRange(0, 300),
        glados.any.intInRange(301, 600),
        glados.any.intInRange(601, 900),
        glados.AnyUtils(this).choose(const [true, false]),
        (int t1, int t2, int t3, bool includeThird) => <num, String>{
          0: '#FF0000',
          t1: '#FFAA00',
          t2: '#00FF00',
          if (includeThird) t3: '#0000FF',
        },
      );
}

/// Converts an [EntrySpec] list to [QuantitativeEntry] items anchored at
/// [base].
List<JournalEntity> makeEntries(
  List<EntrySpec> specs,
  DateTime base,
) {
  return <JournalEntity>[
    for (var i = 0; i < specs.length; i++)
      makeQuantitativeEntry(
        dateFrom: base.add(Duration(days: specs[i].dayOffset)),
        value: specs[i].value,
        dataType: 'HealthDataType.WEIGHT',
        id: 'e$i',
      ),
  ];
}
