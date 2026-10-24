import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/sync_descriptor_fetcher.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  const roomId = '!room:example.org';
  const eventId = r'$descriptor';
  late MockRoom room;
  late MockMatrixClient client;
  late MockEncryption encryption;
  late MatrixDescriptorFetcher fetcher;

  setUpAll(() => registerFallbackValue(MockEvent()));

  /// A cached descriptor event as the SDK hands it back.
  MockEvent descriptor({
    String type = EventTypes.Message,
    Map<String, dynamic> content = const {'relativePath': '/images/a.json'},
  }) {
    final event = MockEvent();
    when(() => event.type).thenReturn(type);
    when(() => event.eventId).thenReturn(eventId);
    when(() => event.roomId).thenReturn(roomId);
    when(() => event.content).thenReturn(content);
    return event;
  }

  /// What the homeserver answers a direct event lookup with.
  MatrixEvent remote({String? wireRoomId = roomId, String id = eventId}) =>
      MatrixEvent(
        content: {'relativePath': '/images/a.json'},
        type: EventTypes.Message,
        eventId: id,
        senderId: '@alice:example.org',
        originServerTs: DateTime(2026),
        roomId: wireRoomId,
      );

  setUp(() {
    room = MockRoom();
    client = MockMatrixClient();
    encryption = MockEncryption();
    when(() => room.id).thenReturn(roomId);
    when(() => room.client).thenReturn(client);
    when(() => client.encryption).thenReturn(encryption);
    fetcher = MatrixDescriptorFetcher(
      resolveRoom: (id) => id == roomId ? room : null,
    );
  });

  test('a room this client does not hold answers none without asking '
      'the SDK', () async {
    final lookup = await fetcher.fetch(
      roomId: '!elsewhere:example.org',
      eventId: eventId,
    );

    expect(lookup, same(SyncDescriptorLookup.none));
    verifyNever(() => room.getEventById(any()));
  });

  test('a complete cached descriptor is returned without a server '
      'round trip', () async {
    final cached = descriptor();
    when(() => room.getEventById(eventId)).thenAnswer((_) async => cached);

    final lookup = await fetcher.fetch(roomId: roomId, eventId: eventId);

    expect(lookup.descriptor, same(cached));
    expect(lookup.source, 'cacheOrServer');
    verifyNever(() => client.getOneRoomEvent(any(), any()));
    verifyNever(() => encryption.decryptRoomEvent(any()));
  });

  test('a cache miss stays a miss: a null from the SDK is not followed by '
      'a server fetch', () async {
    when(() => room.getEventById(eventId)).thenAnswer((_) async => null);

    final lookup = await fetcher.fetch(roomId: roomId, eventId: eventId);

    expect(lookup.descriptor, isNull);
    expect(lookup.source, 'cacheOrServer');
    verifyNever(() => client.getOneRoomEvent(any(), any()));
  });

  group('a cached plaintext descriptor without relativePath', () {
    setUp(() {
      when(
        () => room.getEventById(eventId),
      ).thenAnswer((_) async => descriptor(content: const {}));
    });

    test('is replaced by the server copy, bound to this room', () async {
      when(
        () => client.getOneRoomEvent(roomId, eventId),
      ).thenAnswer((_) async => remote(wireRoomId: null));

      final lookup = await fetcher.fetch(roomId: roomId, eventId: eventId);

      expect(lookup.source, 'server');
      expect(lookup.descriptor, isA<Event>());
      expect(lookup.descriptor!.eventId, eventId);
      expect(lookup.descriptor!.room, same(room));
      expect(lookup.descriptor!.content['relativePath'], '/images/a.json');
    });

    test('rejects a server copy that names another room', () async {
      when(
        () => client.getOneRoomEvent(roomId, eventId),
      ).thenAnswer((_) async => remote(wireRoomId: '!other:example.org'));

      final lookup = await fetcher.fetch(roomId: roomId, eventId: eventId);

      expect(lookup.source, 'server');
      expect(lookup.descriptor, isNull);
    });

    test('rejects a server copy with another event id', () async {
      when(
        () => client.getOneRoomEvent(roomId, eventId),
      ).thenAnswer((_) async => remote(id: r'$someone-else'));

      final lookup = await fetcher.fetch(roomId: roomId, eventId: eventId);

      expect(lookup.descriptor, isNull);
    });

    test('propagates a server failure for the caller to classify', () {
      when(
        () => client.getOneRoomEvent(roomId, eventId),
      ).thenThrow(const SocketException('offline'));

      expect(
        fetcher.fetch(roomId: roomId, eventId: eventId),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('ciphertext', () {
    late MockEvent ciphertext;
    late MockEvent plaintext;

    setUp(() {
      ciphertext = descriptor(type: EventTypes.Encrypted, content: const {});
      plaintext = descriptor();
      when(
        () => room.getEventById(eventId),
      ).thenAnswer((_) async => ciphertext);
    });

    test('from the cache is decrypted before it is judged', () async {
      when(
        () => encryption.decryptRoomEvent(ciphertext),
      ).thenAnswer((_) async => plaintext);

      final lookup = await fetcher.fetch(roomId: roomId, eventId: eventId);

      expect(lookup.descriptor, same(plaintext));
      expect(lookup.source, 'cacheOrServer');
      verifyNever(() => client.getOneRoomEvent(any(), any()));
    });

    test('that still will not decrypt is returned as it is, not fetched '
        'again', () async {
      when(
        () => encryption.decryptRoomEvent(ciphertext),
      ).thenAnswer((_) async => ciphertext);

      final lookup = await fetcher.fetch(roomId: roomId, eventId: eventId);

      // Encrypted is not Message, so the server is not asked for a copy.
      expect(lookup.descriptor, same(ciphertext));
      verifyNever(() => client.getOneRoomEvent(any(), any()));
    });

    test('stays ciphertext when the client has no encryption', () async {
      when(() => client.encryption).thenReturn(null);

      final lookup = await fetcher.fetch(roomId: roomId, eventId: eventId);

      expect(lookup.descriptor, same(ciphertext));
    });

    test('from the server is decrypted too', () async {
      when(
        () => room.getEventById(eventId),
      ).thenAnswer((_) async => descriptor(content: const {}));
      when(
        () => client.getOneRoomEvent(roomId, eventId),
      ).thenAnswer((_) async => remote()..type = EventTypes.Encrypted);
      when(
        () => encryption.decryptRoomEvent(any()),
      ).thenAnswer((_) async => plaintext);

      final lookup = await fetcher.fetch(roomId: roomId, eventId: eventId);

      expect(lookup.source, 'server');
      expect(lookup.descriptor, same(plaintext));
      final decrypted =
          verify(
                () => encryption.decryptRoomEvent(captureAny()),
              ).captured.single
              as Event;
      expect(decrypted.eventId, eventId);
      expect(decrypted.type, EventTypes.Encrypted);
    });
  });

  test('forClient resolves rooms through the client', () async {
    when(() => client.getRoomById(roomId)).thenReturn(room);
    when(() => client.getRoomById('!elsewhere:example.org')).thenReturn(null);
    final cached = descriptor();
    when(() => room.getEventById(eventId)).thenAnswer((_) async => cached);
    final onClient = MatrixDescriptorFetcher.forClient(client);

    final found = await onClient.fetch(roomId: roomId, eventId: eventId);
    final missing = await onClient.fetch(
      roomId: '!elsewhere:example.org',
      eventId: eventId,
    );

    expect(found.descriptor, same(cached));
    expect(missing, same(SyncDescriptorLookup.none));
  });
}
