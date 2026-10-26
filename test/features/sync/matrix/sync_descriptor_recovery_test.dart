import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/sync_descriptor_fetcher.dart';
import 'package:lotti/features/sync/matrix/sync_descriptor_recovery.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  const roomId = '!room:example.org';
  const eventId = r'$descriptor';

  late MockSyncDescriptorFetcher fetcher;
  late MockSyncEventTrust trust;
  late MockDomainLogger logging;
  late TrustedDescriptorRecovery recovery;

  setUpAll(() {
    registerFallbackValue(MockEvent());
    registerFallbackValue(LogDomain.sync);
  });

  /// The decrypted descriptor event the client lookup hands back.
  MockEvent descriptorEvent({
    String id = eventId,
    String room = roomId,
    Map<String, dynamic> content = const {
      'relativePath': '/images/a.jpg',
      'info': {'size': 2048},
    },
  }) {
    final event = MockEvent();
    when(() => event.type).thenReturn(EventTypes.Message);
    when(() => event.eventId).thenReturn(id);
    when(() => event.roomId).thenReturn(room);
    when(() => event.content).thenReturn(content);
    when(() => event.attachmentMimetype).thenReturn('image/jpeg');
    return event;
  }

  void lookupAnswers(Event? event, {String source = 'cacheOrServer'}) {
    when(
      () => fetcher.fetch(roomId: roomId, eventId: eventId),
    ).thenAnswer(
      (_) async => SyncDescriptorLookup(descriptor: event, source: source),
    );
  }

  void trustSays({required bool admitted}) {
    when(
      () => trust.admits(any(), subDomain: 'descriptorRecovery.trust'),
    ).thenAnswer((_) async => admitted);
  }

  setUp(() {
    fetcher = MockSyncDescriptorFetcher();
    trust = MockSyncEventTrust();
    logging = MockDomainLogger();
    when(
      () => logging.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
        level: any(named: 'level'),
      ),
    ).thenReturn(null);
    recovery = TrustedDescriptorRecovery(
      fetcher: fetcher,
      trust: trust,
      logging: logging,
    );
  });

  test('a trusted descriptor bound to the asked event and room comes back '
      'as plain values', () async {
    lookupAnswers(descriptorEvent());
    trustSays(admitted: true);

    final descriptor = await recovery.recover(
      roomId: roomId,
      eventId: eventId,
    );

    expect(descriptor, isNotNull);
    expect(descriptor!.eventId, eventId);
    expect(descriptor.roomId, roomId);
    expect(descriptor.relativePath, '/images/a.jpg');
    expect(descriptor.mimetype, 'image/jpeg');
    expect(descriptor.declaredSize, 2048);
    verify(
      () => logging.log(
        LogDomain.sync,
        any(
          that: allOf(
            contains('found=true'),
            contains('source=cacheOrServer'),
            contains('trusted=true'),
            contains('descriptor=true'),
          ),
        ),
        subDomain: 'descriptorRecovery',
      ),
    ).called(1);
  });

  test('nothing found is null, and the trust gate is never asked', () async {
    lookupAnswers(null, source: 'none');

    expect(
      await recovery.recover(roomId: roomId, eventId: eventId),
      isNull,
    );
    verifyNever(
      () => trust.admits(any(), subDomain: any(named: 'subDomain')),
    );
  });

  test('an event answering for another id or room is refused before the '
      'trust gate', () async {
    lookupAnswers(descriptorEvent(id: r'$someone-else'));
    expect(
      await recovery.recover(roomId: roomId, eventId: eventId),
      isNull,
    );

    lookupAnswers(descriptorEvent(room: '!other:example.org'));
    expect(
      await recovery.recover(roomId: roomId, eventId: eventId),
      isNull,
    );

    verifyNever(
      () => trust.admits(any(), subDomain: any(named: 'subDomain')),
    );
  });

  test('a descriptor from an untrusted device is refused', () async {
    final event = descriptorEvent();
    lookupAnswers(event);
    trustSays(admitted: false);

    expect(
      await recovery.recover(roomId: roomId, eventId: eventId),
      isNull,
    );
    verify(
      () => trust.admits(event, subDomain: 'descriptorRecovery.trust'),
    ).called(1);
  });

  test('a trusted event that describes no attachment is null', () async {
    lookupAnswers(descriptorEvent(content: const {'body': 'hello'}));
    trustSays(admitted: true);

    expect(
      await recovery.recover(roomId: roomId, eventId: eventId),
      isNull,
    );
  });

  test('a lookup failure propagates for the caller to classify', () {
    when(
      () => fetcher.fetch(roomId: roomId, eventId: eventId),
    ).thenThrow(const SocketException('offline'));

    expect(
      recovery.recover(roomId: roomId, eventId: eventId),
      throwsA(isA<SocketException>()),
    );
  });

  test('works without a logger', () async {
    final quiet = TrustedDescriptorRecovery(fetcher: fetcher, trust: trust);
    lookupAnswers(descriptorEvent());
    trustSays(admitted: true);

    final descriptor = await quiet.recover(roomId: roomId, eventId: eventId);

    expect(descriptor?.eventId, eventId);
  });
}
