// ignore_for_file: unnecessary_lambdas, avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/platform.dart' as pf;
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'read_marker_service_test_helpers.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(MockRoom());
    registerFallbackValue(StackTrace.current);
  });

  group('SyncReadMarkerService guard + fallback', () {
    test('allows when remote is empty', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => room.fullyRead).thenReturn('');
      when(() => room.setReadMarker(any())).thenAnswer((_) async {});
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e1',
      );

      verify(() => room.setReadMarker(r'$e1')).called(1);
    });

    test('allows when no timeline snapshot is provided', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => room.fullyRead).thenReturn(r'$remote');
      when(() => room.setReadMarker(any())).thenAnswer((_) async {});
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e2',
        timeline: null,
      );

      verify(() => room.setReadMarker(r'$e2')).called(1);
    });

    test('skips remote update when event id is not server-assigned', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: 'lotti-123',
      );

      verifyNever(() => room.setReadMarker(any()));
      verifyNever(() => db.saveSettingsItem(any(), any()));
      verify(
        () => log.log(
          LogDomain.sync,
          'marker.remote.skip(nonServerId) id=lotti-123',
          subDomain: 'setReadMarker.guard',
        ),
      ).called(1);
    });

    test(
      'logs and suppresses M_UNKNOWN errors from room.setReadMarker',
      () async {
        final client = MockClient();
        final room = MockRoom();
        final log = MockLogging();
        final db = MockSettingsDb();
        final tl = MockTimeline();
        final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

        final matrixException = MockMatrixException();
        when(() => matrixException.errcode).thenReturn('M_UNKNOWN');

        when(() => client.isLogged()).thenReturn(true);
        when(() => client.deviceName).thenReturn('dev');
        when(() => room.fullyRead).thenReturn('');
        when(() => room.id).thenReturn('!room');
        when(() => room.setReadMarker(any())).thenThrow(matrixException);
        when(
          () => db.saveSettingsItem(any(), any()),
        ).thenAnswer((_) async => 1);

        await svc.updateReadMarker(
          client: client,
          room: room,
          eventId: r'$missing',
          timeline: tl,
        );

        verify(() => db.saveSettingsItem(any(), any())).called(1);
        verify(() => room.setReadMarker(r'$missing')).called(1);
        verify(
          () => log.log(
            LogDomain.sync,
            any<String>(
              that: contains(
                r'marker.remote.missingEvent id=$missing (M_UNKNOWN)',
              ),
            ),
            subDomain: 'setReadMarker',
          ),
        ).called(1);
        verifyNever(() => tl.setReadMarker(eventId: any(named: 'eventId')));
        verifyNever(
          () => log.error(
            any<LogDomain>(),
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        );
      },
    );

    test('blocks when both visible and candidate is not newer', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final tl = MockTimeline();
      final newer = MockEvent();
      final older = MockEvent();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => client.deviceName).thenReturn('dev');
      when(() => room.fullyRead).thenReturn(r'$remote');
      when(() => room.setReadMarker(any())).thenAnswer((_) async {});
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      when(() => older.eventId).thenReturn(r'$e');
      when(() => newer.eventId).thenReturn(r'$remote');
      when(
        () => older.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
      when(
        () => newer.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(200));
      when(() => tl.events).thenReturn(<Event>[older, newer]);

      // Enable guard in tests
      final prev = pf.isTestEnv;
      pf.isTestEnv = false;
      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e',
        timeline: tl,
      );
      // restore
      pf.isTestEnv = prev;

      verifyNever(() => room.setReadMarker(any()));
      verify(
        () => log.log(
          LogDomain.sync,
          any<String>(that: contains('marker.remote.skip')),
          subDomain: 'setReadMarker.guard',
        ),
      ).called(1);
    });

    test('allows when both visible and candidate is newer', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final tl = MockTimeline();
      final newer = MockEvent();
      final older = MockEvent();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => room.fullyRead).thenReturn(r'$remote');
      when(() => room.setReadMarker(any())).thenAnswer((_) async {});
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      when(() => older.eventId).thenReturn(r'$remote');
      when(() => newer.eventId).thenReturn(r'$e');
      when(
        () => older.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
      when(
        () => newer.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(200));
      when(() => tl.events).thenReturn(<Event>[older, newer]);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e',
        timeline: tl,
      );

      verify(() => room.setReadMarker(r'$e')).called(1);
    });

    test(
      'allows when either base or candidate not visible in timeline',
      () async {
        final client = MockClient();
        final room = MockRoom();
        final log = MockLogging();
        final db = MockSettingsDb();
        final tl = MockTimeline();
        final only = MockEvent();
        final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

        when(() => client.isLogged()).thenReturn(true);
        when(() => room.fullyRead).thenReturn(r'$remote');
        when(() => room.setReadMarker(any())).thenAnswer((_) async {});
        when(
          () => db.saveSettingsItem(any(), any()),
        ).thenAnswer((_) async => 1);

        when(() => only.eventId).thenReturn(r'$e');
        when(
          () => only.originServerTs,
        ).thenReturn(DateTime.fromMillisecondsSinceEpoch(100));
        when(() => tl.events).thenReturn(<Event>[only]);

        await svc.updateReadMarker(
          client: client,
          room: room,
          eventId: r'$e',
          timeline: tl,
        );

        verify(() => room.setReadMarker(r'$e')).called(1);
      },
    );

    test('does not attempt remote update when client not logged', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(false);
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e',
      );

      verifyNever(() => room.setReadMarker(any()));
    });

    test(
      'falls back to timeline.setReadMarker when room.setReadMarker fails',
      () async {
        final client = MockClient();
        final room = MockRoom();
        final log = MockLogging();
        final db = MockSettingsDb();
        final tl = MockTimeline();
        final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

        when(() => client.isLogged()).thenReturn(true);
        when(() => room.fullyRead).thenReturn('');
        when(() => room.id).thenReturn('!room');
        when(() => room.setReadMarker(any())).thenThrow(Exception('x'));
        when(
          () => tl.setReadMarker(eventId: any<String>(named: 'eventId')),
        ).thenAnswer((_) async {});
        when(
          () => db.saveSettingsItem(any(), any()),
        ).thenAnswer((_) async => 1);

        await svc.updateReadMarker(
          client: client,
          room: room,
          eventId: r'$e',
          timeline: tl,
        );

        verify(() => tl.setReadMarker(eventId: r'$e')).called(1);
      },
    );

    test('logs exception when room and timeline updates both fail', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final tl = MockTimeline();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => client.deviceName).thenReturn('dev');
      when(() => room.fullyRead).thenReturn('');
      when(() => room.id).thenReturn('!room');
      when(() => room.setReadMarker(any())).thenThrow(Exception('x'));
      when(
        () => tl.setReadMarker(eventId: any<String>(named: 'eventId')),
      ).thenThrow(Exception('y'));
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e',
        timeline: tl,
      );

      verify(
        () => log.error(
          LogDomain.sync,
          any<Object>(),
          stackTrace: any<StackTrace>(named: 'stackTrace'),
          subDomain: any<String>(
            named: 'subDomain',
            that: contains('setReadMarker '),
          ),
        ),
      ).called(1);
    });

    test('allows when timeline.events throws during comparison', () async {
      final client = MockClient();
      final room = MockRoom();
      final log = MockLogging();
      final db = MockSettingsDb();
      final tl = MockTimeline();
      final svc = SyncReadMarkerService(settingsDb: db, loggingService: log);

      when(() => client.isLogged()).thenReturn(true);
      when(() => room.fullyRead).thenReturn(r'$remote');
      when(() => room.setReadMarker(any())).thenAnswer((_) async {});
      when(() => db.saveSettingsItem(any(), any())).thenAnswer((_) async => 1);

      when(() => tl.events).thenThrow(Exception('boom'));

      await svc.updateReadMarker(
        client: client,
        room: room,
        eventId: r'$e',
        timeline: tl,
      );

      verify(() => room.setReadMarker(r'$e')).called(1);
    });

    glados.Glados(
      glados.any.readMarkerScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'generated guard and fallback matrix preserves marker semantics',
      (scenario) async {
        final client = MockClient();
        final room = MockRoom();
        final log = MockLogging();
        final db = MockSettingsDb();
        final timeline = scenario.hasTimeline ? MockTimeline() : null;
        final svc = SyncReadMarkerService(
          settingsDb: db,
          loggingService: log,
        );

        MockEvent buildEvent(String id, int tsMs) {
          final event = MockEvent();
          when(() => event.eventId).thenReturn(id);
          when(() => event.originServerTs).thenReturn(
            DateTime.fromMillisecondsSinceEpoch(tsMs),
          );
          return event;
        }

        when(() => client.isLogged()).thenReturn(scenario.loggedIn);
        when(() => client.deviceName).thenReturn('generated-device');
        when(() => room.id).thenReturn('!generated-room:example.org');
        when(() => room.fullyRead).thenReturn(scenario.remoteId);
        when(
          () => db.saveSettingsItem(any<String>(), any<String>()),
        ).thenAnswer((_) async => 1);

        switch (scenario.roomOutcome) {
          case GeneratedReadMarkerRoomOutcome.succeeds:
            when(() => room.setReadMarker(any<String>())).thenAnswer(
              (_) async {},
            );
          case GeneratedReadMarkerRoomOutcome.missingUnknown:
            final matrixException = MockMatrixException();
            when(() => matrixException.errcode).thenReturn('M_UNKNOWN');
            when(
              () => room.setReadMarker(any<String>()),
            ).thenThrow(matrixException);
          case GeneratedReadMarkerRoomOutcome.throwsGeneric:
            when(
              () => room.setReadMarker(any<String>()),
            ).thenThrow(Exception('room marker failed'));
        }

        if (timeline != null) {
          final hasRemoteMarker = scenario.remoteId.isNotEmpty;
          switch (scenario.timelineKind) {
            case GeneratedReadMarkerTimelineKind.absent:
              throw StateError('absent timeline should not be instantiated');
            case GeneratedReadMarkerTimelineKind.candidateNewer:
              final candidate = buildEvent(scenario.eventId, 200);
              final events = hasRemoteMarker
                  ? <Event>[buildEvent(scenario.remoteId, 100), candidate]
                  : <Event>[candidate];
              when(() => timeline.events).thenReturn(events);
            case GeneratedReadMarkerTimelineKind.remoteNewer:
              final candidate = buildEvent(scenario.eventId, 100);
              final events = hasRemoteMarker
                  ? <Event>[candidate, buildEvent(scenario.remoteId, 200)]
                  : <Event>[candidate];
              when(() => timeline.events).thenReturn(events);
            case GeneratedReadMarkerTimelineKind.candidateOnly:
              final candidate = buildEvent(scenario.eventId, 100);
              when(() => timeline.events).thenReturn(<Event>[candidate]);
            case GeneratedReadMarkerTimelineKind.remoteOnly:
              final events = hasRemoteMarker
                  ? <Event>[buildEvent(scenario.remoteId, 100)]
                  : <Event>[];
              when(() => timeline.events).thenReturn(events);
            case GeneratedReadMarkerTimelineKind.throwsOnEvents:
              when(() => timeline.events).thenThrow(Exception('events failed'));
          }

          switch (scenario.timelineOutcome) {
            case GeneratedReadMarkerTimelineOutcome.succeeds:
              when(
                () => timeline.setReadMarker(
                  eventId: any<String>(named: 'eventId'),
                ),
              ).thenAnswer((_) async {});
            case GeneratedReadMarkerTimelineOutcome.throwsGeneric:
              when(
                () => timeline.setReadMarker(
                  eventId: any<String>(named: 'eventId'),
                ),
              ).thenThrow(Exception('timeline marker failed'));
          }
        }

        final previousTestEnv = pf.isTestEnv;
        pf.isTestEnv = false;
        try {
          await svc.updateReadMarker(
            client: client,
            room: room,
            eventId: scenario.eventId,
            timeline: timeline,
          );
        } finally {
          pf.isTestEnv = previousTestEnv;
        }

        if (scenario.savesLocalMarker) {
          verify(
            () => db.saveSettingsItem(any<String>(), scenario.eventId),
          ).called(1);
        } else {
          verifyNever(
            () => db.saveSettingsItem(any<String>(), any<String>()),
          );
        }

        if (scenario.attemptsRoomMarker) {
          verify(() => room.setReadMarker(scenario.eventId)).called(1);
        } else {
          verifyNever(() => room.setReadMarker(any<String>()));
        }

        if (timeline != null) {
          if (scenario.attemptsTimelineFallback) {
            verify(
              () => timeline.setReadMarker(eventId: scenario.eventId),
            ).called(1);
          } else {
            verifyNever(
              () => timeline.setReadMarker(
                eventId: any<String>(named: 'eventId'),
              ),
            );
          }
        }

        if (scenario.logsMissingEvent) {
          verify(
            () => log.log(
              LogDomain.sync,
              any<String>(that: contains('marker.remote.missingEvent')),
              subDomain: 'setReadMarker',
            ),
          ).called(1);
        } else {
          verifyNever(
            () => log.log(
              LogDomain.sync,
              any<String>(that: contains('marker.remote.missingEvent')),
              subDomain: 'setReadMarker',
            ),
          );
        }

        if (scenario.logsRoomFailure) {
          verify(
            () => log.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(
                named: 'subDomain',
                that: contains('setReadMarker '),
              ),
            ),
          ).called(1);
        } else {
          verifyNever(
            () => log.error(
              LogDomain.sync,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: any<String>(named: 'subDomain'),
            ),
          );
        }
      },
      tags: 'glados',
    );
  });
}
