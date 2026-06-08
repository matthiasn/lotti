import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_text.dart';


enum GeneratedRunningSummaryShape {
  absent,
  valid,
  paddedValid,
  empty,
  tooLong,
  nonString,
}

enum GeneratedTimerIdShape {
  absent,
  exact,
  paddedExact,
  wrong,
  empty,
  nonString,
}

enum GeneratedCurrentTimerShape {
  none,
  journalMatchingId,
  journalDifferentId,
  measurementMatchingId,
}

enum GeneratedLinkedSourceShape { sameSource, otherSource, none }

class GeneratedRunningTimerUpdateScenario {
  const GeneratedRunningTimerUpdateScenario({
    required this.summaryShape,
    required this.timerIdShape,
    required this.currentShape,
    required this.linkedSourceShape,
    required this.persistenceSucceeds,
    required this.seed,
  });

  final GeneratedRunningSummaryShape summaryShape;
  final GeneratedTimerIdShape timerIdShape;
  final GeneratedCurrentTimerShape currentShape;
  final GeneratedLinkedSourceShape linkedSourceShape;
  final bool persistenceSucceeds;
  final int seed;

  Object? get rawSummary => switch (summaryShape) {
    GeneratedRunningSummaryShape.absent => null,
    GeneratedRunningSummaryShape.valid => 'Generated timer summary $seed',
    GeneratedRunningSummaryShape.paddedValid =>
      '  Generated timer summary $seed  ',
    GeneratedRunningSummaryShape.empty => '   ',
    GeneratedRunningSummaryShape.tooLong => 'x' * 501,
    GeneratedRunningSummaryShape.nonString => seed,
  };

  Object? get rawTimerId => switch (timerIdShape) {
    GeneratedTimerIdShape.absent => null,
    GeneratedTimerIdShape.exact => 'timer-entry-001',
    GeneratedTimerIdShape.paddedExact => ' timer-entry-001 ',
    GeneratedTimerIdShape.wrong => 'wrong-timer-$seed',
    GeneratedTimerIdShape.empty => '   ',
    GeneratedTimerIdShape.nonString => seed,
  };

  Map<String, dynamic> get args => {
    if (summaryShape != GeneratedRunningSummaryShape.absent)
      'summary': rawSummary,
    if (timerIdShape != GeneratedTimerIdShape.absent) 'timerId': rawTimerId,
  };

  String? get trimmedSummary {
    final summary = rawSummary;
    return summary is String ? summary.trim() : null;
  }

  String? get trimmedTimerId {
    final timerId = rawTimerId;
    return timerId is String ? timerId.trim() : null;
  }

  String get currentId => switch (currentShape) {
    GeneratedCurrentTimerShape.none => 'none',
    GeneratedCurrentTimerShape.journalMatchingId ||
    GeneratedCurrentTimerShape.measurementMatchingId => 'timer-entry-001',
    GeneratedCurrentTimerShape.journalDifferentId => 'active-other-$seed',
  };

  bool get hasInvalidSummary =>
      trimmedSummary == null ||
      trimmedSummary!.isEmpty ||
      trimmedSummary!.length > 500;

  bool get hasInvalidTimerId =>
      trimmedTimerId == null || trimmedTimerId!.isEmpty;

  bool get hasNoActiveTimer => currentShape == GeneratedCurrentTimerShape.none;

  bool get hasSourceMismatch =>
      linkedSourceShape != GeneratedLinkedSourceShape.sameSource;

  bool get hasTimerIdMismatch => currentId != trimmedTimerId;

  bool get hasUnsupportedCurrentEntity =>
      currentShape == GeneratedCurrentTimerShape.measurementMatchingId;

  bool get shouldAttemptPersist =>
      !hasInvalidSummary &&
      !hasInvalidTimerId &&
      !hasNoActiveTimer &&
      !hasSourceMismatch &&
      !hasTimerIdMismatch &&
      !hasUnsupportedCurrentEntity;

  bool get shouldSucceed => shouldAttemptPersist && persistenceSucceeds;

  EntryText get expectedEntryText => EntryText(
    plainText: '$trimmedSummary [generated]',
  );

  @override
  String toString() {
    return 'GeneratedRunningTimerUpdateScenario('
        'summaryShape: $summaryShape, '
        'timerIdShape: $timerIdShape, '
        'currentShape: $currentShape, '
        'linkedSourceShape: $linkedSourceShape, '
        'persistenceSucceeds: $persistenceSucceeds, '
        'currentId: $currentId)';
  }
}

extension AnyRunningTimerUpdateScenario on glados.Any {
  glados.Generator<GeneratedRunningSummaryShape>
  get generatedRunningSummaryShape =>
      glados.AnyUtils(this).choose(GeneratedRunningSummaryShape.values);

  glados.Generator<GeneratedTimerIdShape> get generatedTimerIdShape =>
      glados.AnyUtils(this).choose(GeneratedTimerIdShape.values);

  glados.Generator<GeneratedCurrentTimerShape> get generatedCurrentTimerShape =>
      glados.AnyUtils(this).choose(GeneratedCurrentTimerShape.values);

  glados.Generator<GeneratedLinkedSourceShape> get generatedLinkedSourceShape =>
      glados.AnyUtils(this).choose(GeneratedLinkedSourceShape.values);

  glados.Generator<GeneratedRunningTimerUpdateScenario>
  get runningTimerUpdateScenario => glados.CombinableAny(this).combine6(
    generatedRunningSummaryShape,
    generatedTimerIdShape,
    generatedCurrentTimerShape,
    generatedLinkedSourceShape,
    glados.BoolAny(this).bool,
    glados.IntAnys(this).intInRange(0, 10000),
    (
      GeneratedRunningSummaryShape summaryShape,
      GeneratedTimerIdShape timerIdShape,
      GeneratedCurrentTimerShape currentShape,
      GeneratedLinkedSourceShape linkedSourceShape,
      bool persistenceSucceeds,
      int seed,
    ) => GeneratedRunningTimerUpdateScenario(
      summaryShape: summaryShape,
      timerIdShape: timerIdShape,
      currentShape: currentShape,
      linkedSourceShape: linkedSourceShape,
      persistenceSucceeds: persistenceSucceeds,
      seed: seed,
    ),
  );
}
