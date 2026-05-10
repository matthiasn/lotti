import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/task_label_handler.dart';
import 'package:lotti/features/labels/services/label_assignment_processor.dart';
import 'package:lotti/features/labels/utils/label_tool_parsing.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';

enum _GeneratedLabelPayloadShape {
  structured,
  legacyList,
  legacyString,
  neither,
}

enum _GeneratedHandlerLabelIdShape {
  valid,
  padded,
  empty,
  missing,
}

enum _GeneratedHandlerConfidenceShape {
  veryHigh,
  high,
  medium,
  low,
  unknown,
  missing,
}

class _GeneratedHandlerLabelItem {
  const _GeneratedHandlerLabelItem({
    required this.idShape,
    required this.confidenceShape,
    required this.value,
  });

  final _GeneratedHandlerLabelIdShape idShape;
  final _GeneratedHandlerConfidenceShape confidenceShape;
  final int value;

  String get id => 'label-$value';

  Object get structuredRaw {
    final raw = <String, dynamic>{};
    switch (idShape) {
      case _GeneratedHandlerLabelIdShape.valid:
        raw['id'] = id;
      case _GeneratedHandlerLabelIdShape.padded:
        raw['id'] = '  $id  ';
      case _GeneratedHandlerLabelIdShape.empty:
        raw['id'] = '   ';
      case _GeneratedHandlerLabelIdShape.missing:
        break;
    }

    switch (confidenceShape) {
      case _GeneratedHandlerConfidenceShape.veryHigh:
        raw['confidence'] = 'very_high';
      case _GeneratedHandlerConfidenceShape.high:
        raw['confidence'] = 'high';
      case _GeneratedHandlerConfidenceShape.medium:
        raw['confidence'] = 'medium';
      case _GeneratedHandlerConfidenceShape.low:
        raw['confidence'] = 'low';
      case _GeneratedHandlerConfidenceShape.unknown:
        raw['confidence'] = 'unexpected';
      case _GeneratedHandlerConfidenceShape.missing:
        break;
    }

    return raw;
  }

  String get legacyRaw => switch (idShape) {
    _GeneratedHandlerLabelIdShape.valid => id,
    _GeneratedHandlerLabelIdShape.padded => '  $id  ',
    _GeneratedHandlerLabelIdShape.empty => '   ',
    _GeneratedHandlerLabelIdShape.missing => '',
  };
}

class _GeneratedTaskLabelHandlerScenario {
  const _GeneratedTaskLabelHandlerScenario({
    required this.payloadShape,
    required this.items,
    required this.existingCount,
    required this.assignedCountSeed,
  });

  final _GeneratedLabelPayloadShape payloadShape;
  final List<_GeneratedHandlerLabelItem> items;
  final int existingCount;
  final int assignedCountSeed;

  Map<String, dynamic> get args => switch (payloadShape) {
    _GeneratedLabelPayloadShape.structured => {
      'labels': items.map((item) => item.structuredRaw).toList(),
      'labelIds': ['legacy-ignored'],
    },
    _GeneratedLabelPayloadShape.legacyList => {
      'labelIds': items.map((item) => item.legacyRaw).toList(),
    },
    _GeneratedLabelPayloadShape.legacyString => {
      'labelIds': items.map((item) => item.legacyRaw).join(', '),
    },
    _GeneratedLabelPayloadShape.neither => {'unrelated': 'value'},
  };

  List<String> get existingIds => List.generate(
    existingCount,
    (index) => 'existing-$index',
  );

  bool get hasMaxExistingLabels => existingCount >= 3;

  LabelCallParseResult get parseResult => parseLabelCallArgs(jsonEncode(args));

  bool get shouldCallProcessor =>
      !hasMaxExistingLabels && parseResult.selectedIds.isNotEmpty;

  List<String> get assignedByProcessor {
    final selected = parseResult.selectedIds;
    if (selected.isEmpty) return const [];
    final count = assignedCountSeed % (selected.length + 1);
    return selected.take(count).toList(growable: false);
  }

  @override
  String toString() {
    return '_GeneratedTaskLabelHandlerScenario('
        'payloadShape: $payloadShape, '
        'itemCount: ${items.length}, '
        'existingCount: $existingCount, '
        'selectedIds: ${parseResult.selectedIds}, '
        'assignedByProcessor: $assignedByProcessor)';
  }
}

extension _AnyTaskLabelHandlerScenario on glados.Any {
  glados.Generator<_GeneratedLabelPayloadShape> get labelPayloadShape =>
      glados.AnyUtils(this).choose(_GeneratedLabelPayloadShape.values);

  glados.Generator<_GeneratedHandlerLabelIdShape> get handlerLabelIdShape =>
      glados.AnyUtils(this).choose(_GeneratedHandlerLabelIdShape.values);

  glados.Generator<_GeneratedHandlerConfidenceShape>
  get handlerConfidenceShape =>
      glados.AnyUtils(this).choose(_GeneratedHandlerConfidenceShape.values);

  glados.Generator<_GeneratedHandlerLabelItem> get handlerLabelItem =>
      glados.CombinableAny(this).combine3(
        handlerLabelIdShape,
        handlerConfidenceShape,
        glados.IntAnys(this).intInRange(0, 1000),
        (
          _GeneratedHandlerLabelIdShape idShape,
          _GeneratedHandlerConfidenceShape confidenceShape,
          int value,
        ) => _GeneratedHandlerLabelItem(
          idShape: idShape,
          confidenceShape: confidenceShape,
          value: value,
        ),
      );

  glados.Generator<List<_GeneratedHandlerLabelItem>> get handlerLabelItems =>
      glados.ListAnys(
        this,
      ).listWithLengthInRange(0, 8, handlerLabelItem);

  glados.Generator<_GeneratedTaskLabelHandlerScenario>
  get taskLabelHandlerScenario => glados.CombinableAny(this).combine4(
    labelPayloadShape,
    handlerLabelItems,
    glados.IntAnys(this).intInRange(0, 4),
    glados.IntAnys(this).intInRange(0, 1000),
    (
      _GeneratedLabelPayloadShape payloadShape,
      List<_GeneratedHandlerLabelItem> items,
      int existingCount,
      int assignedCountSeed,
    ) => _GeneratedTaskLabelHandlerScenario(
      payloadShape: payloadShape,
      items: items,
      existingCount: existingCount,
      assignedCountSeed: assignedCountSeed,
    ),
  );
}

void main() {
  late MockLabelAssignmentProcessor mockProcessor;
  late Task task;

  setUp(() {
    mockProcessor = MockLabelAssignmentProcessor();
    task = testTask.copyWith(
      meta: testTask.meta.copyWith(
        labelIds: null,
        categoryId: 'cat-1',
      ),
    );
  });

  group('TaskLabelHandler', () {
    group('handle', () {
      test('assigns labels and returns success with didWrite=true', () async {
        when(
          () => mockProcessor.processAssignment(
            taskId: any(named: 'taskId'),
            proposedIds: any(named: 'proposedIds'),
            existingIds: any(named: 'existingIds'),
            categoryId: any(named: 'categoryId'),
            droppedLow: any(named: 'droppedLow'),
            legacyUsed: any(named: 'legacyUsed'),
            confidenceBreakdown: any(named: 'confidenceBreakdown'),
            totalCandidates: any(named: 'totalCandidates'),
          ),
        ).thenAnswer(
          (_) async => LabelAssignmentResult(
            assigned: ['label-a', 'label-b'],
            invalid: const [],
            skipped: const [],
          ),
        );

        final handler = TaskLabelHandler(
          task: task,
          processor: mockProcessor,
        );

        final result = await handler.handle({
          'labels': [
            {'id': 'label-a', 'confidence': 'very_high'},
            {'id': 'label-b', 'confidence': 'high'},
          ],
        });

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);
        expect(result.wasNoOp, isFalse);
        expect(result.assigned, equals(['label-a', 'label-b']));
        expect(result.error, isNull);

        verify(
          () => mockProcessor.processAssignment(
            taskId: task.meta.id,
            proposedIds: any(named: 'proposedIds'),
            existingIds: any(named: 'existingIds'),
            categoryId: 'cat-1',
            droppedLow: any(named: 'droppedLow'),
            confidenceBreakdown: any(named: 'confidenceBreakdown'),
            totalCandidates: any(named: 'totalCandidates'),
          ),
        ).called(1);
      });

      test('returns no-op when task already has >= 3 labels', () async {
        final taskWith3Labels = task.copyWith(
          meta: task.meta.copyWith(
            labelIds: ['l1', 'l2', 'l3'],
          ),
        );

        final handler = TaskLabelHandler(
          task: taskWith3Labels,
          processor: mockProcessor,
        );

        final result = await handler.handle({
          'labels': [
            {'id': 'label-a', 'confidence': 'high'},
          ],
        });

        expect(result.success, isTrue);
        expect(result.didWrite, isFalse);
        expect(result.wasNoOp, isTrue);
        expect(result.message, contains('3 or more labels'));

        verifyNever(
          () => mockProcessor.processAssignment(
            taskId: any(named: 'taskId'),
            proposedIds: any(named: 'proposedIds'),
            existingIds: any(named: 'existingIds'),
          ),
        );
      });

      test('drops low confidence labels during parsing', () async {
        when(
          () => mockProcessor.processAssignment(
            taskId: any(named: 'taskId'),
            proposedIds: any(named: 'proposedIds'),
            existingIds: any(named: 'existingIds'),
            categoryId: any(named: 'categoryId'),
            droppedLow: any(named: 'droppedLow'),
            legacyUsed: any(named: 'legacyUsed'),
            confidenceBreakdown: any(named: 'confidenceBreakdown'),
            totalCandidates: any(named: 'totalCandidates'),
          ),
        ).thenAnswer(
          (_) async => LabelAssignmentResult(
            assigned: ['label-a'],
            invalid: const [],
            skipped: const [],
          ),
        );

        final handler = TaskLabelHandler(
          task: task,
          processor: mockProcessor,
        );

        final result = await handler.handle({
          'labels': [
            {'id': 'label-a', 'confidence': 'high'},
            {'id': 'label-low', 'confidence': 'low'},
          ],
        });

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);

        // Verify only label-a was passed (label-low dropped by parser).
        final captured = verify(
          () => mockProcessor.processAssignment(
            taskId: any(named: 'taskId'),
            proposedIds: captureAny(named: 'proposedIds'),
            existingIds: any(named: 'existingIds'),
            categoryId: any(named: 'categoryId'),
            droppedLow: 1,
            legacyUsed: any(named: 'legacyUsed'),
            confidenceBreakdown: any(named: 'confidenceBreakdown'),
            totalCandidates: any(named: 'totalCandidates'),
          ),
        ).captured;
        expect(captured.single, equals(['label-a']));
      });

      test('returns no-op when all labels are low confidence', () async {
        final handler = TaskLabelHandler(
          task: task,
          processor: mockProcessor,
        );

        final result = await handler.handle({
          'labels': [
            {'id': 'label-a', 'confidence': 'low'},
            {'id': 'label-b', 'confidence': 'low'},
          ],
        });

        expect(result.success, isTrue);
        expect(result.didWrite, isFalse);
        expect(result.wasNoOp, isTrue);
        expect(result.message, contains('No valid labels'));

        verifyNever(
          () => mockProcessor.processAssignment(
            taskId: any(named: 'taskId'),
            proposedIds: any(named: 'proposedIds'),
            existingIds: any(named: 'existingIds'),
          ),
        );
      });

      test('returns no-op when labels array is empty', () async {
        final handler = TaskLabelHandler(
          task: task,
          processor: mockProcessor,
        );

        final result = await handler.handle({
          'labels': <Map<String, dynamic>>[],
        });

        expect(result.success, isTrue);
        expect(result.didWrite, isFalse);
        expect(result.wasNoOp, isTrue);
      });

      test('handles processor exception', () async {
        when(
          () => mockProcessor.processAssignment(
            taskId: any(named: 'taskId'),
            proposedIds: any(named: 'proposedIds'),
            existingIds: any(named: 'existingIds'),
            categoryId: any(named: 'categoryId'),
            droppedLow: any(named: 'droppedLow'),
            legacyUsed: any(named: 'legacyUsed'),
            confidenceBreakdown: any(named: 'confidenceBreakdown'),
            totalCandidates: any(named: 'totalCandidates'),
          ),
        ).thenThrow(Exception('DB error'));

        final handler = TaskLabelHandler(
          task: task,
          processor: mockProcessor,
        );

        final result = await handler.handle({
          'labels': [
            {'id': 'label-a', 'confidence': 'high'},
          ],
        });

        expect(result.success, isFalse);
        expect(result.didWrite, isFalse);
        expect(result.error, contains('DB error'));
      });

      test('passes existing label IDs to processor', () async {
        final taskWithLabels = task.copyWith(
          meta: task.meta.copyWith(
            labelIds: ['existing-1', 'existing-2'],
          ),
        );

        when(
          () => mockProcessor.processAssignment(
            taskId: any(named: 'taskId'),
            proposedIds: any(named: 'proposedIds'),
            existingIds: any(named: 'existingIds'),
            categoryId: any(named: 'categoryId'),
            droppedLow: any(named: 'droppedLow'),
            legacyUsed: any(named: 'legacyUsed'),
            confidenceBreakdown: any(named: 'confidenceBreakdown'),
            totalCandidates: any(named: 'totalCandidates'),
          ),
        ).thenAnswer(
          (_) async => LabelAssignmentResult(
            assigned: ['label-a'],
            invalid: const [],
            skipped: const [],
          ),
        );

        final handler = TaskLabelHandler(
          task: taskWithLabels,
          processor: mockProcessor,
        );

        await handler.handle({
          'labels': [
            {'id': 'label-a', 'confidence': 'high'},
          ],
        });

        verify(
          () => mockProcessor.processAssignment(
            taskId: any(named: 'taskId'),
            proposedIds: any(named: 'proposedIds'),
            existingIds: ['existing-1', 'existing-2'],
            categoryId: any(named: 'categoryId'),
            droppedLow: any(named: 'droppedLow'),
            legacyUsed: any(named: 'legacyUsed'),
            confidenceBreakdown: any(named: 'confidenceBreakdown'),
            totalCandidates: any(named: 'totalCandidates'),
          ),
        ).called(1);
      });

      test('returns structured JSON message on success', () async {
        when(
          () => mockProcessor.processAssignment(
            taskId: any(named: 'taskId'),
            proposedIds: any(named: 'proposedIds'),
            existingIds: any(named: 'existingIds'),
            categoryId: any(named: 'categoryId'),
            droppedLow: any(named: 'droppedLow'),
            legacyUsed: any(named: 'legacyUsed'),
            confidenceBreakdown: any(named: 'confidenceBreakdown'),
            totalCandidates: any(named: 'totalCandidates'),
          ),
        ).thenAnswer(
          (_) async => LabelAssignmentResult(
            assigned: ['label-a'],
            invalid: ['label-unknown'],
            skipped: [
              {'id': 'label-x', 'reason': 'suppressed'},
            ],
          ),
        );

        final handler = TaskLabelHandler(
          task: task,
          processor: mockProcessor,
        );

        final result = await handler.handle({
          'labels': [
            {'id': 'label-a', 'confidence': 'high'},
            {'id': 'label-unknown', 'confidence': 'medium'},
          ],
        });

        expect(result.success, isTrue);
        expect(result.didWrite, isTrue);

        // Verify the message is valid JSON with expected structure.
        final parsed = jsonDecode(result.message) as Map<String, dynamic>;
        expect(parsed['function'], equals('assign_task_labels'));
        final resultObj = parsed['result'] as Map<String, dynamic>;
        expect(resultObj['assigned'], equals(['label-a']));
        expect(resultObj['invalid'], equals(['label-unknown']));
      });

      test('caps at 3 labels via parser', () async {
        when(
          () => mockProcessor.processAssignment(
            taskId: any(named: 'taskId'),
            proposedIds: any(named: 'proposedIds'),
            existingIds: any(named: 'existingIds'),
            categoryId: any(named: 'categoryId'),
            droppedLow: any(named: 'droppedLow'),
            legacyUsed: any(named: 'legacyUsed'),
            confidenceBreakdown: any(named: 'confidenceBreakdown'),
            totalCandidates: any(named: 'totalCandidates'),
          ),
        ).thenAnswer(
          (_) async => LabelAssignmentResult(
            assigned: ['l1', 'l2', 'l3'],
            invalid: const [],
            skipped: const [],
          ),
        );

        final handler = TaskLabelHandler(
          task: task,
          processor: mockProcessor,
        );

        await handler.handle({
          'labels': [
            {'id': 'l1', 'confidence': 'very_high'},
            {'id': 'l2', 'confidence': 'high'},
            {'id': 'l3', 'confidence': 'medium'},
            {'id': 'l4', 'confidence': 'medium'},
            {'id': 'l5', 'confidence': 'medium'},
          ],
        });

        final captured = verify(
          () => mockProcessor.processAssignment(
            taskId: any(named: 'taskId'),
            proposedIds: captureAny(named: 'proposedIds'),
            existingIds: any(named: 'existingIds'),
            categoryId: any(named: 'categoryId'),
            droppedLow: any(named: 'droppedLow'),
            legacyUsed: any(named: 'legacyUsed'),
            confidenceBreakdown: any(named: 'confidenceBreakdown'),
            totalCandidates: 5,
          ),
        ).captured;
        // Parser caps at 3.
        expect((captured.single as List).length, equals(3));
      });

      test('no-op when processor assigns nothing', () async {
        when(
          () => mockProcessor.processAssignment(
            taskId: any(named: 'taskId'),
            proposedIds: any(named: 'proposedIds'),
            existingIds: any(named: 'existingIds'),
            categoryId: any(named: 'categoryId'),
            droppedLow: any(named: 'droppedLow'),
            legacyUsed: any(named: 'legacyUsed'),
            confidenceBreakdown: any(named: 'confidenceBreakdown'),
            totalCandidates: any(named: 'totalCandidates'),
          ),
        ).thenAnswer(
          (_) async => LabelAssignmentResult(
            assigned: const [],
            invalid: const [],
            skipped: const [],
          ),
        );

        final handler = TaskLabelHandler(
          task: task,
          processor: mockProcessor,
        );

        final result = await handler.handle({
          'labels': [
            {'id': 'label-a', 'confidence': 'high'},
          ],
        });

        expect(result.success, isTrue);
        expect(result.didWrite, isFalse);
        expect(result.wasNoOp, isTrue);
      });

      glados.Glados(
        glados.any.taskLabelHandlerScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test(
        'matches generated parsing, max-label, and processor handoff semantics',
        (scenario) async {
          final localProcessor = MockLabelAssignmentProcessor();
          final taskWithExisting = task.copyWith(
            meta: task.meta.copyWith(labelIds: scenario.existingIds),
          );
          final handler = TaskLabelHandler(
            task: taskWithExisting,
            processor: localProcessor,
          );

          when(
            () => localProcessor.processAssignment(
              taskId: any(named: 'taskId'),
              proposedIds: any(named: 'proposedIds'),
              existingIds: any(named: 'existingIds'),
              categoryId: any(named: 'categoryId'),
              droppedLow: any(named: 'droppedLow'),
              legacyUsed: any(named: 'legacyUsed'),
              confidenceBreakdown: any(named: 'confidenceBreakdown'),
              totalCandidates: any(named: 'totalCandidates'),
            ),
          ).thenAnswer(
            (_) async => LabelAssignmentResult(
              assigned: scenario.assignedByProcessor,
              invalid: const [],
              skipped: const [],
            ),
          );

          final result = await handler.handle(scenario.args);

          if (!scenario.shouldCallProcessor) {
            expect(result.success, isTrue, reason: '$scenario');
            expect(result.didWrite, isFalse, reason: '$scenario');
            expect(result.wasNoOp, isTrue, reason: '$scenario');
            verifyNever(
              () => localProcessor.processAssignment(
                taskId: any(named: 'taskId'),
                proposedIds: any(named: 'proposedIds'),
                existingIds: any(named: 'existingIds'),
              ),
            );
            return;
          }

          final parseResult = scenario.parseResult;
          final captured = verify(
            () => localProcessor.processAssignment(
              taskId: task.meta.id,
              proposedIds: captureAny(named: 'proposedIds'),
              existingIds: captureAny(named: 'existingIds'),
              categoryId: 'cat-1',
              droppedLow: captureAny(named: 'droppedLow'),
              legacyUsed: captureAny(named: 'legacyUsed'),
              confidenceBreakdown: captureAny(
                named: 'confidenceBreakdown',
              ),
              totalCandidates: captureAny(named: 'totalCandidates'),
            ),
          ).captured;

          expect(captured[0], parseResult.selectedIds, reason: '$scenario');
          expect(captured[1], scenario.existingIds, reason: '$scenario');
          expect(captured[2], parseResult.droppedLow, reason: '$scenario');
          expect(captured[3], parseResult.legacyUsed, reason: '$scenario');
          expect(
            captured[4],
            parseResult.confidenceBreakdown,
            reason: '$scenario',
          );
          expect(captured[5], parseResult.totalCandidates, reason: '$scenario');

          expect(result.success, isTrue, reason: '$scenario');
          expect(result.assigned, scenario.assignedByProcessor);
          expect(
            result.didWrite,
            scenario.assignedByProcessor.isNotEmpty,
            reason: '$scenario',
          );

          final parsedMessage =
              jsonDecode(result.message) as Map<String, dynamic>;
          final request = parsedMessage['request'] as Map<String, dynamic>;
          expect(request['labelIds'], parseResult.selectedIds);
        },
        tags: 'glados',
      );
    });

    group('fromHandlerResult conversion', () {
      test('maps successful write with entityId', () {
        const labelResult = TaskLabelResult(
          success: true,
          message: 'Assigned 2 labels',
          assigned: ['l1', 'l2'],
          didWrite: true,
        );

        final toolResult = ToolExecutionResult.fromHandlerResult(
          success: labelResult.success,
          message: labelResult.message,
          didWrite: labelResult.didWrite,
          error: labelResult.error,
          entityId: 'ent-123',
        );

        expect(toolResult.success, isTrue);
        expect(toolResult.output, contains('Assigned'));
        expect(toolResult.mutatedEntityId, 'ent-123');
        expect(toolResult.errorMessage, isNull);
      });

      test('maps no-op result without entityId', () {
        const labelResult = TaskLabelResult(
          success: true,
          message: 'No labels assigned',
        );

        final toolResult = ToolExecutionResult.fromHandlerResult(
          success: labelResult.success,
          message: labelResult.message,
          didWrite: labelResult.didWrite,
          error: labelResult.error,
          entityId: 'ent-123',
        );

        expect(toolResult.success, isTrue);
        expect(toolResult.mutatedEntityId, isNull);
      });

      test('maps error result with error message', () {
        const labelResult = TaskLabelResult(
          success: false,
          message: 'Failed',
          error: 'DB error',
        );

        final toolResult = ToolExecutionResult.fromHandlerResult(
          success: labelResult.success,
          message: labelResult.message,
          didWrite: labelResult.didWrite,
          error: labelResult.error,
        );

        expect(toolResult.success, isFalse);
        expect(toolResult.errorMessage, 'DB error');
        expect(toolResult.mutatedEntityId, isNull);
      });
    });

    group('TaskLabelResult', () {
      test('wasNoOp is true when success=true and didWrite=false', () {
        const result = TaskLabelResult(
          success: true,
          message: 'no-op',
        );
        expect(result.wasNoOp, isTrue);
      });

      test('wasNoOp is false when didWrite=true', () {
        const result = TaskLabelResult(
          success: true,
          message: 'wrote',
          didWrite: true,
        );
        expect(result.wasNoOp, isFalse);
      });

      test('wasNoOp is false when success=false', () {
        const result = TaskLabelResult(
          success: false,
          message: 'error',
        );
        expect(result.wasNoOp, isFalse);
      });
    });

    group('buildLabelContext', () {
      late MockJournalDb mockDb;

      setUp(() {
        mockDb = MockJournalDb();
      });

      test('returns empty string when no labels exist', () async {
        when(() => mockDb.getAllLabelDefinitions()).thenAnswer((_) async => []);

        final result = await TaskLabelHandler.buildLabelContext(
          task: task,
          journalDb: mockDb,
        );

        expect(result, isEmpty);
      });

      test('returns empty string when all labels are deleted', () async {
        when(() => mockDb.getAllLabelDefinitions()).thenAnswer(
          (_) async => [
            testLabelDefinition1.copyWith(
              deletedAt: DateTime(2024),
            ),
          ],
        );

        final result = await TaskLabelHandler.buildLabelContext(
          task: task,
          journalDb: mockDb,
        );

        expect(result, isEmpty);
      });

      test('omits assigned labels (now inline in task context JSON)', () async {
        final taskWithLabels = task.copyWith(
          meta: task.meta.copyWith(labelIds: ['label-1']),
        );

        when(() => mockDb.getAllLabelDefinitions()).thenAnswer(
          (_) async => [testLabelDefinition1, testLabelDefinition2],
        );

        final result = await TaskLabelHandler.buildLabelContext(
          task: taskWithLabels,
          journalDb: mockDb,
        );

        // Assigned labels are now part of the Current Task Context JSON,
        // so they should not appear as a separate section.
        expect(result, isNot(contains('## Assigned Labels')));
        // Available labels section should still be present for unassigned
        // labels.
        expect(result, contains('## Available Labels'));
        expect(result, contains('label-2'));
        expect(result, contains('Backlog'));
      });

      test('includes suppressed labels section', () async {
        final taskWithSuppressed = task.copyWith(
          data: task.data.copyWith(
            aiSuppressedLabelIds: {'label-1'},
          ),
        );

        when(() => mockDb.getAllLabelDefinitions()).thenAnswer(
          (_) async => [testLabelDefinition1, testLabelDefinition2],
        );

        final result = await TaskLabelHandler.buildLabelContext(
          task: taskWithSuppressed,
          journalDb: mockDb,
        );

        expect(result, contains('## Suppressed Labels'));
        expect(result, contains('label-1'));
      });

      test('includes available labels section filtered by scope', () async {
        final scopedLabel = LabelDefinition(
          id: 'scoped-label',
          name: 'Scoped',
          color: '#00FF00',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
          applicableCategoryIds: ['cat-1'],
        );
        final otherCatLabel = LabelDefinition(
          id: 'other-cat-label',
          name: 'Other',
          color: '#0000FF',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
          applicableCategoryIds: ['cat-999'],
        );

        when(() => mockDb.getAllLabelDefinitions()).thenAnswer(
          (_) async => [
            testLabelDefinition1, // global (no applicableCategoryIds)
            scopedLabel, // scoped to cat-1 (task's category)
            otherCatLabel, // scoped to different category
          ],
        );

        final result = await TaskLabelHandler.buildLabelContext(
          task: task,
          journalDb: mockDb,
        );

        expect(result, contains('## Available Labels'));
        // Global label should be available.
        expect(result, contains('label-1'));
        // Scoped label matching task's category should be available.
        expect(result, contains('scoped-label'));
        // Label scoped to different category should NOT be available.
        expect(result, isNot(contains('other-cat-label')));
      });

      test(
        'returns suppressed section even when no assigned/available',
        () async {
          // All labels are either suppressed or out-of-scope — no available.
          final taskWithOnlySuppressed = task.copyWith(
            meta: task.meta.copyWith(labelIds: null),
            data: task.data.copyWith(
              aiSuppressedLabelIds: {'label-1'},
            ),
          );

          final outOfScopeLabel = LabelDefinition(
            id: 'out-of-scope',
            name: 'OutOfScope',
            color: '#0000FF',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            vectorClock: null,
            applicableCategoryIds: ['cat-999'],
          );

          when(() => mockDb.getAllLabelDefinitions()).thenAnswer(
            (_) async => [testLabelDefinition1, outOfScopeLabel],
          );

          final result = await TaskLabelHandler.buildLabelContext(
            task: taskWithOnlySuppressed,
            journalDb: mockDb,
          );

          // Should NOT be empty — suppressed guidance is critical.
          expect(result, isNotEmpty);
          expect(result, contains('## Suppressed Labels'));
          expect(result, contains('label-1'));
          // No assigned or available sections.
          expect(result, isNot(contains('## Assigned Labels')));
          expect(result, isNot(contains('## Available Labels')));
        },
      );

      test('omits available labels section when task has 3+ labels', () async {
        final taskWith3Labels = task.copyWith(
          meta: task.meta.copyWith(
            labelIds: ['label-1', 'label-2', 'label-3'],
          ),
        );

        when(() => mockDb.getAllLabelDefinitions()).thenAnswer(
          (_) async => [
            testLabelDefinition1,
            testLabelDefinition2,
            LabelDefinition(
              id: 'label-3',
              name: 'Third',
              color: '#00FF00',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
            LabelDefinition(
              id: 'label-4',
              name: 'Fourth',
              color: '#FF0000',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
          ],
        );

        final result = await TaskLabelHandler.buildLabelContext(
          task: taskWith3Labels,
          journalDb: mockDb,
        );

        // Should not contain available labels section since task already
        // has 3 labels — prevents the LLM from proposing redundant
        // assignments.
        expect(result, isNot(contains('## Available Labels')));
        expect(result, isNot(contains('label-4')));
      });

      test('excludes assigned and suppressed from available', () async {
        final taskWithLabelsAndSuppressed = task.copyWith(
          meta: task.meta.copyWith(labelIds: ['label-1']),
          data: task.data.copyWith(
            aiSuppressedLabelIds: {'label-2'},
          ),
        );

        when(() => mockDb.getAllLabelDefinitions()).thenAnswer(
          (_) async => [
            testLabelDefinition1, // assigned
            testLabelDefinition2, // suppressed
            LabelDefinition(
              id: 'label-3',
              name: 'Available',
              color: '#00FF00',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
              vectorClock: null,
            ),
          ],
        );

        final result = await TaskLabelHandler.buildLabelContext(
          task: taskWithLabelsAndSuppressed,
          journalDb: mockDb,
        );

        expect(result, contains('## Available Labels'));
        // label-3 should be in available but not label-1 or label-2.
        final availableSection = result.split('## Available Labels')[1];
        expect(availableSection, contains('label-3'));
        expect(availableSection, isNot(contains('"label-1"')));
        expect(availableSection, isNot(contains('"label-2"')));
      });
    });
  });
}
