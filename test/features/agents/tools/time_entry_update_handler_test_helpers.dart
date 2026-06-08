import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_text.dart';


enum GeneratedSummaryShape {
  absent,
  valid,
  paddedValid,
  empty,
  tooLong,
  nonString,
}

enum GeneratedTimeArgShape {
  absent,
  valid,
  paddedValid,
  empty,
  invalidType,
  timezone,
  invalidLocal,
}

class GeneratedTimeEntryUpdateScenario {
  const GeneratedTimeEntryUpdateScenario({
    required this.summaryShape,
    required this.startShape,
    required this.endShape,
    required this.flags,
    required this.startOffsetSeed,
    required this.endOffsetSeed,
    required this.seed,
  });

  final GeneratedSummaryShape summaryShape;
  final GeneratedTimeArgShape startShape;
  final GeneratedTimeArgShape endShape;
  final int flags;
  final int startOffsetSeed;
  final int endOffsetSeed;
  final int seed;

  static final existingStart = DateTime(2026, 4, 15, 13);
  static final existingEnd = DateTime(2026, 4, 15, 14);

  bool get isLinked => flags.isOdd;
  bool get isActiveTimer => flags & 2 != 0;
  bool get persistenceSucceeds => flags & 4 != 0;

  int get startOffsetMinutes => (startOffsetSeed % 361) - 180;
  int get endOffsetMinutes => (endOffsetSeed % 361) - 180;

  DateTime get generatedStart =>
      existingStart.add(Duration(minutes: startOffsetMinutes));

  DateTime get generatedEnd =>
      existingEnd.add(Duration(minutes: endOffsetMinutes));

  Object? get rawSummary => switch (summaryShape) {
    GeneratedSummaryShape.absent => null,
    GeneratedSummaryShape.valid => 'Generated summary $seed',
    GeneratedSummaryShape.paddedValid => '  Generated summary $seed  ',
    GeneratedSummaryShape.empty => '   ',
    GeneratedSummaryShape.tooLong => 'x' * 501,
    GeneratedSummaryShape.nonString => seed,
  };

  Object? rawTime(GeneratedTimeArgShape shape, DateTime value) {
    final text = hFormatLocal(value);
    return switch (shape) {
      GeneratedTimeArgShape.absent => null,
      GeneratedTimeArgShape.valid => text,
      GeneratedTimeArgShape.paddedValid => ' $text ',
      GeneratedTimeArgShape.empty => '',
      GeneratedTimeArgShape.invalidType => seed,
      GeneratedTimeArgShape.timezone => '${text}Z',
      GeneratedTimeArgShape.invalidLocal => '2026-00-01T00:00:00',
    };
  }

  Map<String, dynamic> get args => {
    'entryId': 'entry-001',
    if (summaryShape != GeneratedSummaryShape.absent) 'summary': rawSummary,
    if (startShape != GeneratedTimeArgShape.absent)
      'startTime': rawTime(startShape, generatedStart),
    if (endShape != GeneratedTimeArgShape.absent)
      'endTime': rawTime(endShape, generatedEnd),
  };

  bool get hasNoChanges =>
      summaryShape == GeneratedSummaryShape.absent &&
      startShape == GeneratedTimeArgShape.absent &&
      endShape == GeneratedTimeArgShape.absent;

  bool get hasInvalidSummary => switch (summaryShape) {
    GeneratedSummaryShape.empty ||
    GeneratedSummaryShape.tooLong ||
    GeneratedSummaryShape.nonString => true,
    _ => false,
  };

  bool hasInvalidTime(GeneratedTimeArgShape shape) {
    return switch (shape) {
      GeneratedTimeArgShape.empty ||
      GeneratedTimeArgShape.invalidType ||
      GeneratedTimeArgShape.timezone ||
      GeneratedTimeArgShape.invalidLocal => true,
      _ => false,
    };
  }

  DateTime? parsedTime(GeneratedTimeArgShape shape, DateTime value) {
    return switch (shape) {
      GeneratedTimeArgShape.valid || GeneratedTimeArgShape.paddedValid => value,
      _ => null,
    };
  }

  DateTime? get parsedStart => parsedTime(startShape, generatedStart);
  DateTime? get parsedEnd => parsedTime(endShape, generatedEnd);

  DateTime get resolvedStart => parsedStart ?? existingStart;
  DateTime get resolvedEnd => parsedEnd ?? existingEnd;

  bool get hasInvalidRange => !resolvedEnd.isAfter(resolvedStart);

  bool get shouldAttemptWrite =>
      !hasNoChanges &&
      !hasInvalidSummary &&
      !hasInvalidTime(startShape) &&
      !hasInvalidTime(endShape) &&
      isLinked &&
      !isActiveTimer &&
      !hasInvalidRange;

  bool get shouldSucceed => shouldAttemptWrite && persistenceSucceeds;

  EntryText? get expectedEntryText {
    final summary = rawSummary;
    if (summary is! String) return null;
    return EntryText(plainText: '${summary.trim()} [generated]');
  }

  @override
  String toString() {
    return 'GeneratedTimeEntryUpdateScenario('
        'summaryShape: $summaryShape, '
        'startShape: $startShape, '
        'endShape: $endShape, '
        'isLinked: $isLinked, '
        'isActiveTimer: $isActiveTimer, '
        'persistenceSucceeds: $persistenceSucceeds, '
        'resolvedStart: $resolvedStart, '
        'resolvedEnd: $resolvedEnd)';
  }
}

extension AnyTimeEntryUpdateScenario on glados.Any {
  glados.Generator<GeneratedSummaryShape> get generatedSummaryShape =>
      glados.AnyUtils(this).choose(GeneratedSummaryShape.values);

  glados.Generator<GeneratedTimeArgShape> get generatedTimeArgShape =>
      glados.AnyUtils(this).choose(GeneratedTimeArgShape.values);

  glados.Generator<GeneratedTimeEntryUpdateScenario>
  get timeEntryUpdateScenario => glados.CombinableAny(this).combine7(
    generatedSummaryShape,
    generatedTimeArgShape,
    generatedTimeArgShape,
    glados.IntAnys(this).intInRange(0, 7),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    glados.IntAnys(this).intInRange(0, 10000),
    (
      GeneratedSummaryShape summaryShape,
      GeneratedTimeArgShape startShape,
      GeneratedTimeArgShape endShape,
      int flags,
      int startOffsetSeed,
      int endOffsetSeed,
      int seed,
    ) => GeneratedTimeEntryUpdateScenario(
      summaryShape: summaryShape,
      startShape: startShape,
      endShape: endShape,
      flags: flags,
      startOffsetSeed: startOffsetSeed,
      endOffsetSeed: endOffsetSeed,
      seed: seed,
    ),
  );
}

String hFormatLocal(DateTime value) {
  return '${hFourDigits(value.year)}-${hTwoDigits(value.month)}-'
      '${hTwoDigits(value.day)}T${hTwoDigits(value.hour)}:'
      '${hTwoDigits(value.minute)}:${hTwoDigits(value.second)}';
}

String hTwoDigits(int value) => value.toString().padLeft(2, '0');
String hFourDigits(int value) => value.toString().padLeft(4, '0');
