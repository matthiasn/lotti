import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_consumer.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class _MockSessionManager extends Mock implements MatrixSessionManager {}

class _MockRoomManager extends Mock implements SyncRoomManager {}

class _MockClient extends Mock implements Client {}

class _MockSyncEventProcessor extends Mock implements SyncEventProcessor {
  num? _ts;
  @override
  num? get startupTimestamp => _ts;
  @override
  set startupTimestamp(num? value) => _ts = value;
}

class _FakeRoom extends Fake implements Room {}

class _FakeClient extends Fake implements Client {}

enum _GeneratedConsumerStartKind {
  skipped,
  alreadyAttached,
  noConfiguredRoom,
  configuredNeverAppears,
  configuredAppears,
  configuredHydrateThrows,
}

enum _GeneratedConsumerTimestampKind { present, missing }

class _GeneratedConsumerScenario {
  const _GeneratedConsumerScenario({
    required this.initCalls,
    required this.disposeCalls,
    required this.startKind,
    required this.timestampKind,
    required this.slot,
  });

  final int initCalls;
  final int disposeCalls;
  final _GeneratedConsumerStartKind startKind;
  final _GeneratedConsumerTimestampKind timestampKind;
  final int slot;

  bool get starts => startKind != _GeneratedConsumerStartKind.skipped;

  bool get hydrates =>
      starts && startKind != _GeneratedConsumerStartKind.alreadyAttached;

  bool get requiresPolling =>
      startKind == _GeneratedConsumerStartKind.configuredNeverAppears ||
      startKind == _GeneratedConsumerStartKind.configuredAppears ||
      startKind == _GeneratedConsumerStartKind.configuredHydrateThrows;

  bool get hydrateThrows =>
      startKind == _GeneratedConsumerStartKind.configuredHydrateThrows;

  num? get expectedStartupTimestamp =>
      timestampKind == _GeneratedConsumerTimestampKind.present
      ? 1700000000 + slot
      : null;

  String? get timestampSetting => expectedStartupTimestamp?.toString();

  @override
  String toString() {
    return '_GeneratedConsumerScenario('
        'initCalls: $initCalls, '
        'disposeCalls: $disposeCalls, '
        'startKind: $startKind, '
        'timestampKind: $timestampKind, '
        'slot: $slot'
        ')';
  }
}

extension _AnyGeneratedConsumerScenario on glados.Any {
  glados.Generator<_GeneratedConsumerStartKind> get consumerStartKind =>
      glados.AnyUtils(this).choose(_GeneratedConsumerStartKind.values);

  glados.Generator<_GeneratedConsumerTimestampKind> get consumerTimestampKind =>
      glados.AnyUtils(this).choose(_GeneratedConsumerTimestampKind.values);

  glados.Generator<_GeneratedConsumerScenario> get consumerScenario =>
      glados.CombinableAny(this).combine5(
        glados.IntAnys(this).intInRange(0, 4),
        glados.IntAnys(this).intInRange(0, 3),
        consumerStartKind,
        consumerTimestampKind,
        glados.IntAnys(this).intInRange(0, 16),
        (
          int initCalls,
          int disposeCalls,
          _GeneratedConsumerStartKind startKind,
          _GeneratedConsumerTimestampKind timestampKind,
          int slot,
        ) => _GeneratedConsumerScenario(
          initCalls: initCalls,
          disposeCalls: disposeCalls,
          startKind: startKind,
          timestampKind: timestampKind,
          slot: slot,
        ),
      );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeClient());
    registerFallbackValue(StackTrace.empty);
  });

  late _MockSessionManager session;
  late _MockRoomManager room;
  late MockLoggingService logging;
  late MockSettingsDb settings;
  late _MockSyncEventProcessor processor;
  late CachedStreamController<SyncUpdate> onSyncCtl;
  late _MockClient client;

  setUp(() {
    session = _MockSessionManager();
    room = _MockRoomManager();
    logging = MockLoggingService();
    settings = MockSettingsDb();
    processor = _MockSyncEventProcessor();
    client = _MockClient();
    onSyncCtl = CachedStreamController<SyncUpdate>();

    when(() => session.client).thenReturn(client);
    when(() => client.onSync).thenReturn(onSyncCtl);

    when(() => room.initialize()).thenAnswer((_) async {});
    when(
      () => room.hydrateRoomSnapshot(client: any(named: 'client')),
    ).thenAnswer((_) async {});

    when(
      () => settings.itemByKey(lastReadMatrixEventId),
    ).thenAnswer((_) async => 'evt-123');
    when(
      () => settings.itemByKey(lastReadMatrixEventTs),
    ).thenAnswer((_) async => '1700000000');

    stubLoggingService(logging);
  });

  tearDown(() async {
    await onSyncCtl.close();
  });

  // Drop the stub class — we use the real CachedStreamController above.

  MatrixStreamConsumer build() => MatrixStreamConsumer(
    sessionManager: session,
    roomManager: room,
    loggingService: logging,
    settingsDb: settings,
    eventProcessor: processor,
  );

  group('MatrixStreamConsumer.initialize', () {
    test('seeds eventProcessor.startupTimestamp from SettingsDb', () async {
      final consumer = build();
      await consumer.initialize();
      expect(processor.startupTimestamp, 1700000000);
      verify(() => room.initialize()).called(1);
    });

    test('parses missing startup timestamp as null', () async {
      when(
        () => settings.itemByKey(lastReadMatrixEventTs),
      ).thenAnswer((_) async => null);

      final consumer = build();
      await consumer.initialize();
      expect(processor.startupTimestamp, isNull);
    });

    test('initialize is idempotent', () async {
      final consumer = build();
      await consumer.initialize();
      await consumer.initialize();
      verify(() => room.initialize()).called(1);
    });

    test('emits a startup.marker log line with the resolved values', () async {
      final consumer = build();
      await consumer.initialize();

      verify(
        () => logging.captureEvent(
          any<Object>(
            that: isA<String>().having(
              (s) => s,
              'message',
              allOf(
                contains('startup.marker'),
                contains('id=evt-123'),
                contains('ts=1700000000'),
              ),
            ),
          ),
          domain: any<String>(named: 'domain'),
          subDomain: 'startup.marker',
        ),
      ).called(1);
    });
  });

  group('MatrixStreamConsumer.start', () {
    test(
      'hydrates the room when not yet present and a roomId is configured',
      () {
        // Advance fake time past the 50 × 200ms polling window so the test
        // doesn't burn 10s of real time waiting for hydrateRoomSnapshot to
        // populate currentRoom (which our stub never does).
        fakeAsync((async) {
          when(() => room.currentRoom).thenReturn(null);
          when(() => room.currentRoomId).thenReturn('!room:server');

          final consumer = build();
          unawaited(consumer.start());
          async
            ..elapse(const Duration(seconds: 11))
            ..flushMicrotasks();

          verify(
            () => room.hydrateRoomSnapshot(client: any(named: 'client')),
          ).called(1);
        });
      },
    );

    test(
      'skips waiting when no room is configured (fresh provisioning)',
      () async {
        when(() => room.currentRoom).thenReturn(null);
        when(() => room.currentRoomId).thenReturn(null);

        final consumer = build();
        await consumer.start();

        verify(
          () => room.hydrateRoomSnapshot(client: any(named: 'client')),
        ).called(1);
      },
    );

    test('does not hydrate when a room is already attached', () async {
      when(() => room.currentRoom).thenReturn(_FakeRoom());

      final consumer = build();
      await consumer.start();

      verifyNever(
        () => room.hydrateRoomSnapshot(client: any(named: 'client')),
      );
    });

    test('logs hydrate failure but continues to start signals', () async {
      when(() => room.currentRoom).thenReturn(null);
      when(() => room.currentRoomId).thenReturn(null);
      when(
        () => room.hydrateRoomSnapshot(client: any(named: 'client')),
      ).thenThrow(StateError('hydrate failed'));

      final consumer = build();
      await consumer.start();

      verify(
        () => logging.captureException(
          any<Object>(),
          domain: any<String>(named: 'domain'),
          subDomain: 'start.hydrateRoom',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  glados.Glados(
    glados.any.consumerScenario,
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'generated lifecycle initializes once and hydrates only when needed',
    (scenario) async {
      final localSession = _MockSessionManager();
      final localRoom = _MockRoomManager();
      final localLogging = MockLoggingService();
      final localSettings = MockSettingsDb();
      final localProcessor = _MockSyncEventProcessor();
      final localClient = _MockClient();
      final localOnSyncCtl = CachedStreamController<SyncUpdate>();
      var currentRoomReads = 0;

      when(() => localSession.client).thenReturn(localClient);
      when(() => localClient.onSync).thenReturn(localOnSyncCtl);
      when(localRoom.initialize).thenAnswer((_) async {});
      when(
        () => localRoom.hydrateRoomSnapshot(client: any(named: 'client')),
      ).thenAnswer((_) async {});
      when(
        () => localSettings.itemByKey(lastReadMatrixEventId),
      ).thenAnswer((_) async => 'evt-${scenario.slot}');
      when(
        () => localSettings.itemByKey(lastReadMatrixEventTs),
      ).thenAnswer((_) async => scenario.timestampSetting);
      stubLoggingService(localLogging);

      switch (scenario.startKind) {
        case _GeneratedConsumerStartKind.skipped:
          when(() => localRoom.currentRoom).thenReturn(null);
          when(() => localRoom.currentRoomId).thenReturn(null);
        case _GeneratedConsumerStartKind.alreadyAttached:
          when(() => localRoom.currentRoom).thenReturn(_FakeRoom());
          when(() => localRoom.currentRoomId).thenReturn('!room:server');
        case _GeneratedConsumerStartKind.noConfiguredRoom:
          when(() => localRoom.currentRoom).thenReturn(null);
          when(() => localRoom.currentRoomId).thenReturn(null);
        case _GeneratedConsumerStartKind.configuredNeverAppears:
        case _GeneratedConsumerStartKind.configuredHydrateThrows:
          when(() => localRoom.currentRoom).thenReturn(null);
          when(() => localRoom.currentRoomId).thenReturn('!room:server');
        case _GeneratedConsumerStartKind.configuredAppears:
          when(() => localRoom.currentRoom).thenAnswer((_) {
            currentRoomReads++;
            return currentRoomReads > 3 ? _FakeRoom() : null;
          });
          when(() => localRoom.currentRoomId).thenReturn('!room:server');
      }
      if (scenario.hydrateThrows) {
        when(
          () => localRoom.hydrateRoomSnapshot(client: any(named: 'client')),
        ).thenThrow(StateError('generated hydrate failure'));
      }

      final consumer = MatrixStreamConsumer(
        sessionManager: localSession,
        roomManager: localRoom,
        loggingService: localLogging,
        settingsDb: localSettings,
        eventProcessor: localProcessor,
      );

      try {
        Future<void> exerciseLifecycle({required bool includeDispose}) async {
          for (var i = 0; i < scenario.initCalls; i++) {
            await consumer.initialize();
          }
          if (scenario.starts) {
            await consumer.start();
          }
          if (includeDispose) {
            for (var i = 0; i < scenario.disposeCalls; i++) {
              await consumer.dispose();
            }
          }
        }

        if (scenario.requiresPolling) {
          fakeAsync((async) {
            var completed = false;
            Object? error;
            unawaited(
              exerciseLifecycle(includeDispose: false)
                  .then<void>((_) {
                    completed = true;
                  })
                  .catchError((Object e) {
                    error = e;
                  }),
            );

            async.flushMicrotasks();
            for (var i = 0; i < 51 && !completed; i++) {
              async
                ..elapse(const Duration(milliseconds: 200))
                ..flushMicrotasks();
            }

            expect(error, isNull, reason: '$scenario');
            expect(completed, isTrue, reason: '$scenario');
          });
        } else {
          await exerciseLifecycle(includeDispose: true);
        }

        expect(
          localProcessor.startupTimestamp,
          scenario.initCalls > 0 ? scenario.expectedStartupTimestamp : isNull,
          reason: '$scenario',
        );
        if (scenario.initCalls > 0) {
          verify(localRoom.initialize).called(1);
        } else {
          verifyNever(localRoom.initialize);
        }
        if (scenario.hydrates) {
          verify(
            () => localRoom.hydrateRoomSnapshot(client: any(named: 'client')),
          ).called(1);
        } else {
          verifyNever(
            () => localRoom.hydrateRoomSnapshot(client: any(named: 'client')),
          );
        }
        if (scenario.hydrateThrows) {
          verify(
            () => localLogging.captureException(
              any<Object>(),
              domain: any<String>(named: 'domain'),
              subDomain: 'start.hydrateRoom',
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
            ),
          ).called(1);
        }
      } finally {
        if (scenario.starts && scenario.disposeCalls == 0) {
          await consumer.dispose();
        }
        await localOnSyncCtl.close();
      }
    },
  );

  group('MatrixStreamConsumer disposal & metrics', () {
    test('dispose logs a disposal event', () async {
      when(() => room.currentRoom).thenReturn(_FakeRoom());

      final consumer = build();
      await consumer.start();
      await consumer.dispose();

      verify(
        () => logging.captureEvent(
          any<Object>(
            that: isA<String>().having(
              (s) => s,
              'message',
              contains('MatrixStreamConsumer disposed'),
            ),
          ),
          domain: any<String>(named: 'domain'),
          subDomain: 'dispose',
        ),
      ).called(1);
    });

    test('metricsSnapshot returns the processor snapshot map', () {
      final consumer = build();
      final snap = consumer.metricsSnapshot();
      expect(snap, isA<Map<String, int>>());
    });

    test('diagnosticsStrings returns a map even with no traffic', () {
      final consumer = build();
      expect(consumer.diagnosticsStrings(), isA<Map<String, String>>());
    });

    test('recordConnectivitySignal does not throw on a fresh consumer', () {
      final consumer = build();
      expect(consumer.recordConnectivitySignal, returnsNormally);
    });
  });
}
