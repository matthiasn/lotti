import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';

class _MockJournalDb extends Mock implements JournalDb {}

class _MockUpdateNotifications extends Mock implements UpdateNotifications {}

class _MockNotificationService extends Mock implements NotificationService {}

class _MockOutboxService extends Mock implements OutboxService {}

void main() {
  late _MockJournalDb journalDb;
  // Use the centralized MockVectorClockService so the withVcScope passthrough
  // from test/mocks/mocks.dart is in effect. A plain mocktail mock would
  // return null from withVcScope and the production code would crash on the
  // `await null` inside PersistenceLogic.updateJournalEntity.
  late MockVectorClockService vclock;
  late _MockUpdateNotifications updates;
  late MockLoggingService logging;
  late _MockNotificationService notifications;

  setUpAll(() {
    // Fallback for any<JournalEntity>() matchers
    final now = DateTime(2024);
    registerFallbackValue(
      Task(
        meta: Metadata(
          id: 'fallback',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: TaskData(
          title: 'fallback',
          status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
          statusHistory: const [],
          dateFrom: now,
          dateTo: now,
        ),
      ),
    );
  });

  setUp(() async {
    await getIt.reset();
    journalDb = _MockJournalDb();
    vclock = MockVectorClockService();
    updates = _MockUpdateNotifications();
    logging = MockLoggingService();
    notifications = _MockNotificationService();

    getIt
      ..registerSingleton<JournalDb>(journalDb)
      ..registerSingleton<VectorClockService>(vclock)
      ..registerSingleton<UpdateNotifications>(updates)
      ..registerSingleton<LoggingService>(logging)
      ..registerSingleton<NotificationService>(notifications)
      ..registerSingleton<OutboxService>(_MockOutboxService());

    // Not used because we override updateMetadata below
    when(() => notifications.updateBadge()).thenAnswer((_) async {});
  });

  tearDown(getIt.reset);

  final testDate = DateTime(2024, 3, 15, 10, 30);

  Task makeTask({List<String>? labelIds}) => Task(
    meta: Metadata(
      id: 'task-1',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
      labelIds: labelIds,
    ),
    data: TaskData(
      title: 'T',
      status: TaskStatus.open(
        id: 's',
        createdAt: testDate,
        utcOffset: 0,
      ),
      statusHistory: const [],
      dateFrom: testDate,
      dateTo: testDate,
    ),
  );

  test(
    'updateJournalEntity preserves current labels to prevent overwrite',
    () async {
      // Use a test persistence that overrides updateDbEntity and updateMetadata
      final persistence = _TestPersistenceLogic();
      // Ensure registration
      if (getIt.isRegistered<PersistenceLogic>()) {
        getIt.unregister<PersistenceLogic>();
      }
      getIt.registerSingleton<PersistenceLogic>(persistence);

      // Current DB state has label "nice" already assigned (e.g., by addLabels)
      final current = makeTask(labelIds: const ['nice']);
      when(
        () => journalDb.journalEntityById('task-1'),
      ).thenAnswer((_) async => current);

      // JournalDb side-effects no-op
      when(
        () => journalDb.addLabeled(any<JournalEntity>()),
      ).thenAnswer((_) async {});

      // Now perform a non-label update with an updated entity that does not carry the labels
      final updated = current.copyWith(
        data: current.data.copyWith(languageCode: 'en'),
        meta: current.meta.copyWith(labelIds: null),
      );

      final ok = await getIt<PersistenceLogic>().updateJournalEntity(
        updated,
        updated.meta,
      );
      expect(ok, isTrue);
      final saved =
          (getIt<PersistenceLogic>() as _TestPersistenceLogic).lastSaved;
      expect(saved, isNotNull);
      // Verify that labels were preserved (not dropped)
      expect(saved!.meta.labelIds, equals(const ['nice']));
    },
  );
}

class _TestPersistenceLogic extends PersistenceLogic {
  JournalEntity? _lastSaved;
  @override
  Future<bool?> updateDbEntity(
    JournalEntity journalEntity, {
    String? linkedId,
    bool enqueueSync = true,
    bool overrideComparison = false,
    Future<void> Function()? beforeNotify,
  }) async {
    _lastSaved = journalEntity;
    await beforeNotify?.call();
    // Simulate applied
    return true;
  }

  @override
  Future<Metadata> updateMetadata(
    Metadata metadata, {
    DateTime? dateFrom,
    DateTime? dateTo,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? deletedAt,
    List<String>? labelIds,
    bool clearLabelIds = false,
  }) async {
    // Simple metadata update without vector clock dependency for test
    return metadata.copyWith(
      updatedAt: DateTime(2024, 3, 15, 10, 31),
      dateFrom: dateFrom ?? metadata.dateFrom,
      dateTo: dateTo ?? metadata.dateTo,
      categoryId: clearCategoryId ? null : categoryId ?? metadata.categoryId,
      deletedAt: deletedAt ?? metadata.deletedAt,
      labelIds: clearLabelIds ? null : labelIds ?? metadata.labelIds,
    );
  }

  JournalEntity? get lastSaved => _lastSaved;
}
