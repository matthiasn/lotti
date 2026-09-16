import 'dart:async';
import 'dart:ui' show Locale;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/notification_entity.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/notifications/model/notification_episode_id.dart';
import 'package:lotti/features/notifications/repository/notification_repository.dart';
import 'package:lotti/features/sync/state/conflict_notification_observer.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

Conflict _conflict(String id) => Conflict(
  id: id,
  createdAt: DateTime(2024, 3, 15, 14),
  updatedAt: DateTime(2024, 3, 15, 14),
  serialized: '{}',
  schemaVersion: 1,
  status: ConflictStatus.unresolved.index,
);

void main() {
  // The default-locale path resolves through WidgetsBinding.instance.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerAllFallbackValues);

  final now = DateTime(2026, 9, 16, 12);
  late MockJournalDb db;
  late MockNotificationRepository notifications;
  late ConflictNotificationObserver observer;
  late List<NotificationEntity> armedRows;
  final l10n = AppLocalizationsEn();

  String episodeId(List<String> freshIds) => notificationEpisodeId(
    kind: NotificationKinds.syncConflict,
    subjectId: syncConflictsSubjectId,
    episodeKey: ([...freshIds]..sort()).join('+'),
  );

  void stubSuccess() {
    when(
      () => notifications.armEpisode(
        id: any(named: 'id'),
        scheduledFor: any(named: 'scheduledFor'),
        build: any(named: 'build'),
        category: any(named: 'category'),
      ),
    ).thenAnswer((invocation) async {
      final build =
          invocation.namedArguments[#build]
              as NotificationEntity Function(NotificationMeta);
      final row = build(
        NotificationMeta(
          id: invocation.namedArguments[#id] as String,
          createdAt: now,
          updatedAt: now,
          scheduledFor: invocation.namedArguments[#scheduledFor] as DateTime,
          vectorClock: const VectorClock({}),
          originatingHostId: '',
        ),
      );
      armedRows.add(row);
      return row;
    });
    when(
      () => notifications.retractOpenRows(
        linkedEntityId: any(named: 'linkedEntityId'),
        kind: any(named: 'kind'),
        exceptId: any(named: 'exceptId'),
      ),
    ).thenAnswer((_) async => const []);
  }

  setUp(() {
    db = MockJournalDb();
    notifications = MockNotificationRepository();
    armedRows = [];
    stubSuccess();
    observer = ConflictNotificationObserver(
      db: db,
      notificationRepository: notifications,
      messages: AppLocalizationsEn.new,
    );
  });

  Future<void> clocked(Future<void> Function() body) =>
      withClock(Clock.fixed(now), body);

  void verifyNothingWritten() => verifyNever(
    () => notifications.armEpisode(
      id: any(named: 'id'),
      scheduledFor: any(named: 'scheduledFor'),
      build: any(named: 'build'),
      category: any(named: 'category'),
    ),
  );

  test('does not alert for conflicts already present at startup', () async {
    await observer.handleSnapshot([_conflict('a')]);

    verifyNothingWritten();
  });

  test('writes a row due now when a new conflict appears', () async {
    await clocked(() async {
      await observer.handleSnapshot(const []); // prime
      await observer.handleSnapshot([_conflict('a')]);
    });

    verify(
      () => notifications.armEpisode(
        id: episodeId(['a']),
        scheduledFor: now,
        build: any(named: 'build'),
        category: any(named: 'category'),
      ),
    ).called(1);
    final row = armedRows.single as SyncConflictNotification;
    expect(row.conflictCount, 1);
    expect(row.title, l10n.conflictNotificationTitle);
    expect(row.body, l10n.conflictNotificationBody(1));
    // A conflict is this device's disagreement with a peer; the row must
    // never travel to that peer.
    expect(row.isDeviceLocal, isTrue);
    expect(row.linkedEntityId, syncConflictsSubjectId);
  });

  test('a later burst retracts the earlier row', () async {
    await observer.handleSnapshot(const []); // prime
    await observer.handleSnapshot([_conflict('a')]);
    await observer.handleSnapshot([_conflict('a'), _conflict('b')]);

    verify(
      () => notifications.retractOpenRows(
        linkedEntityId: syncConflictsSubjectId,
        kind: NotificationKinds.syncConflict,
        exceptId: episodeId(['b']),
      ),
    ).called(1);
    // The body carries the total still unresolved, not the burst's size.
    expect((armedRows.last as SyncConflictNotification).conflictCount, 2);
  });

  test('coalesces a burst of new conflicts into a single row', () async {
    await observer.handleSnapshot(const []); // prime
    await observer.handleSnapshot([
      _conflict('a'),
      _conflict('b'),
      _conflict('c'),
    ]);

    expect(armedRows, hasLength(1));
    expect(armedRows.single.body, l10n.conflictNotificationBody(3));
    expect(armedRows.single.meta.id, episodeId(['a', 'b', 'c']));
  });

  test('does not alert when no new conflict id appears', () async {
    await observer.handleSnapshot([_conflict('a')]); // prime with one existing
    await observer.handleSnapshot([_conflict('a')]); // unchanged
    await observer.handleSnapshot(const []); // one resolved, none new

    verifyNothingWritten();
  });

  test('a write failure is logged and never escapes the listener', () async {
    final logger = MockDomainLogger();
    await setUpTestGetIt(
      additionalSetup: () => getIt
        ..unregister<DomainLogger>()
        ..registerSingleton<DomainLogger>(logger),
    );
    addTearDown(tearDownTestGetIt);
    when(
      () => notifications.armEpisode(
        id: any(named: 'id'),
        scheduledFor: any(named: 'scheduledFor'),
        build: any(named: 'build'),
        category: any(named: 'category'),
      ),
    ).thenThrow(StateError('notifications.sqlite unavailable'));

    await observer.handleSnapshot(const []); // prime
    await expectLater(observer.handleSnapshot([_conflict('a')]), completes);

    verify(
      () => logger.error(
        LogDomain.sync,
        any<Object>(),
        message: 'failed to record sync-conflict notification',
        stackTrace: any(named: 'stackTrace'),
      ),
    ).called(1);
  });

  test('a write failure without a logger is swallowed too', () async {
    when(
      () => notifications.armEpisode(
        id: any(named: 'id'),
        scheduledFor: any(named: 'scheduledFor'),
        build: any(named: 'build'),
        category: any(named: 'category'),
      ),
    ).thenThrow(StateError('notifications.sqlite unavailable'));

    await observer.handleSnapshot(const []); // prime
    await expectLater(observer.handleSnapshot([_conflict('a')]), completes);
  });

  group('default dependencies resolve from getIt', () {
    setUp(() async {
      await setUpTestGetIt(
        additionalSetup: () => getIt
          ..unregister<JournalDb>()
          ..registerSingleton<JournalDb>(db)
          ..registerSingleton<NotificationRepository>(notifications),
      );
    });

    tearDown(tearDownTestGetIt);

    test(
      'falls back to getIt for the db and repository, and to the device '
      'locale for copy',
      () async {
        // No db, repository or messages passed: the db comes from getIt, the
        // repository resolves lazily from getIt on first alert, and the copy
        // comes from the device-locale resolver (en in the test host).
        final fallback = ConflictNotificationObserver();
        await fallback.handleSnapshot(const []); // prime
        await fallback.handleSnapshot([_conflict('a')]);

        expect(armedRows.single.title, l10n.conflictNotificationTitle);
        expect(armedRows.single.body, l10n.conflictNotificationBody(1));
      },
    );

    testWidgets('an unsupported device locale falls back to English copy', (
      tester,
    ) async {
      // 'xx' is not a shipped translation, so the resolver takes the
      // AppLocalizationsEn() fallback rather than lookupAppLocalizations.
      tester.platformDispatcher.localeTestValue = const Locale('xx');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      final fallback = ConflictNotificationObserver();
      await fallback.handleSnapshot(const []); // prime
      await fallback.handleSnapshot([_conflict('a')]);

      expect(armedRows.single.title, l10n.conflictNotificationTitle);
    });
  });

  test('snapshots from the stream are applied one at a time', () async {
    // Conflicts arriving one by one during a sync each emit a snapshot. Two
    // applied side by side would each arm a row and then retract the
    // other's; serialised, the second waits and the last row survives.
    final controller = StreamController<List<Conflict>>();
    when(
      () => db.watchConflicts(ConflictStatus.unresolved),
    ).thenAnswer((_) => controller.stream);
    final firstArm = Completer<NotificationEntity?>();
    var arms = 0;
    when(
      () => notifications.armEpisode(
        id: any(named: 'id'),
        scheduledFor: any(named: 'scheduledFor'),
        build: any(named: 'build'),
        category: any(named: 'category'),
      ),
    ).thenAnswer((_) => ++arms == 1 ? firstArm.future : Future.value());

    observer.start();
    controller
      ..add(const []) // prime
      ..add([_conflict('a')])
      ..add([_conflict('a'), _conflict('b')]);
    await pumpEventQueue();

    // The second burst has not been touched while the first is still armed.
    expect(arms, 1);
    verifyNever(
      () => notifications.retractOpenRows(
        linkedEntityId: any(named: 'linkedEntityId'),
        kind: any(named: 'kind'),
        exceptId: any(named: 'exceptId'),
      ),
    );

    firstArm.complete(null);
    await pumpEventQueue();

    expect(arms, 2);
    // The last retraction spares the last row: the order the bursts came in.
    final spared = verify(
      () => notifications.retractOpenRows(
        linkedEntityId: syncConflictsSubjectId,
        kind: NotificationKinds.syncConflict,
        exceptId: captureAny(named: 'exceptId'),
      ),
    ).captured;
    expect(spared, [
      episodeId(['a']),
      episodeId(['b']),
    ]);

    await observer.dispose();
    await controller.close();
  });

  test('start subscribes to the unresolved stream; dispose cancels', () async {
    final controller = StreamController<List<Conflict>>();
    when(
      () => db.watchConflicts(ConflictStatus.unresolved),
    ).thenAnswer((_) => controller.stream);

    observer.start();
    controller
      ..add(const []) // prime
      ..add([_conflict('x')]);
    await pumpEventQueue();

    expect(armedRows, hasLength(1));

    await observer.dispose();
    expect(controller.hasListener, isFalse);
    await controller.close();
  });
}
