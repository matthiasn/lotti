import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/labels/constants/label_assignment_constants.dart';
import 'package:lotti/features/labels/services/label_assignment_event_service.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

enum _GeneratedProcessorRawShape { exact, padded, empty, whitespace }

enum _GeneratedProcessorLabelToken {
  globalA,
  globalB,
  globalC,
  scopedA,
  scopedB,
  existingA,
  existingB,
  existingC,
  suppressedA,
  suppressedB,
  outOfScopeA,
  outOfScopeB,
  deletedA,
  unknownA,
}

class _GeneratedProcessorCandidate {
  const _GeneratedProcessorCandidate({
    required this.token,
    required this.rawShape,
  });

  final _GeneratedProcessorLabelToken token;
  final _GeneratedProcessorRawShape rawShape;

  String get id => switch (token) {
    _GeneratedProcessorLabelToken.globalA => 'global_a',
    _GeneratedProcessorLabelToken.globalB => 'global_b',
    _GeneratedProcessorLabelToken.globalC => 'global_c',
    _GeneratedProcessorLabelToken.scopedA => 'scoped_a',
    _GeneratedProcessorLabelToken.scopedB => 'scoped_b',
    _GeneratedProcessorLabelToken.existingA => 'existing_a',
    _GeneratedProcessorLabelToken.existingB => 'existing_b',
    _GeneratedProcessorLabelToken.existingC => 'existing_c',
    _GeneratedProcessorLabelToken.suppressedA => 'suppressed_a',
    _GeneratedProcessorLabelToken.suppressedB => 'suppressed_b',
    _GeneratedProcessorLabelToken.outOfScopeA => 'out_of_scope_a',
    _GeneratedProcessorLabelToken.outOfScopeB => 'out_of_scope_b',
    _GeneratedProcessorLabelToken.deletedA => 'deleted_a',
    _GeneratedProcessorLabelToken.unknownA => 'unknown_a',
  };

  String get raw => switch (rawShape) {
    _GeneratedProcessorRawShape.exact => id,
    _GeneratedProcessorRawShape.padded => '  $id  ',
    _GeneratedProcessorRawShape.empty => '',
    _GeneratedProcessorRawShape.whitespace => ' \n\t ',
  };

  @override
  String toString() {
    return '_GeneratedProcessorCandidate('
        'token: $token, rawShape: $rawShape, id: $id)';
  }
}

class _GeneratedProcessorScenario {
  const _GeneratedProcessorScenario({
    required this.candidates,
    required this.existingCount,
    required this.flags,
    required this.droppedLow,
    required this.totalCandidates,
    required this.confidenceSeed,
  });

  static const taskId = 'generated-task';
  static const categoryId = 'engineering';
  static const existingUniverse = ['existing_a', 'existing_b', 'existing_c'];
  static const suppressedIds = {'suppressed_a', 'suppressed_b'};

  final List<_GeneratedProcessorCandidate> candidates;
  final int existingCount;
  final int flags;
  final int droppedLow;
  final int totalCandidates;
  final int confidenceSeed;

  bool get passCategoryDirectly => flags.isOdd;
  bool get legacyUsed => flags & 2 != 0;
  bool get includeConfidenceBreakdown => flags & 4 != 0;

  List<String> get proposedIds => [
    for (final candidate in candidates) candidate.raw,
  ];

  List<String> get existingIds =>
      existingUniverse.take(existingCount).toList(growable: false);

  List<String> get normalized => proposedIds
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);

  Set<String> get duplicateIds {
    final counts = <String, int>{};
    for (final id in normalized) {
      counts.update(id, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts.entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toSet();
  }

  List<String> get dedupedOrder {
    final seen = <String>{};
    return [
      for (final id in normalized)
        if (seen.add(id)) id,
    ];
  }

  List<String> get base =>
      dedupedOrder.take(kMaxLabelsPerAssignment).toList(growable: false);

  List<String> get overCap => dedupedOrder.length > kMaxLabelsPerAssignment
      ? dedupedOrder.sublist(kMaxLabelsPerAssignment)
      : const [];

  List<String> get alreadyAssigned {
    final existingSet = existingIds.toSet();
    return base.where(existingSet.contains).toList(growable: false);
  }

  List<String> get requested {
    final existingSet = existingIds.toSet();
    return base
        .where((id) => !existingSet.contains(id))
        .toList(growable: false);
  }

  bool get hasMaxExistingLabels => existingIds.length >= 3;
  bool get returnsBeforeValidation => hasMaxExistingLabels || requested.isEmpty;

  List<String> get assigned => [
    for (final id in requested)
      if (_isAssignable(id)) id,
  ];

  List<String> get outOfScope => [
    for (final id in requested)
      if (_isOutOfScope(id)) id,
  ];

  List<String> get invalid => [
    for (final id in requested)
      if (_isUnknown(id) || _isDeleted(id)) id,
  ];

  List<String> get suppressed => [
    for (final id in requested)
      if (_isSuppressed(id)) id,
  ];

  List<Map<String, String>> get skipped {
    final skipReasons = <String, String>{};
    for (final id in alreadyAssigned) {
      skipReasons[id] = 'already_assigned';
    }
    for (final id in overCap) {
      skipReasons.putIfAbsent(id, () => 'over_cap');
    }
    for (final id in duplicateIds) {
      skipReasons.putIfAbsent(id, () => 'duplicate');
    }

    return [
      for (final id in outOfScope) {'id': id, 'reason': 'out_of_scope'},
      for (final id in suppressed) {'id': id, 'reason': 'suppressed'},
      for (final entry in skipReasons.entries)
        {'id': entry.key, 'reason': entry.value},
    ];
  }

  Map<String, int>? get confidenceBreakdown {
    if (!includeConfidenceBreakdown) return null;
    return {
      'high': confidenceSeed % 4,
      'medium': (confidenceSeed ~/ 2) % 4,
      'low': (confidenceSeed ~/ 3) % 4,
    };
  }

  bool _isAssignable(String id) {
    return _isKnownActive(id) && !_isOutOfScope(id) && !_isSuppressed(id);
  }

  bool _isKnownActive(String id) {
    return _labelDefinitionsById[id] != null && !_isDeleted(id);
  }

  bool _isDeleted(String id) => id == 'deleted_a';

  bool _isUnknown(String id) => id == 'unknown_a';

  bool _isOutOfScope(String id) =>
      id == 'out_of_scope_a' || id == 'out_of_scope_b';

  bool _isSuppressed(String id) => suppressedIds.contains(id);

  @override
  String toString() {
    return '_GeneratedProcessorScenario('
        'candidates: $candidates, '
        'existingIds: $existingIds, '
        'passCategoryDirectly: $passCategoryDirectly, '
        'legacyUsed: $legacyUsed, '
        'droppedLow: $droppedLow, '
        'totalCandidates: $totalCandidates, '
        'confidenceBreakdown: $confidenceBreakdown)';
  }
}

extension _AnyGeneratedProcessorScenario on glados.Any {
  glados.Generator<_GeneratedProcessorRawShape> get processorRawShape =>
      glados.AnyUtils(this).choose(_GeneratedProcessorRawShape.values);

  glados.Generator<_GeneratedProcessorLabelToken> get processorLabelToken =>
      glados.AnyUtils(this).choose(_GeneratedProcessorLabelToken.values);

  glados.Generator<_GeneratedProcessorCandidate> get processorCandidate =>
      glados.CombinableAny(this).combine2(
        processorLabelToken,
        processorRawShape,
        (
          _GeneratedProcessorLabelToken token,
          _GeneratedProcessorRawShape rawShape,
        ) => _GeneratedProcessorCandidate(
          token: token,
          rawShape: rawShape,
        ),
      );

  glados.Generator<List<_GeneratedProcessorCandidate>>
  get processorCandidates => glados.ListAnys(
    this,
  ).listWithLengthInRange(0, 9, processorCandidate);

  glados.Generator<_GeneratedProcessorScenario> get processorScenario =>
      glados.CombinableAny(this).combine6(
        processorCandidates,
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 7),
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 8),
        glados.IntAnys(this).intInRange(0, 99),
        (
          List<_GeneratedProcessorCandidate> candidates,
          int existingCount,
          int flags,
          int droppedLow,
          int totalCandidates,
          int confidenceSeed,
        ) => _GeneratedProcessorScenario(
          candidates: candidates,
          existingCount: existingCount,
          flags: flags,
          droppedLow: droppedLow,
          totalCandidates: totalCandidates,
          confidenceSeed: confidenceSeed,
        ),
      );
}

final _testDate = DateTime(2024, 3, 15, 10, 30);

final _labelDefinitionsById = <String, LabelDefinition>{
  'global_a': _labelDefinition('global_a'),
  'global_b': _labelDefinition('global_b'),
  'global_c': _labelDefinition('global_c'),
  'scoped_a': _labelDefinition(
    'scoped_a',
    applicableCategoryIds: const [_GeneratedProcessorScenario.categoryId],
  ),
  'scoped_b': _labelDefinition(
    'scoped_b',
    applicableCategoryIds: const [_GeneratedProcessorScenario.categoryId],
  ),
  'existing_a': _labelDefinition('existing_a'),
  'existing_b': _labelDefinition('existing_b'),
  'existing_c': _labelDefinition('existing_c'),
  'suppressed_a': _labelDefinition('suppressed_a'),
  'suppressed_b': _labelDefinition('suppressed_b'),
  'out_of_scope_a': _labelDefinition(
    'out_of_scope_a',
    applicableCategoryIds: const ['design'],
  ),
  'out_of_scope_b': _labelDefinition(
    'out_of_scope_b',
    applicableCategoryIds: const ['design'],
  ),
  'deleted_a': _labelDefinition('deleted_a', deletedAt: _testDate),
};

LabelDefinition _labelDefinition(
  String id, {
  List<String>? applicableCategoryIds,
  DateTime? deletedAt,
}) {
  return LabelDefinition(
    id: id,
    name: id,
    color: '#000',
    createdAt: _testDate,
    updatedAt: _testDate,
    vectorClock: null,
    private: false,
    applicableCategoryIds: applicableCategoryIds,
    deletedAt: deletedAt,
  );
}

Task _taskForGeneratedProcessorScenario(_GeneratedProcessorScenario scenario) {
  return Task(
    meta: Metadata(
      id: _GeneratedProcessorScenario.taskId,
      createdAt: _testDate,
      updatedAt: _testDate,
      dateFrom: _testDate,
      dateTo: _testDate,
      categoryId: _GeneratedProcessorScenario.categoryId,
      labelIds: scenario.existingIds,
    ),
    data: TaskData(
      status: TaskStatus.open(
        id: 'status-generated',
        createdAt: _testDate,
        utcOffset: 0,
      ),
      dateFrom: _testDate,
      dateTo: _testDate,
      statusHistory: const [],
      title: 'Generated processor task',
      aiSuppressedLabelIds: _GeneratedProcessorScenario.suppressedIds,
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(InsightLevel.info);
    registerFallbackValue(InsightType.log);
  });
  late MockLabelsRepository mockRepo;
  late MockLoggingService mockLogging;
  late MockJournalDb mockDb;
  late LabelAssignmentProcessor processor;

  setUp(() {
    mockRepo = MockLabelsRepository();
    mockLogging = MockLoggingService();
    mockDb = MockJournalDb();
    getIt.registerSingleton<LabelAssignmentEventService>(
      LabelAssignmentEventService(),
    );
    processor = LabelAssignmentProcessor(
      db: mockDb,
      repository: mockRepo,
      logging: mockLogging,
    );
  });

  tearDown(getIt.reset);

  test('short-circuits when task already has >=3 labels', () async {
    final result = await processor.processAssignment(
      taskId: 't1',
      proposedIds: const ['a', 'b'],
      existingIds: const ['e1', 'e2', 'e3'],
    );

    expect(result.assigned, isEmpty);
    expect(result.invalid, isEmpty);
    expect(result.skipped, isEmpty);
    verifyNever(
      () => mockRepo.addLabels(
        journalEntityId: any(named: 'journalEntityId'),
        addedLabelIds: any(named: 'addedLabelIds'),
      ),
    );

    // Verify a max_total_reached event was logged with expected marker
    final logged = verify(
      () => mockLogging.captureEvent(
        captureAny<dynamic>(),
        domain: 'labels_ai_assignment',
        subDomain: 'processor',
        level: any<InsightLevel>(named: 'level'),
        type: any<InsightType>(named: 'type'),
      ),
    ).captured;
    expect(logged, isNotEmpty);
    final message = logged.first.toString();
    expect(message, contains('max_total_reached'));
  });

  glados.Glados(
    glados.any.processorScenario,
    glados.ExploreConfig(numRuns: 260),
  ).test(
    'matches generated normalization, validation, telemetry, and persistence semantics',
    (scenario) async {
      final localDb = MockJournalDb();
      final localRepo = MockLabelsRepository();
      final localLogging = MockLoggingService();
      final localProcessor = LabelAssignmentProcessor(
        db: localDb,
        repository: localRepo,
        logging: localLogging,
      );
      final telemetry = <String>[];
      final maxTotalEvents = <dynamic>[];

      when(
        () => localDb.journalEntityById(_GeneratedProcessorScenario.taskId),
      ).thenAnswer((_) async => _taskForGeneratedProcessorScenario(scenario));
      when(() => localDb.getLabelDefinitionById(any())).thenAnswer(
        (invocation) async {
          final id = invocation.positionalArguments.first as String;
          return _labelDefinitionsById[id];
        },
      );
      when(localDb.getAllLabelDefinitions).thenAnswer(
        (_) async => _labelDefinitionsById.values.toList(growable: false),
      );
      when(
        () => localRepo.addLabels(
          journalEntityId: any<String>(named: 'journalEntityId'),
          addedLabelIds: any<List<String>>(named: 'addedLabelIds'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => localLogging.captureEvent(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
          level: any<InsightLevel>(named: 'level'),
          type: any<InsightType>(named: 'type'),
        ),
      ).thenAnswer((invocation) {
        final event = invocation.positionalArguments.first;
        if (event is String && event.startsWith('{')) {
          telemetry.add(event);
        } else {
          maxTotalEvents.add(event);
        }
      });

      final result = await localProcessor.processAssignment(
        taskId: _GeneratedProcessorScenario.taskId,
        proposedIds: scenario.proposedIds,
        existingIds: scenario.existingIds,
        categoryId: scenario.passCategoryDirectly
            ? _GeneratedProcessorScenario.categoryId
            : null,
        droppedLow: scenario.droppedLow,
        legacyUsed: scenario.legacyUsed,
        totalCandidates: scenario.totalCandidates,
        confidenceBreakdown: scenario.confidenceBreakdown,
      );

      if (scenario.returnsBeforeValidation) {
        expect(result.assigned, isEmpty, reason: '$scenario');
        expect(result.invalid, isEmpty, reason: '$scenario');
        expect(result.skipped, isEmpty, reason: '$scenario');
        expect(telemetry, isEmpty, reason: '$scenario');
        if (scenario.hasMaxExistingLabels) {
          expect(
            maxTotalEvents.single.toString(),
            contains('max_total_reached'),
          );
        } else {
          expect(maxTotalEvents, isEmpty, reason: '$scenario');
        }
        verifyNever(
          () => localRepo.addLabels(
            journalEntityId: any(named: 'journalEntityId'),
            addedLabelIds: any(named: 'addedLabelIds'),
          ),
        );
        return;
      }

      expect(result.assigned, scenario.assigned, reason: '$scenario');
      expect(result.invalid, scenario.invalid, reason: '$scenario');
      expect(result.skipped, scenario.skipped, reason: '$scenario');
      expect(maxTotalEvents, isEmpty, reason: '$scenario');

      if (scenario.assigned.isEmpty) {
        verifyNever(
          () => localRepo.addLabels(
            journalEntityId: any(named: 'journalEntityId'),
            addedLabelIds: any(named: 'addedLabelIds'),
          ),
        );
      } else {
        verify(
          () => localRepo.addLabels(
            journalEntityId: _GeneratedProcessorScenario.taskId,
            addedLabelIds: scenario.assigned,
          ),
        ).called(1);
      }

      expect(telemetry, hasLength(1), reason: '$scenario');
      final decoded = jsonDecode(telemetry.single) as Map<String, dynamic>;
      expect(decoded['taskId'], _GeneratedProcessorScenario.taskId);
      expect(decoded['attempted'], scenario.requested.length);
      expect(decoded['assigned'], scenario.assigned.length);
      expect(decoded['invalid'], scenario.invalid.length);
      expect(decoded['dropped_low'], scenario.droppedLow);
      expect(
        decoded['legacy_capped'],
        scenario.legacyUsed && scenario.totalCandidates > 3,
      );
      expect(decoded['phase'], 2);
      if (scenario.confidenceBreakdown == null) {
        expect(decoded.containsKey('confidenceBreakdown'), isFalse);
      } else {
        expect(
          Map<String, dynamic>.from(decoded['confidenceBreakdown'] as Map),
          scenario.confidenceBreakdown,
        );
      }

      final skippedTelemetry = decoded['skipped'] as Map<String, dynamic>;
      expect(skippedTelemetry['out_of_scope'], scenario.outOfScope.length);
      expect(skippedTelemetry['suppressed'], scenario.suppressed.length);
      expect(
        skippedTelemetry['already_assigned'],
        scenario.alreadyAssigned.length,
      );
      expect(skippedTelemetry['over_cap'], scenario.overCap.length);
      expect(skippedTelemetry['duplicate'], scenario.duplicateIds.length);
    },
    tags: 'glados',
  );
}
