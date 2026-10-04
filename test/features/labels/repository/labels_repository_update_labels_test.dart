import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

// The two writers of a task's labels, each deciding on the task as stored
// (`specs/tla/TaskLabels.tla`): the label picker's edit (`updateLabels`) and
// the agent's assignment (`assignLabels`).
void main() {
  late LabelsRepository repo;
  late MockJournalDb mockDb;
  late MockPersistenceLogic mockPl;
  late MockEntitiesCacheService mockCache;
  late MockDomainLogger mockDomainLogger;
  late JournalEntity current;

  setUpAll(registerAllFallbackValues);

  LabelDefinition def(String id) => LabelDefinition(
    id: id,
    name: id,
    color: '#000',
    createdAt: DateTime(2024, 3, 15),
    updatedAt: DateTime(2024, 3, 15),
    vectorClock: null,
    private: false,
  );

  Task task({List<String>? labels, Set<String>? suppressed}) => Task(
    meta: Metadata(
      id: 't1',
      createdAt: DateTime(2024, 3, 15),
      updatedAt: DateTime(2024, 3, 15),
      dateFrom: DateTime(2024, 3, 15),
      dateTo: DateTime(2024, 3, 15),
      labelIds: labels,
    ),
    data: TaskData(
      status: TaskStatus.open(
        id: 's',
        createdAt: DateTime(2024, 3, 15),
        utcOffset: 0,
      ),
      dateFrom: DateTime(2024, 3, 15),
      dateTo: DateTime(2024, 3, 15),
      statusHistory: const [],
      title: 't',
      aiSuppressedLabelIds: suppressed,
    ),
  );

  /// The database holds [entity], and every write replaces it.
  void storing(JournalEntity entity) {
    current = entity;
    when(
      () => mockDb.journalEntityById(entity.meta.id),
    ).thenAnswer((_) async => current);
    when(
      () => mockPl.updateDbEntity(
        any(),
        precondition: any(named: 'precondition'),
      ),
    ).thenAnswer((inv) async {
      current = inv.positionalArguments.first as JournalEntity;
      return true;
    });
  }

  List<String> labelsOf() => current.meta.labelIds ?? const [];
  Set<String> suppressedOf() =>
      (current as Task).data.aiSuppressedLabelIds ?? const {};

  setUp(() {
    mockDb = MockJournalDb();
    mockPl = MockPersistenceLogic();
    mockCache = MockEntitiesCacheService();
    mockDomainLogger = MockDomainLogger();
    repo = LabelsRepository(
      mockPl,
      mockDb,
      mockCache,
      mockDomainLogger,
      MockUpdateNotifications(),
    );
    when(() => mockCache.getLabelById(any())).thenAnswer(
      (inv) => def(inv.positionalArguments.first as String),
    );
    when(
      () => mockPl.updateMetadata(
        any(),
        dateFrom: any(named: 'dateFrom'),
        dateTo: any(named: 'dateTo'),
        categoryId: any(named: 'categoryId'),
        clearCategoryId: any(named: 'clearCategoryId'),
        deletedAt: any(named: 'deletedAt'),
        labelIds: any<List<String>?>(named: 'labelIds'),
        clearLabelIds: any<bool>(named: 'clearLabelIds'),
      ),
    ).thenAnswer((inv) async {
      final meta = inv.positionalArguments.first as Metadata;
      final labels = inv.namedArguments[#labelIds] as List<String>?;
      return labels == null ? meta : meta.copyWith(labelIds: labels);
    });
    when(
      () => mockDomainLogger.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);
  });

  group('updateLabels', () {
    test(
      'a label taken off is suppressed, and put back is unsuppressed',
      () async {
        storing(task(labels: ['a', 'b', 'c'], suppressed: {'x'}));

        expect(
          await repo.updateLabels(journalEntityId: 't1', removed: {'b'}),
          isTrue,
        );
        expect(labelsOf(), ['a', 'c']);
        expect(suppressedOf(), {'x', 'b'});

        expect(
          await repo.updateLabels(journalEntityId: 't1', added: {'b'}),
          isTrue,
        );
        expect(labelsOf(), ['a', 'b', 'c']);
        expect(suppressedOf(), {'x'});
      },
    );

    // The picker opened on {a}; the agent put b on meanwhile; the user adds
    // c. The edit is the user's: b stays, and is not suppressed as if the
    // user had rejected it (`specs/tla/TaskLabels.tla`, PickerDelta).
    test('a label another writer put on while the picker was open is kept '
        'and not suppressed', () async {
      storing(task(labels: ['a', 'b']));

      await repo.updateLabels(journalEntityId: 't1', added: {'c'});

      expect(labelsOf(), ['a', 'b', 'c']);
      expect(suppressedOf(), isEmpty);
    });

    test('drops unknown labels and sorts by name', () async {
      when(() => mockCache.getLabelById('gone')).thenReturn(null);
      when(
        () => mockDb.getLabelDefinitionById('gone'),
      ).thenAnswer((_) async => null);
      storing(task(labels: ['c']));

      await repo.updateLabels(journalEntityId: 't1', added: {'gone', 'a'});

      expect(labelsOf(), ['a', 'c']);
    });

    // The agent appends, the picker sorts: the same labels in another order
    // are no edit.
    test('an edit that changes nothing writes nothing, whatever the stored '
        'order', () async {
      storing(task(labels: ['c', 'a']));

      expect(await repo.updateLabels(journalEntityId: 't1'), isTrue);
      expect(
        await repo.updateLabels(journalEntityId: 't1', added: {'a'}),
        isTrue,
      );

      verifyNever(
        () => mockPl.updateDbEntity(
          any(),
          precondition: any(named: 'precondition'),
        ),
      );
    });
  });

  group('assignLabels', () {
    // The user took b off after the assignment read the task: the write
    // decides on the task as stored, and b stays off and suppressed
    // (`specs/tla/TaskLabels.tla`, SuppressionAtWrite).
    test('skips a label suppressed on the stored task, and leaves the '
        'suppressed set alone', () async {
      storing(task(labels: ['a'], suppressed: {'b'}));

      final added = await repo.assignLabels(
        journalEntityId: 't1',
        labelIds: ['b', 'c'],
      );

      expect(added, {'c'});
      expect(labelsOf(), ['a', 'c']);
      expect(suppressedOf(), {'b'});
    });

    test('adds nothing, and writes nothing, for labels already on the '
        'task', () async {
      storing(task(labels: ['a']));

      expect(
        await repo.assignLabels(journalEntityId: 't1', labelIds: ['a']),
        isEmpty,
      );
      verifyNever(
        () => mockPl.updateDbEntity(
          any(),
          precondition: any(named: 'precondition'),
        ),
      );
    });
  });

  test('a non-task entry gets its labels from both writers, with no '
      'suppression', () async {
    final img = JournalImage(
      meta: Metadata(
        id: 'img1',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
      ),
      data: ImageData(
        capturedAt: DateTime(2024, 3, 15),
        imageId: 'i',
        imageFile: 'f',
        imageDirectory: 'd',
      ),
    );
    storing(img);

    expect(
      await repo.assignLabels(journalEntityId: 'img1', labelIds: ['a']),
      {'a'},
    );
    expect(
      await repo.updateLabels(journalEntityId: 'img1', added: {'b'}),
      isTrue,
    );

    expect(current, isA<JournalImage>());
    expect(labelsOf(), ['a', 'b']);
  });

  test('a failure is logged; assignLabels answers null, updateLabels '
      'false', () async {
    when(() => mockDb.journalEntityById('bad')).thenThrow(Exception('db'));

    expect(
      await repo.assignLabels(journalEntityId: 'bad', labelIds: ['x']),
      isNull,
    );
    expect(
      await repo.updateLabels(journalEntityId: 'bad', removed: {'x'}),
      isFalse,
    );
    verify(
      () => mockDomainLogger.error(
        LogDomain.labels,
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).called(2);
  });
}
