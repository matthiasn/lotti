import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/tools/checklist_migration_handler.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

enum _GeneratedChecklistMigrationBranch {
  invalidItemId,
  invalidTargetTaskId,
  itemLookupFailed,
  alreadyArchived,
  sourceLookupFailed,
  itemNotOwned,
  targetLookupFailed,
  targetChecklistCreationFailed,
  copyCreationFailed,
  archiveSucceeded,
  archiveFailed,
}

enum _GeneratedInvalidStringArgShape { missing, emptyString, nonString }

class _GeneratedChecklistMigrationScenario {
  const _GeneratedChecklistMigrationScenario({
    required this.branch,
    required this.invalidStringArgShape,
    required this.lookupReturnsWrongType,
    required this.targetNeedsChecklist,
    required this.itemChecked,
    required this.includeTargetCategory,
    required this.titleSeed,
  });

  final _GeneratedChecklistMigrationBranch branch;
  final _GeneratedInvalidStringArgShape invalidStringArgShape;
  final bool lookupReturnsWrongType;
  final bool targetNeedsChecklist;
  final bool itemChecked;
  final bool includeTargetCategory;
  final int titleSeed;

  String get title => 'Generated checklist item $titleSeed';

  String? get targetCategoryId =>
      includeTargetCategory ? 'generated-category-$titleSeed' : null;

  bool get shouldLookupItem =>
      branch != _GeneratedChecklistMigrationBranch.invalidItemId &&
      branch != _GeneratedChecklistMigrationBranch.invalidTargetTaskId;

  bool get shouldLookupSource => switch (branch) {
    _GeneratedChecklistMigrationBranch.sourceLookupFailed ||
    _GeneratedChecklistMigrationBranch.itemNotOwned ||
    _GeneratedChecklistMigrationBranch.targetLookupFailed ||
    _GeneratedChecklistMigrationBranch.targetChecklistCreationFailed ||
    _GeneratedChecklistMigrationBranch.copyCreationFailed ||
    _GeneratedChecklistMigrationBranch.archiveSucceeded ||
    _GeneratedChecklistMigrationBranch.archiveFailed => true,
    _ => false,
  };

  bool get shouldLookupTarget => switch (branch) {
    _GeneratedChecklistMigrationBranch.targetLookupFailed ||
    _GeneratedChecklistMigrationBranch.targetChecklistCreationFailed ||
    _GeneratedChecklistMigrationBranch.copyCreationFailed ||
    _GeneratedChecklistMigrationBranch.archiveSucceeded ||
    _GeneratedChecklistMigrationBranch.archiveFailed => true,
    _ => false,
  };

  bool get isCopyOrArchiveBranch => switch (branch) {
    _GeneratedChecklistMigrationBranch.copyCreationFailed ||
    _GeneratedChecklistMigrationBranch.archiveSucceeded ||
    _GeneratedChecklistMigrationBranch.archiveFailed => true,
    _ => false,
  };

  bool get shouldCreateChecklist =>
      branch ==
          _GeneratedChecklistMigrationBranch.targetChecklistCreationFailed ||
      (isCopyOrArchiveBranch && targetNeedsChecklist);

  bool get shouldAddItem => isCopyOrArchiveBranch;

  bool get shouldArchiveItem => switch (branch) {
    _GeneratedChecklistMigrationBranch.archiveSucceeded ||
    _GeneratedChecklistMigrationBranch.archiveFailed => true,
    _ => false,
  };

  bool get expectedSuccess => switch (branch) {
    _GeneratedChecklistMigrationBranch.alreadyArchived ||
    _GeneratedChecklistMigrationBranch.archiveSucceeded ||
    _GeneratedChecklistMigrationBranch.archiveFailed => true,
    _ => false,
  };

  String? get expectedErrorMessage => switch (branch) {
    _GeneratedChecklistMigrationBranch.invalidItemId =>
      'Missing checklist item ID',
    _GeneratedChecklistMigrationBranch.invalidTargetTaskId =>
      'Missing target task ID',
    _GeneratedChecklistMigrationBranch.itemLookupFailed =>
      'Checklist item lookup failed',
    _GeneratedChecklistMigrationBranch.alreadyArchived => null,
    _GeneratedChecklistMigrationBranch.sourceLookupFailed =>
      'Source task lookup failed',
    _GeneratedChecklistMigrationBranch.itemNotOwned =>
      'Item does not belong to source task',
    _GeneratedChecklistMigrationBranch.targetLookupFailed =>
      'Target task lookup failed',
    _GeneratedChecklistMigrationBranch.targetChecklistCreationFailed =>
      'Target checklist creation failed',
    _GeneratedChecklistMigrationBranch.copyCreationFailed =>
      'Item copy creation failed',
    _GeneratedChecklistMigrationBranch.archiveSucceeded => null,
    _GeneratedChecklistMigrationBranch.archiveFailed =>
      'Source item archival failed',
  };

  Map<String, dynamic> args({
    required String itemId,
    required String targetTaskId,
  }) {
    final args = <String, dynamic>{
      'title': 'Argument title should be ignored',
    };

    if (branch == _GeneratedChecklistMigrationBranch.invalidItemId) {
      _putInvalidStringArg(args, 'id');
    } else {
      args['id'] = itemId;
    }

    if (branch == _GeneratedChecklistMigrationBranch.invalidTargetTaskId) {
      _putInvalidStringArg(args, 'targetTaskId');
    } else {
      args['targetTaskId'] = targetTaskId;
    }

    return args;
  }

  String expectedTargetChecklistId({
    required String existingTargetChecklistId,
    required String createdTargetChecklistId,
  }) {
    if (targetNeedsChecklist && isCopyOrArchiveBranch) {
      return createdTargetChecklistId;
    }
    return existingTargetChecklistId;
  }

  void _putInvalidStringArg(Map<String, dynamic> args, String key) {
    switch (invalidStringArgShape) {
      case _GeneratedInvalidStringArgShape.missing:
        break;
      case _GeneratedInvalidStringArgShape.emptyString:
        args[key] = '';
      case _GeneratedInvalidStringArgShape.nonString:
        args[key] = 42;
    }
  }

  @override
  String toString() {
    return '_GeneratedChecklistMigrationScenario('
        'branch: $branch, '
        'invalidStringArgShape: $invalidStringArgShape, '
        'lookupReturnsWrongType: $lookupReturnsWrongType, '
        'targetNeedsChecklist: $targetNeedsChecklist, '
        'itemChecked: $itemChecked, '
        'includeTargetCategory: $includeTargetCategory, '
        'titleSeed: $titleSeed)';
  }
}

extension _AnyGeneratedChecklistMigrationScenario on glados.Any {
  glados.Generator<_GeneratedChecklistMigrationBranch>
  get checklistMigrationBranch =>
      glados.AnyUtils(this).choose(_GeneratedChecklistMigrationBranch.values);

  glados.Generator<_GeneratedInvalidStringArgShape> get invalidStringArgShape =>
      glados.AnyUtils(this).choose(_GeneratedInvalidStringArgShape.values);

  glados.Generator<_GeneratedChecklistMigrationScenario>
  get checklistMigrationScenario => glados.CombinableAny(this).combine7(
    checklistMigrationBranch,
    invalidStringArgShape,
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    glados.AnyUtils(this).choose([false, true]),
    glados.IntAnys(this).intInRange(0, 10000),
    (
      _GeneratedChecklistMigrationBranch branch,
      _GeneratedInvalidStringArgShape invalidStringArgShape,
      bool lookupReturnsWrongType,
      bool targetNeedsChecklist,
      bool itemChecked,
      bool includeTargetCategory,
      int titleSeed,
    ) => _GeneratedChecklistMigrationScenario(
      branch: branch,
      invalidStringArgShape: invalidStringArgShape,
      lookupReturnsWrongType: lookupReturnsWrongType,
      targetNeedsChecklist: targetNeedsChecklist,
      itemChecked: itemChecked,
      includeTargetCategory: includeTargetCategory,
      titleSeed: titleSeed,
    ),
  );
}

Metadata _generatedMetadata(String id, {String? categoryId}) {
  return Metadata(
    id: id,
    dateFrom: DateTime(2024, 3, 15),
    dateTo: DateTime(2024, 3, 15),
    createdAt: DateTime(2024, 3, 15),
    updatedAt: DateTime(2024, 3, 15),
    categoryId: categoryId,
  );
}

JournalEntity _generatedWrongTypeEntity(String id) {
  return JournalEntity.journalEntry(meta: _generatedMetadata(id));
}

Checklist _generatedChecklist(String id) {
  return JournalEntity.checklist(
        meta: _generatedMetadata(id),
        data: const ChecklistData(
          title: 'Todos',
          linkedChecklistItems: [],
          linkedTasks: [],
        ),
      )
      as Checklist;
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockChecklistRepository mockChecklistRepository;
  late MockJournalDb mockJournalDb;
  late ChecklistMigrationHandler handler;

  const sourceTaskId = 'source-task-001';
  const targetTaskId = 'target-task-001';
  const itemId = 'item-001';
  const checklistId = 'checklist-001';
  const targetChecklistId = 'checklist-002';

  ChecklistItem makeChecklistItem({
    String id = itemId,
    String title = 'Buy milk',
    bool isChecked = false,
    bool isArchived = false,
    List<String> linkedChecklists = const ['checklist-001'],
  }) {
    return JournalEntity.checklistItem(
          meta: Metadata(
            id: id,
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
          ),
          data: ChecklistItemData(
            title: title,
            isChecked: isChecked,
            isArchived: isArchived,
            linkedChecklists: linkedChecklists,
          ),
        )
        as ChecklistItem;
  }

  Task makeTask({
    required String id,
    List<String>? checklistIds,
    String? categoryId,
  }) {
    return Task(
      meta: Metadata(
        id: id,
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        categoryId: categoryId,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: id,
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 0,
        ),
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        statusHistory: [],
        title: 'Task $id',
        checklistIds: checklistIds,
      ),
    );
  }

  late MockDomainLogger mockDomainLogger;

  setUp(() {
    mockChecklistRepository = MockChecklistRepository();
    mockJournalDb = MockJournalDb();
    mockDomainLogger = MockDomainLogger();
    handler = ChecklistMigrationHandler(
      checklistRepository: mockChecklistRepository,
      journalDb: mockJournalDb,
      domainLogger: mockDomainLogger,
    );

    // Stub DomainLogger methods so verification works.
    when(
      () => mockDomainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => mockDomainLogger.error(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenReturn(null);
  });

  group('ChecklistMigrationHandler', () {
    group('validation', () {
      test('returns failure when item id is missing', () async {
        final result = await handler.handle(
          sourceTaskId,
          {'targetTaskId': targetTaskId},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('"id" must be a non-empty string'));
      });

      test('returns failure when targetTaskId is missing', () async {
        final result = await handler.handle(
          sourceTaskId,
          {'id': itemId},
        );

        expect(result.success, isFalse);
        expect(
          result.output,
          contains('"targetTaskId" must be a non-empty string'),
        );
      });

      test('returns failure when checklist item not found', () async {
        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => null);

        final result = await handler.handle(
          sourceTaskId,
          {'id': itemId, 'targetTaskId': targetTaskId},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('checklist item $itemId not found'));
      });

      test('returns failure when source task not found', () async {
        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => makeChecklistItem());

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer((_) async => null);

        final result = await handler.handle(
          sourceTaskId,
          {'id': itemId, 'targetTaskId': targetTaskId},
        );

        expect(result.success, isFalse);
        expect(result.output, contains('source task $sourceTaskId not found'));
      });

      test(
        'returns failure when item does not belong to source task',
        () async {
          when(
            () => mockJournalDb.journalEntityById(itemId),
          ).thenAnswer(
            (_) async => makeChecklistItem(
              linkedChecklists: ['other-checklist'],
            ),
          );

          when(
            () => mockJournalDb.journalEntityById(sourceTaskId),
          ).thenAnswer(
            (_) async => makeTask(
              id: sourceTaskId,
              checklistIds: [checklistId],
            ),
          );

          final result = await handler.handle(
            sourceTaskId,
            {'id': itemId, 'targetTaskId': targetTaskId},
          );

          expect(result.success, isFalse);
          expect(result.output, contains('does not belong to source task'));
        },
      );
    });

    group('idempotency', () {
      test('skips already-archived items without error', () async {
        final archivedItem =
            JournalEntity.checklistItem(
                  meta: Metadata(
                    id: itemId,
                    dateFrom: DateTime(2024, 3, 15),
                    dateTo: DateTime(2024, 3, 15),
                    createdAt: DateTime(2024, 3, 15),
                    updatedAt: DateTime(2024, 3, 15),
                  ),
                  data: const ChecklistItemData(
                    title: 'Already archived',
                    isChecked: false,
                    isArchived: true,
                    linkedChecklists: ['checklist-001'],
                  ),
                )
                as ChecklistItem;

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => archivedItem);

        final result = await handler.handle(
          sourceTaskId,
          {'id': itemId, 'targetTaskId': targetTaskId},
        );

        expect(result.success, isTrue);
        expect(result.output, contains('already archived'));

        // Should not attempt any migration operations.
        verifyNever(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        );
        verifyNever(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        );
      });
    });

    group('migration — target has existing checklist', () {
      test('archives item in source and copies to target', () async {
        final item = makeChecklistItem();

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => item);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: sourceTaskId,
            checklistIds: [checklistId],
          ),
        );

        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => true);

        when(
          () => mockJournalDb.journalEntityById(targetTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: targetTaskId,
            checklistIds: [targetChecklistId],
            categoryId: 'cat-002',
          ),
        );

        when(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: any(named: 'checklistId'),
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (_) async => makeChecklistItem(
            id: 'new-item-001',
            linkedChecklists: [targetChecklistId],
          ),
        );

        final result = await handler.handle(
          sourceTaskId,
          {
            'id': itemId,
            'title': 'Buy milk',
            'targetTaskId': targetTaskId,
          },
        );

        expect(result.success, isTrue);
        expect(result.output, contains('Migrated'));
        expect(result.output, contains('Buy milk'));
        expect(result.mutatedEntityId, targetTaskId);

        // Verify archival.
        final archiveCaptured = verify(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: captureAny(named: 'checklistItemId'),
            data: captureAny(named: 'data'),
            taskId: captureAny(named: 'taskId'),
          ),
        ).captured;

        expect(archiveCaptured[0], itemId);
        final archivedData = archiveCaptured[1] as ChecklistItemData;
        expect(archivedData.isArchived, isTrue);
        expect(archiveCaptured[2], sourceTaskId);

        // Verify copy creation in target.
        verify(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: targetChecklistId,
            title: 'Buy milk',
            isChecked: false,
            categoryId: 'cat-002',
          ),
        ).called(1);
      });

      test('preserves isChecked state when copying', () async {
        final checkedItem = makeChecklistItem(isChecked: true);

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => checkedItem);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: sourceTaskId,
            checklistIds: [checklistId],
          ),
        );

        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => true);

        when(
          () => mockJournalDb.journalEntityById(targetTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: targetTaskId,
            checklistIds: [targetChecklistId],
          ),
        );

        when(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: any(named: 'checklistId'),
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (_) async => makeChecklistItem(
            id: 'new-item-002',
            isChecked: true,
            linkedChecklists: [targetChecklistId],
          ),
        );

        final result = await handler.handle(
          sourceTaskId,
          {
            'id': itemId,
            'title': 'Buy milk',
            'targetTaskId': targetTaskId,
          },
        );

        expect(result.success, isTrue);

        verify(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: targetChecklistId,
            title: 'Buy milk',
            isChecked: true,
            categoryId: any(named: 'categoryId'),
          ),
        ).called(1);
      });
    });

    group('migration — target has no checklist', () {
      test('creates checklist on target task', () async {
        final item = makeChecklistItem();
        final createdChecklist = JournalEntity.checklist(
          meta: Metadata(
            id: 'auto-created-checklist',
            dateFrom: DateTime(2024, 3, 15),
            dateTo: DateTime(2024, 3, 15),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
          ),
          data: const ChecklistData(
            title: 'Todos',
            linkedChecklistItems: [],
            linkedTasks: [],
          ),
        );

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => item);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: sourceTaskId,
            checklistIds: [checklistId],
          ),
        );

        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => true);

        // Target has no checklists.
        when(
          () => mockJournalDb.journalEntityById(targetTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: targetTaskId,
            checklistIds: [],
          ),
        );

        when(
          () => mockChecklistRepository.createChecklist(
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer(
          (_) async => (
            checklist: createdChecklist,
            createdItems: <({String id, String title, bool isChecked})>[],
          ),
        );

        when(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: any(named: 'checklistId'),
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (_) async => makeChecklistItem(
            id: 'new-item-003',
            linkedChecklists: ['auto-created-checklist'],
          ),
        );

        final result = await handler.handle(
          sourceTaskId,
          {
            'id': itemId,
            'title': 'Buy milk',
            'targetTaskId': targetTaskId,
          },
        );

        expect(result.success, isTrue);

        verify(
          () => mockChecklistRepository.createChecklist(
            taskId: targetTaskId,
          ),
        ).called(1);

        verify(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: 'auto-created-checklist',
            title: 'Buy milk',
            isChecked: false,
            categoryId: any(named: 'categoryId'),
          ),
        ).called(1);
      });

      test('returns failure when createChecklist fails', () async {
        final item = makeChecklistItem();

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => item);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: sourceTaskId,
            checklistIds: [checklistId],
          ),
        );

        when(
          () => mockJournalDb.journalEntityById(targetTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: targetTaskId,
            checklistIds: [],
          ),
        );

        when(
          () => mockChecklistRepository.createChecklist(
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer(
          (_) async => (
            checklist: null,
            createdItems: <({String id, String title, bool isChecked})>[],
          ),
        );

        final result = await handler.handle(
          sourceTaskId,
          {
            'id': itemId,
            'title': 'Buy milk',
            'targetTaskId': targetTaskId,
          },
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Target checklist creation failed');

        // Source item should NOT be archived when target checklist
        // creation fails.
        verifyNever(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        );
      });
    });

    group('generated migration semantics', () {
      glados.Glados(
        glados.any.checklistMigrationScenario,
        glados.ExploreConfig(numRuns: 220),
      ).test(
        'matches generated checklist migration branch semantics',
        (scenario) async {
          final localChecklistRepository = MockChecklistRepository();
          final localJournalDb = MockJournalDb();
          final localDomainLogger = MockDomainLogger();
          final localHandler = ChecklistMigrationHandler(
            checklistRepository: localChecklistRepository,
            journalDb: localJournalDb,
            domainLogger: localDomainLogger,
          );
          const createdTargetChecklistId = 'created-target-checklist';

          when(
            () => localDomainLogger.log(
              any(),
              any(),
              subDomain: any(named: 'subDomain'),
            ),
          ).thenReturn(null);
          when(
            () => localDomainLogger.error(
              any(),
              any(),
              subDomain: any(named: 'subDomain'),
              error: any(named: 'error'),
              stackTrace: any(named: 'stackTrace'),
            ),
          ).thenReturn(null);

          if (scenario.shouldLookupItem) {
            final itemEntity = switch (scenario.branch) {
              _GeneratedChecklistMigrationBranch.itemLookupFailed =>
                scenario.lookupReturnsWrongType
                    ? _generatedWrongTypeEntity(itemId)
                    : null,
              _GeneratedChecklistMigrationBranch.alreadyArchived =>
                makeChecklistItem(
                  title: scenario.title,
                  isChecked: scenario.itemChecked,
                  isArchived: true,
                ),
              _ => makeChecklistItem(
                title: scenario.title,
                isChecked: scenario.itemChecked,
              ),
            };

            when(
              () => localJournalDb.journalEntityById(itemId),
            ).thenAnswer((_) async => itemEntity);
          }

          if (scenario.shouldLookupSource) {
            final sourceTaskEntity = switch (scenario.branch) {
              _GeneratedChecklistMigrationBranch.sourceLookupFailed =>
                scenario.lookupReturnsWrongType
                    ? _generatedWrongTypeEntity(sourceTaskId)
                    : null,
              _GeneratedChecklistMigrationBranch.itemNotOwned => makeTask(
                id: sourceTaskId,
                checklistIds: scenario.lookupReturnsWrongType
                    ? null
                    : ['other-checklist'],
              ),
              _ => makeTask(
                id: sourceTaskId,
                checklistIds: [checklistId],
              ),
            };

            when(
              () => localJournalDb.journalEntityById(sourceTaskId),
            ).thenAnswer((_) async => sourceTaskEntity);
          }

          if (scenario.shouldLookupTarget) {
            final targetTaskEntity = switch (scenario.branch) {
              _GeneratedChecklistMigrationBranch.targetLookupFailed =>
                scenario.lookupReturnsWrongType
                    ? _generatedWrongTypeEntity(targetTaskId)
                    : null,
              _ => makeTask(
                id: targetTaskId,
                checklistIds:
                    scenario.targetNeedsChecklist ||
                        scenario.branch ==
                            _GeneratedChecklistMigrationBranch
                                .targetChecklistCreationFailed
                    ? []
                    : [targetChecklistId],
                categoryId: scenario.targetCategoryId,
              ),
            };

            when(
              () => localJournalDb.journalEntityById(targetTaskId),
            ).thenAnswer((_) async => targetTaskEntity);
          }

          if (scenario.shouldCreateChecklist) {
            when(
              () => localChecklistRepository.createChecklist(
                taskId: any(named: 'taskId'),
              ),
            ).thenAnswer((_) async {
              if (scenario.branch ==
                  _GeneratedChecklistMigrationBranch
                      .targetChecklistCreationFailed) {
                return (
                  checklist: null,
                  createdItems:
                      <
                        ({
                          String id,
                          String title,
                          bool isChecked,
                        })
                      >[],
                );
              }

              return (
                checklist: _generatedChecklist(createdTargetChecklistId),
                createdItems:
                    <
                      ({
                        String id,
                        String title,
                        bool isChecked,
                      })
                    >[],
              );
            });
          }

          if (scenario.shouldAddItem) {
            when(
              () => localChecklistRepository.addItemToChecklist(
                checklistId: any(named: 'checklistId'),
                title: any(named: 'title'),
                isChecked: any(named: 'isChecked'),
                categoryId: any(named: 'categoryId'),
              ),
            ).thenAnswer((_) async {
              if (scenario.branch ==
                  _GeneratedChecklistMigrationBranch.copyCreationFailed) {
                return null;
              }

              return makeChecklistItem(
                id: 'new-generated-item',
                title: scenario.title,
                isChecked: scenario.itemChecked,
                linkedChecklists: [
                  scenario.expectedTargetChecklistId(
                    existingTargetChecklistId: targetChecklistId,
                    createdTargetChecklistId: createdTargetChecklistId,
                  ),
                ],
              );
            });
          }

          if (scenario.shouldArchiveItem) {
            when(
              () => localChecklistRepository.updateChecklistItem(
                checklistItemId: any(named: 'checklistItemId'),
                data: any(named: 'data'),
                taskId: any(named: 'taskId'),
              ),
            ).thenAnswer(
              (_) async =>
                  scenario.branch ==
                  _GeneratedChecklistMigrationBranch.archiveSucceeded,
            );
          }

          final result = await localHandler.handle(
            sourceTaskId,
            scenario.args(
              itemId: itemId,
              targetTaskId: targetTaskId,
            ),
          );

          expect(result.success, scenario.expectedSuccess, reason: '$scenario');
          expect(
            result.errorMessage,
            scenario.expectedErrorMessage,
            reason: '$scenario',
          );

          if (scenario.branch ==
              _GeneratedChecklistMigrationBranch.alreadyArchived) {
            expect(result.output, contains('already archived'));
            expect(result.mutatedEntityId, isNull);
          } else if (scenario.shouldArchiveItem) {
            expect(
              result.output,
              contains(scenario.title),
              reason: '$scenario',
            );
            expect(result.mutatedEntityId, targetTaskId, reason: '$scenario');
            expect(
              result.output,
              scenario.branch ==
                      _GeneratedChecklistMigrationBranch.archiveFailed
                  ? contains('Warning')
                  : isNot(contains('Warning')),
              reason: '$scenario',
            );
          } else {
            expect(result.mutatedEntityId, isNull, reason: '$scenario');
          }

          if (!scenario.shouldLookupItem) {
            verifyNever(() => localJournalDb.journalEntityById(itemId));
          }
          if (!scenario.shouldLookupSource) {
            verifyNever(() => localJournalDb.journalEntityById(sourceTaskId));
          }
          if (!scenario.shouldLookupTarget) {
            verifyNever(() => localJournalDb.journalEntityById(targetTaskId));
          }

          if (scenario.shouldCreateChecklist) {
            verify(
              () => localChecklistRepository.createChecklist(
                taskId: targetTaskId,
              ),
            ).called(1);
          } else {
            verifyNever(
              () => localChecklistRepository.createChecklist(
                taskId: any(named: 'taskId'),
              ),
            );
          }

          if (scenario.shouldAddItem) {
            verify(
              () => localChecklistRepository.addItemToChecklist(
                checklistId: scenario.expectedTargetChecklistId(
                  existingTargetChecklistId: targetChecklistId,
                  createdTargetChecklistId: createdTargetChecklistId,
                ),
                title: scenario.title,
                isChecked: scenario.itemChecked,
                categoryId: scenario.targetCategoryId,
              ),
            ).called(1);
          } else {
            verifyNever(
              () => localChecklistRepository.addItemToChecklist(
                checklistId: any(named: 'checklistId'),
                title: any(named: 'title'),
                isChecked: any(named: 'isChecked'),
                categoryId: any(named: 'categoryId'),
              ),
            );
          }

          if (scenario.shouldArchiveItem) {
            final archiveCaptured = verify(
              () => localChecklistRepository.updateChecklistItem(
                checklistItemId: captureAny(named: 'checklistItemId'),
                data: captureAny(named: 'data'),
                taskId: captureAny(named: 'taskId'),
              ),
            ).captured;
            expect(archiveCaptured[0], itemId, reason: '$scenario');
            expect(archiveCaptured[2], sourceTaskId, reason: '$scenario');
            expect(
              (archiveCaptured[1] as ChecklistItemData).isArchived,
              isTrue,
              reason: '$scenario',
            );
          } else {
            verifyNever(
              () => localChecklistRepository.updateChecklistItem(
                checklistItemId: any(named: 'checklistItemId'),
                data: any(named: 'data'),
                taskId: any(named: 'taskId'),
              ),
            );
          }
        },
      );
    });

    group('migration — edge cases', () {
      test('returns failure when target task not found', () async {
        final item = makeChecklistItem();

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => item);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: sourceTaskId,
            checklistIds: [checklistId],
          ),
        );

        when(
          () => mockJournalDb.journalEntityById(targetTaskId),
        ).thenAnswer((_) async => null);

        final result = await handler.handle(
          sourceTaskId,
          {
            'id': itemId,
            'title': 'Buy milk',
            'targetTaskId': targetTaskId,
          },
        );

        expect(result.success, isFalse);
        expect(result.output, contains('target task $targetTaskId not found'));

        // Source item should NOT be archived when target validation fails.
        verifyNever(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        );
      });

      test(
        'returns success with warning when archival fails after copy',
        () async {
          final item = makeChecklistItem();

          when(
            () => mockJournalDb.journalEntityById(itemId),
          ).thenAnswer((_) async => item);

          when(
            () => mockJournalDb.journalEntityById(sourceTaskId),
          ).thenAnswer(
            (_) async => makeTask(
              id: sourceTaskId,
              checklistIds: [checklistId],
            ),
          );

          when(
            () => mockJournalDb.journalEntityById(targetTaskId),
          ).thenAnswer(
            (_) async => makeTask(
              id: targetTaskId,
              checklistIds: [targetChecklistId],
            ),
          );

          when(
            () => mockChecklistRepository.addItemToChecklist(
              checklistId: any(named: 'checklistId'),
              title: any(named: 'title'),
              isChecked: any(named: 'isChecked'),
              categoryId: any(named: 'categoryId'),
            ),
          ).thenAnswer(
            (_) async => makeChecklistItem(
              id: 'new-item-copy',
              linkedChecklists: [targetChecklistId],
            ),
          );

          // Copy succeeds but archival fails.
          when(
            () => mockChecklistRepository.updateChecklistItem(
              checklistItemId: any(named: 'checklistItemId'),
              data: any(named: 'data'),
              taskId: any(named: 'taskId'),
            ),
          ).thenAnswer((_) async => false);

          final result = await handler.handle(
            sourceTaskId,
            {
              'id': itemId,
              'title': 'Buy milk',
              'targetTaskId': targetTaskId,
            },
          );

          // Success to prevent retry (which would duplicate the copy).
          expect(result.success, isTrue);
          expect(result.errorMessage, 'Source item archival failed');
          expect(result.output, contains('Warning'));
          expect(result.output, contains('not archived'));
          expect(result.mutatedEntityId, targetTaskId);
        },
      );

      test('logs via DomainLogger when target task not found', () async {
        final item = makeChecklistItem();

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => item);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: sourceTaskId,
            checklistIds: [checklistId],
          ),
        );

        when(
          () => mockJournalDb.journalEntityById(targetTaskId),
        ).thenAnswer((_) async => null);

        await handler.handle(
          sourceTaskId,
          {
            'id': itemId,
            'title': 'Buy milk',
            'targetTaskId': targetTaskId,
          },
        );

        // Verify structured logging was used for lookup and error.
        verify(
          () => mockDomainLogger.log(
            LogDomains.agentWorkflow,
            any(that: contains('Looking up target task')),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);
        verify(
          () => mockDomainLogger.log(
            LogDomains.agentWorkflow,
            any(that: contains('Target task lookup result')),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);
        verify(
          () => mockDomainLogger.error(
            LogDomains.agentWorkflow,
            any(that: contains('Target task $targetTaskId not found')),
            subDomain: any(named: 'subDomain'),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      });

      test('logs via DomainLogger on successful migration', () async {
        final item = makeChecklistItem();

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => item);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: sourceTaskId,
            checklistIds: [checklistId],
          ),
        );

        when(
          () => mockJournalDb.journalEntityById(targetTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: targetTaskId,
            checklistIds: [targetChecklistId],
          ),
        );

        when(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: any(named: 'checklistId'),
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer(
          (_) async => makeChecklistItem(
            id: 'new-item-log',
            linkedChecklists: [targetChecklistId],
          ),
        );

        when(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => true);

        await handler.handle(
          sourceTaskId,
          {
            'id': itemId,
            'title': 'Buy milk',
            'targetTaskId': targetTaskId,
          },
        );

        // Verify lookup logs (no error log on success).
        verify(
          () => mockDomainLogger.log(
            LogDomains.agentWorkflow,
            any(that: contains('Looking up target task')),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);
        verify(
          () => mockDomainLogger.log(
            LogDomains.agentWorkflow,
            any(that: contains('Target task lookup result')),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);
        verifyNever(
          () => mockDomainLogger.error(
            any(),
            any(),
            subDomain: any(named: 'subDomain'),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
          ),
        );
      });

      test('returns failure when addItemToChecklist returns null', () async {
        final item = makeChecklistItem();

        when(
          () => mockJournalDb.journalEntityById(itemId),
        ).thenAnswer((_) async => item);

        when(
          () => mockJournalDb.journalEntityById(sourceTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: sourceTaskId,
            checklistIds: [checklistId],
          ),
        );

        when(
          () => mockJournalDb.journalEntityById(targetTaskId),
        ).thenAnswer(
          (_) async => makeTask(
            id: targetTaskId,
            checklistIds: [targetChecklistId],
          ),
        );

        when(
          () => mockChecklistRepository.addItemToChecklist(
            checklistId: any(named: 'checklistId'),
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        final result = await handler.handle(
          sourceTaskId,
          {
            'id': itemId,
            'title': 'Buy milk',
            'targetTaskId': targetTaskId,
          },
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, 'Item copy creation failed');

        // Source item should NOT be archived when copy creation fails.
        verifyNever(
          () => mockChecklistRepository.updateChecklistItem(
            checklistItemId: any(named: 'checklistItemId'),
            data: any(named: 'data'),
            taskId: any(named: 'taskId'),
          ),
        );
      });
    });
  });
}
