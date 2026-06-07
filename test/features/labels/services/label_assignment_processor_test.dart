// ignore_for_file: avoid_redundant_argument_values, unnecessary_lambdas
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/labels/constants/label_assignment_constants.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_event_service.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/services/label_validator.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

// ---------------------------------------------------------------------------
// Top-level private helpers used only by edge_cases group
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Top-level helpers used by the category group
// ---------------------------------------------------------------------------

class FakeLabelsRepository extends Fake implements LabelsRepository {
  List<String> lastAdded = const [];
  @override
  Future<bool?> addLabels({
    required String journalEntityId,
    required List<String> addedLabelIds,
  }) async {
    lastAdded = List<String>.from(addedLabelIds);
    return true;
  }
}

// ---------------------------------------------------------------------------
// Top-level helpers for the phase2 / generated-scenario group
// ---------------------------------------------------------------------------

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
  // ---------------------------------------------------------------------------
  // Canonical tests (originally in label_assignment_processor_test.dart)
  // ---------------------------------------------------------------------------

  group('canonical', () {
    late MockJournalDb mockDb;
    late MockLabelsRepository mockRepo;
    late MockDomainLogger mockLogging;
    late LabelAssignmentProcessor processor;

    setUp(() {
      mockDb = MockJournalDb();
      mockRepo = MockLabelsRepository();
      mockLogging = MockDomainLogger();
      getIt.registerSingleton<LabelAssignmentEventService>(
        LabelAssignmentEventService(),
      );
      when(
        () => mockRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        ),
      ).thenAnswer((_) async => true);
      processor = LabelAssignmentProcessor(
        db: mockDb,
        repository: mockRepo,
        logging: mockLogging,
      );
    });

    tearDown(() {
      getIt.reset();
    });

    final testDate = DateTime(2024, 3, 15, 10, 30);
    final testDeletedDate = DateTime(2024, 3, 15, 11);

    LabelDefinition makeLabel(String id, {bool deleted = false}) =>
        LabelDefinition(
          id: id,
          name: id,
          color: '#000',
          description: null,
          sortOrder: null,
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
          private: false,
          deletedAt: deleted ? testDeletedDate : null,
        );

    test('assigns valid and filters invalid', () async {
      // existing contains p0 (ignored for exclusivity)
      when(
        () => mockDb.getLabelDefinitionById('p0'),
      ).thenAnswer((_) async => makeLabel('p0'));

      // proposed: p1 (same group) -> now allowed, bug (no group) -> assigned, del (deleted) -> invalid
      when(
        () => mockDb.getLabelDefinitionById('p1'),
      ).thenAnswer((_) async => makeLabel('p1'));
      when(
        () => mockDb.getLabelDefinitionById('bug'),
      ).thenAnswer((_) async => makeLabel('bug'));
      when(
        () => mockDb.getLabelDefinitionById('del'),
      ).thenAnswer((_) async => makeLabel('del', deleted: true));

      final result = await processor.processAssignment(
        taskId: 't1',
        proposedIds: const ['p1', 'bug', 'del'],
        existingIds: const ['p0'],
      );

      expect(result.assigned, containsAll(['bug', 'p1']));
      expect(result.invalid, contains('del'));
      verify(
        () => mockRepo.addLabels(
          journalEntityId: 't1',
          addedLabelIds: any(named: 'addedLabelIds'),
        ),
      ).called(1);
    });

    test('caps at maximum labels per assignment', () async {
      // Prepare 7 valid labels; only first 5 should be considered
      for (final id in const ['a', 'b', 'c', 'd', 'e', 'f', 'g']) {
        when(
          () => mockDb.getLabelDefinitionById(id),
        ).thenAnswer((_) async => makeLabel(id));
      }

      final result = await processor.processAssignment(
        taskId: 't1',
        proposedIds: const ['a', 'b', 'c', 'd', 'e', 'f', 'g'],
        existingIds: const [],
      );

      expect(result.assigned.length, lessThanOrEqualTo(5));
      verify(
        () => mockRepo.addLabels(
          journalEntityId: 't1',
          addedLabelIds: any(named: 'addedLabelIds'),
        ),
      ).called(1);
    });

    test('returns early for empty proposed list', () async {
      final result = await processor.processAssignment(
        taskId: 't1',
        proposedIds: const [],
        existingIds: const [],
      );

      expect(result.assigned, isEmpty);
      verifyNever(
        () => mockRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        ),
      );
    });
  }); // end canonical group

  // ---------------------------------------------------------------------------
  // Edge cases (originally in label_assignment_processor_edge_cases_test.dart)
  // ---------------------------------------------------------------------------

  group('edge_cases', () {
    late MockJournalDb mockDbEdge;
    late MockLabelsRepository mockRepoEdge;
    late MockDomainLogger mockLoggingEdge;
    late LabelAssignmentProcessor processorEdge;

    setUp(() {
      mockDbEdge = MockJournalDb();
      mockRepoEdge = MockLabelsRepository();
      mockLoggingEdge = MockDomainLogger();
      getIt.allowReassignment = true;
      getIt.registerSingleton<LabelAssignmentEventService>(
        LabelAssignmentEventService(),
      );
      processorEdge = LabelAssignmentProcessor(
        db: mockDbEdge,
        repository: mockRepoEdge,
        logging: mockLoggingEdge,
      );
    });

    tearDown(() async {
      await getIt.reset();
    });

    LabelDefinition makeLabelEdge(String id) => LabelDefinition(
      id: id,
      name: id,
      color: '#000',
      description: null,
      sortOrder: null,
      createdAt: DateTime(2024, 3, 15, 10, 30),
      updatedAt: DateTime(2024, 3, 15, 10, 30),
      vectorClock: null,
      private: false,
    );

    test(
      'concurrent assignments to same task do not duplicate labels',
      () async {
        when(
          () => mockDbEdge.getLabelDefinitionById('a'),
        ).thenAnswer((_) async => makeLabelEdge('a'));

        // Delay persistence to increase overlap
        when(
          () => mockRepoEdge.addLabels(
            journalEntityId: any(named: 'journalEntityId'),
            addedLabelIds: any(named: 'addedLabelIds'),
          ),
        ).thenAnswer((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return true;
        });

        // Fire two assignments nearly simultaneously
        final f1 = processorEdge.processAssignment(
          taskId: 't1',
          proposedIds: const ['a'],
          existingIds: const [],
        );
        final f2 = processorEdge.processAssignment(
          taskId: 't1',
          proposedIds: const ['a'],
          existingIds: const [],
        );

        final results = await Future.wait([f1, f2]);
        expect(results[0].assigned, ['a']);
        expect(results[1].assigned, ['a']);
        // Repository is called for both (current behavior), but labels API
        // remains de-duplicating internally.
        verify(
          () => mockRepoEdge.addLabels(
            journalEntityId: 't1',
            addedLabelIds: ['a'],
          ),
        ).called(2);
      },
    );

    test(
      'assignment when task is deleted mid-operation (persistence fails)',
      () async {
        when(
          () => mockDbEdge.getLabelDefinitionById('a'),
        ).thenAnswer((_) async => makeLabelEdge('a'));
        when(
          () => mockRepoEdge.addLabels(
            journalEntityId: any(named: 'journalEntityId'),
            addedLabelIds: any(named: 'addedLabelIds'),
          ),
        ).thenAnswer((_) async => false); // simulate deleted task

        final events = getIt<LabelAssignmentEventService>();
        final received = <LabelAssignmentEvent>[];
        final sub = events.stream.listen(received.add);

        final result = await processorEdge.processAssignment(
          taskId: 't1',
          proposedIds: const ['a'],
          existingIds: const [],
        );
        // Allow asynchronous stream delivery
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        // Even if persistence fails, current behavior still publishes an event
        expect(result.assigned, ['a']);
        expect(received.length, 1);
      },
    );

    test(
      'supports special characters in label IDs (spaces, unicode)',
      () async {
        for (final id in const ['with space', 'ünicode', 'emoji😀']) {
          when(
            () => mockDbEdge.getLabelDefinitionById(id),
          ).thenAnswer((_) async => makeLabelEdge(id));
        }
        when(
          () => mockRepoEdge.addLabels(
            journalEntityId: any(named: 'journalEntityId'),
            addedLabelIds: any(named: 'addedLabelIds'),
          ),
        ).thenAnswer((_) async => true);

        final result = await processorEdge.processAssignment(
          taskId: 't3',
          proposedIds: const ['with space', 'ünicode', 'emoji😀'],
          existingIds: const [],
        );

        expect(
          result.assigned,
          containsAll(['with space', 'ünicode', 'emoji😀']),
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Category scope tests (originally in services/label_assignment_processor_category_test.dart)
  // ---------------------------------------------------------------------------

  group('publish_skipped', () {
    late MockJournalDb mockDb;
    late MockLabelsRepository mockRepo;
    late MockDomainLogger mockLogging;
    late LabelAssignmentProcessor processor;

    setUp(() {
      mockDb = MockJournalDb();
      mockRepo = MockLabelsRepository();
      mockLogging = MockDomainLogger();
      when(
        () => mockRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        ),
      ).thenAnswer((_) async => true);
      processor = LabelAssignmentProcessor(
        db: mockDb,
        repository: mockRepo,
        logging: mockLogging,
      );
    });

    tearDown(() async {
      await getIt.reset();
    });

    LabelDefinition makeLabel(String id) => LabelDefinition(
      id: id,
      name: id,
      color: '#000',
      description: null,
      sortOrder: null,
      createdAt: DateTime(2024, 3, 15, 10, 30),
      updatedAt: DateTime(2024, 3, 15, 10, 30),
      vectorClock: null,
      private: false,
    );

    test(
      'assignment succeeds when no event service is registered '
      '(isRegistered guard)',
      () async {
        // No LabelAssignmentEventService in getIt at all.
        when(
          () => mockDb.getLabelDefinitionById('a'),
        ).thenAnswer((_) async => makeLabel('a'));

        final result = await processor.processAssignment(
          taskId: 't1',
          proposedIds: const ['a'],
          existingIds: const [],
        );

        expect(result.assigned, ['a']);
        verify(
          () => mockRepo.addLabels(
            journalEntityId: 't1',
            addedLabelIds: ['a'],
          ),
        ).called(1);
      },
    );

    test(
      'assignment succeeds and publish is silently dropped when the event '
      'service is already disposed (isClosed guard)',
      () async {
        final events = LabelAssignmentEventService();
        final received = <LabelAssignmentEvent>[];
        final sub = events.stream.listen(received.add);
        getIt.registerSingleton<LabelAssignmentEventService>(events);
        await events.dispose();

        when(
          () => mockDb.getLabelDefinitionById('a'),
        ).thenAnswer((_) async => makeLabel('a'));

        final result = await processor.processAssignment(
          taskId: 't1',
          proposedIds: const ['a'],
          existingIds: const [],
        );
        await pumpEventQueue();
        await sub.cancel();

        // Persistence happened; the closed event bus swallowed the publish.
        expect(result.assigned, ['a']);
        verify(
          () => mockRepo.addLabels(
            journalEntityId: 't1',
            addedLabelIds: ['a'],
          ),
        ).called(1);
        expect(received, isEmpty);
      },
    );
  });

  group('category_scope', () {
    setUp(() {
      getIt.allowReassignment = true;
    });

    test('processor skips out-of-scope labels and assigns in-scope', () async {
      TestWidgetsFlutterBinding.ensureInitialized();

      final db = MockJournalDb();
      final repo = FakeLabelsRepository();
      final logging = MockDomainLogger();
      final validator = LabelValidator(db: db);

      // Task with category cat1
      final task = JournalEntity.task(
        meta: Metadata(
          id: 't1',
          createdAt: DateTime(2025, 11, 4),
          updatedAt: DateTime(2025, 11, 4),
          dateFrom: DateTime(2025, 11, 4),
          dateTo: DateTime(2025, 11, 4),
          categoryId: 'cat1',
          labelIds: const [],
          utcOffset: 0,
          timezone: null,
          vectorClock: null,
          deletedAt: null,
          flag: null,
          starred: null,
          private: null,
        ),
        data: TaskData(
          status: TaskStatus.open(
            id: 's1',
            createdAt: DateTime(2025, 11, 4),
            utcOffset: 0,
          ),
          dateFrom: DateTime(2025, 11, 4),
          dateTo: DateTime(2025, 11, 4),
          statusHistory: const [],
          title: 'Task',
        ),
      );

      when(() => db.journalEntityById('t1')).thenAnswer((_) async => task);

      final now = DateTime(2025, 11, 4);
      final inScope = LabelDefinition(
        id: 'in',
        name: 'In',
        color: '#0f0',
        createdAt: now,
        updatedAt: now,
        vectorClock: null,
        applicableCategoryIds: const ['cat1'],
      );
      final outScope = inScope.copyWith(
        id: 'out',
        applicableCategoryIds: const ['other'],
      );

      when(
        () => db.getLabelDefinitionById('in'),
      ).thenAnswer((_) async => inScope);
      when(
        () => db.getLabelDefinitionById('out'),
      ).thenAnswer((_) async => outScope);
      when(
        db.getAllLabelDefinitions,
      ).thenAnswer((_) async => [inScope, outScope]);

      final categoryProcessor = LabelAssignmentProcessor(
        db: db,
        repository: repo,
        logging: logging,
        validator: validator,
      );

      final res = await categoryProcessor.processAssignment(
        taskId: 't1',
        proposedIds: const ['in', 'out'],
        existingIds: const [],
      );

      // Assign only in-scope; out-of-scope is skipped with reason
      expect(res.assigned, ['in']);
      expect(res.invalid, isEmpty);
      expect(
        res.skipped.any(
          (m) => m['id'] == 'out' && m['reason'] == 'out_of_scope',
        ),
        isTrue,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // DB error tests (originally in services/label_assignment_processor_db_error_test.dart)
  // ---------------------------------------------------------------------------

  group('db_error', () {
    setUp(() {
      getIt.allowReassignment = true;
    });

    test(
      'processAssignment handles DB error when fetching suppression',
      () async {
        final db = MockJournalDb();
        final repo = MockLabelsRepository();
        final log = MockDomainLogger();

        // Valid global label 'S'
        when(() => db.getLabelDefinitionById('S')).thenAnswer(
          (_) async => LabelDefinition(
            id: 'S',
            name: 'S',
            color: '#000',
            createdAt: DateTime(2024, 3, 15, 10, 30),
            updatedAt: DateTime(2024, 3, 15, 10, 30),
            vectorClock: null,
            private: false,
          ),
        );
        // Suppression lookup fails
        when(() => db.journalEntityById(any())).thenThrow(Exception('db'));

        when(
          () => repo.addLabels(
            journalEntityId: any<String>(named: 'journalEntityId'),
            addedLabelIds: any<List<String>>(named: 'addedLabelIds'),
          ),
        ).thenAnswer((_) async => true);

        final dbErrorProcessor = LabelAssignmentProcessor(
          db: db,
          repository: repo,
          logging: log,
          validator: LabelValidator(db: db),
        );

        final res = await dbErrorProcessor.processAssignment(
          taskId: 't',
          proposedIds: const ['S'],
          existingIds: const [],
          // omit categoryId (defaults to null)
        );

        // With suppression lookup failed, treat as not suppressed and assign
        expect(res.assigned, equals(['S']));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Telemetry tests (originally in services/label_assignment_telemetry_test.dart)
  // ---------------------------------------------------------------------------

  group('telemetry', () {
    late MockJournalDb mockDbTelemetry;
    late MockLabelsRepository mockRepoTelemetry;
    late MockDomainLogger mockLoggingTelemetry;
    late LabelAssignmentProcessor processorTelemetry;

    setUpAll(() {
      // Provide fallbacks for enums used in mocked method signatures
      registerFallbackValue(InsightLevel.info);
      registerFallbackValue(InsightType.log);
    });

    setUp(() {
      mockDbTelemetry = MockJournalDb();
      mockRepoTelemetry = MockLabelsRepository();
      mockLoggingTelemetry = MockDomainLogger();

      when(
        () => mockRepoTelemetry.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        ),
      ).thenAnswer((_) async => true);

      // Define all labels as valid global labels
      Future<LabelDefinition> def(String id) async => LabelDefinition(
        id: id,
        name: id,
        color: '#000',
        description: null,
        sortOrder: null,
        createdAt: DateTime(2024, 3, 15, 10, 30),
        updatedAt: DateTime(2024, 3, 15, 10, 30),
        vectorClock: null,
        private: false,
      );
      for (final id in const ['a', 'b', 'c', 'd']) {
        when(
          () => mockDbTelemetry.getLabelDefinitionById(id),
        ).thenAnswer((_) => def(id));
      }

      // Register mocks that LabelAssignmentProcessor may access indirectly
      getIt.allowReassignment = true;
      getIt
        ..registerSingleton<DomainLogger>(mockLoggingTelemetry)
        ..registerSingleton<JournalDb>(mockDbTelemetry);

      processorTelemetry = LabelAssignmentProcessor(
        db: mockDbTelemetry,
        repository: mockRepoTelemetry,
        logging: mockLoggingTelemetry,
      );
    });

    test(
      'processor telemetry includes dropped_low, legacy_capped and confidenceBreakdown',
      () async {
        // Act
        await processorTelemetry.processAssignment(
          taskId: 't1',
          proposedIds: const ['a', 'b', 'c'],
          existingIds: const [],
          // Phase 2 parser metrics
          droppedLow: 1,
          legacyUsed: true,
          totalCandidates: 5,
          confidenceBreakdown: const {
            'very_high': 0,
            'high': 2,
            'medium': 1,
            'low': 1,
          },
        );

        // Assert captureEvent was called with JSON containing the fields
        final captured = verify(
          () => mockLoggingTelemetry.log(
            any<LogDomain>(),
            captureAny<String>(),
            subDomain: captureAny(named: 'subDomain'),
            level: any(named: 'level'),
          ),
        ).captured;
        expect(captured, isNotEmpty);
        final message = captured.first as String;
        final telemetryData = jsonDecode(message) as Map<String, dynamic>;
        expect(telemetryData['dropped_low'], 1);
        expect(telemetryData['legacy_capped'], isTrue);
        final breakdown = Map<String, dynamic>.from(
          telemetryData['confidenceBreakdown'] as Map,
        );
        expect(breakdown['high'], 2);
        expect(breakdown['medium'], 1);
        expect(breakdown['low'], 1);
      },
    );

    tearDown(getIt.reset);
  });

  // ---------------------------------------------------------------------------
  // Phase 2 / generated scenario tests
  // (originally in services/label_assignment_processor_phase2_test.dart)
  // ---------------------------------------------------------------------------

  group('phase2_generated', () {
    setUpAll(() {
      registerFallbackValue(InsightLevel.info);
      registerFallbackValue(InsightType.log);
    });

    late MockLabelsRepository mockRepoPhase2;
    late MockDomainLogger mockLoggingPhase2;
    late MockJournalDb mockDbPhase2;
    late LabelAssignmentProcessor processorPhase2;

    setUp(() {
      mockRepoPhase2 = MockLabelsRepository();
      mockLoggingPhase2 = MockDomainLogger();
      mockDbPhase2 = MockJournalDb();
      getIt.allowReassignment = true;
      getIt.registerSingleton<LabelAssignmentEventService>(
        LabelAssignmentEventService(),
      );
      processorPhase2 = LabelAssignmentProcessor(
        db: mockDbPhase2,
        repository: mockRepoPhase2,
        logging: mockLoggingPhase2,
      );
    });

    tearDown(getIt.reset);

    test('short-circuits when task already has >=3 labels', () async {
      final result = await processorPhase2.processAssignment(
        taskId: 't1',
        proposedIds: const ['a', 'b'],
        existingIds: const ['e1', 'e2', 'e3'],
      );

      expect(result.assigned, isEmpty);
      expect(result.invalid, isEmpty);
      expect(result.skipped, isEmpty);
      verifyNever(
        () => mockRepoPhase2.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        ),
      );

      // Verify a max_total_reached event was logged with expected marker
      final logged = verify(
        () => mockLoggingPhase2.log(
          LogDomain.labels,
          captureAny<String>(),
          subDomain: 'processor',
          level: any<InsightLevel>(named: 'level'),
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
        final localLogging = MockDomainLogger();
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
          () => localLogging.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any<String?>(named: 'subDomain'),
            level: any<InsightLevel>(named: 'level'),
          ),
        ).thenAnswer((invocation) {
          final event = invocation.positionalArguments[1];
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
  });

  // ---------------------------------------------------------------------------
  // Suppression integration tests
  // (originally in services/label_assignment_processor_suppression_integration_test.dart)
  // ---------------------------------------------------------------------------

  group('suppression_integration', () {
    setUp(() {
      getIt.allowReassignment = true;
    });

    test(
      'processor integrates validator + suppression + repository correctly',
      () async {
        final db = MockJournalDb();
        final repo = MockLabelsRepository();
        final log = MockDomainLogger();

        // Task context
        const taskId = 't1';
        final testDateSupp = DateTime(2024, 3, 15, 10, 30);
        final task = Task(
          meta: Metadata(
            id: taskId,
            createdAt: testDateSupp,
            updatedAt: testDateSupp,
            dateFrom: testDateSupp,
            dateTo: testDateSupp,
            categoryId: 'engineering',
            labelIds: const ['A'], // already assigned
          ),
          data: TaskData(
            status: TaskStatus.open(
              id: 's',
              createdAt: testDateSupp,
              utcOffset: 0,
            ),
            dateFrom: testDateSupp,
            dateTo: testDateSupp,
            statusHistory: const [],
            title: 'Task',
            aiSuppressedLabelIds: const {'S'},
          ),
        );

        // DB lookups used by processor/validator
        when(() => db.journalEntityById(taskId)).thenAnswer((_) async => task);
        // Label defs
        LabelDefinition global(String id) => LabelDefinition(
          id: id,
          name: id,
          color: '#000',
          createdAt: testDateSupp,
          updatedAt: testDateSupp,
          vectorClock: null,
          private: false,
        );
        LabelDefinition engineeringOnly(String id) => LabelDefinition(
          id: id,
          name: id,
          color: '#000',
          createdAt: testDateSupp,
          updatedAt: testDateSupp,
          vectorClock: null,
          private: false,
          applicableCategoryIds: const ['engineering'],
        );

        // getLabelDefinitionById
        when(
          () => db.getLabelDefinitionById('A'),
        ).thenAnswer((_) async => global('A'));
        when(
          () => db.getLabelDefinitionById('S'),
        ).thenAnswer((_) async => global('S'));
        when(() => db.getLabelDefinitionById('D')).thenAnswer(
          (_) async => global('D').copyWith(deletedAt: testDateSupp),
        );
        when(() => db.getLabelDefinitionById('C')).thenAnswer(
          (_) async => LabelDefinition(
            id: 'C',
            name: 'C',
            color: '#000',
            createdAt: testDateSupp,
            updatedAt: testDateSupp,
            vectorClock: null,
            private: false,
            applicableCategoryIds: const ['design'], // out of scope
          ),
        );
        when(
          () => db.getLabelDefinitionById('G'),
        ).thenAnswer((_) async => engineeringOnly('G'));

        // getAllLabelDefinitions used for out_of_scope classification path
        when(() => db.getAllLabelDefinitions()).thenAnswer(
          (_) async => [
            global('A'),
            global('S'),
            global('D').copyWith(deletedAt: testDateSupp),
            engineeringOnly('G'),
            LabelDefinition(
              id: 'C',
              name: 'C',
              color: '#000',
              createdAt: testDateSupp,
              updatedAt: testDateSupp,
              vectorClock: null,
              private: false,
              applicableCategoryIds: const ['design'],
            ),
          ],
        );

        // Expect addLabels called only with the valid new id 'G'
        when(
          () => repo.addLabels(
            journalEntityId: any(named: 'journalEntityId'),
            addedLabelIds: any<List<String>>(named: 'addedLabelIds'),
          ),
        ).thenAnswer((_) async => true);

        // Capture telemetry
        final telemetry = <String>[];
        when(
          () => log.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((inv) {
          telemetry.add(inv.positionalArguments[1] as String);
        });

        final suppressionProcessor = LabelAssignmentProcessor(
          db: db,
          repository: repo,
          logging: log,
          validator: LabelValidator(db: db),
        );

        final result = await suppressionProcessor.processAssignment(
          taskId: taskId,
          // Mix of already assigned, suppressed, deleted, out-of-scope, and valid
          proposedIds: const ['A', 'S', 'D', 'C', 'G'],
          existingIds: const ['A'],
          categoryId: 'engineering',
        );

        // Assert result
        expect(result.assigned, equals(['G']));
        expect(result.invalid.toSet(), contains('D'));
        final skippedReasons = {
          for (final m in result.skipped) m['id']!: m['reason']!,
        };
        expect(skippedReasons['A'], 'already_assigned');
        expect(skippedReasons['S'], 'suppressed');
        expect(skippedReasons['C'], 'out_of_scope');

        // Persisted labels
        final captured = verify(
          () => repo.addLabels(
            journalEntityId: taskId,
            addedLabelIds: captureAny(named: 'addedLabelIds'),
          ),
        ).captured;
        final persisted = (captured.first as List).cast<String>();
        expect(persisted, equals(['G']));

        // Telemetry includes suppressed and out_of_scope counts
        expect(telemetry, isNotEmpty);
        final last = jsonDecode(telemetry.last) as Map<String, dynamic>;
        final skipped = last['skipped'] as Map<String, dynamic>;
        expect(skipped['suppressed'], 1);
        expect(skipped['out_of_scope'], 1);
        expect(last['assigned'], 1);
      },
    );
  });
}
