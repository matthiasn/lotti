import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_descriptor.dart';
import 'package:lotti/features/sync/matrix/sync_attachment_fetcher.dart';
import 'package:lotti/features/sync/matrix/sync_descriptor_fetcher.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  const descriptor = AttachmentDescriptor(
    eventId: r'$attachment',
    roomId: '!room:example.org',
    relativePath: '/images/a.jpg',
    mimetype: 'image/jpeg',
  );
  late MockSyncDescriptorFetcher events;
  late MockEvent event;
  late MatrixAttachmentFetcher fetcher;

  void eventFound(Event? found) {
    when(
      () =>
          events.fetch(roomId: descriptor.roomId, eventId: descriptor.eventId),
    ).thenAnswer(
      (_) async => SyncDescriptorLookup(descriptor: found, source: 'test'),
    );
  }

  setUp(() {
    events = MockSyncDescriptorFetcher();
    event = MockEvent();
    when(() => event.eventId).thenReturn(descriptor.eventId);
    fetcher = MatrixAttachmentFetcher(events: events);
  });

  group('download', () {
    test("returns the bytes of the descriptor's event as the SDK decrypts "
        'them', () async {
      eventFound(event);
      final bytes = Uint8List.fromList([1, 2, 3]);
      when(event.downloadAndDecryptAttachment).thenAnswer(
        (_) async => MatrixFile(bytes: bytes, name: 'a.jpg'),
      );

      expect(await fetcher.download(descriptor), same(bytes));
    });

    test('names the attachment in the error when the event cannot be found, '
        "the caller's path first", () async {
      eventFound(null);

      await expectLater(
        fetcher.download(descriptor, pathForError: '/text_entries/a.json'),
        throwsA(
          isA<FileSystemException>()
              .having((e) => e.path, 'path', '/text_entries/a.json')
              .having((e) => e.message, 'message', contains(r'$attachment')),
        ),
      );
      await expectLater(
        fetcher.download(descriptor),
        throwsA(
          isA<FileSystemException>().having(
            (e) => e.path,
            'path',
            '/images/a.jpg',
          ),
        ),
      );
    });

    test('lets a download failure through for the caller to classify', () {
      eventFound(event);
      when(
        event.downloadAndDecryptAttachment,
      ).thenThrow(const SocketException('offline'));

      expect(fetcher.download(descriptor), throwsA(isA<SocketException>()));
    });
  });

  group('purgeCached', () {
    late MockRoom room;
    late MockMatrixClient client;
    late MockMatrixDatabase database;

    setUp(() {
      room = MockRoom();
      client = MockMatrixClient();
      database = MockMatrixDatabase();
      when(() => event.room).thenReturn(room);
      when(() => room.client).thenReturn(client);
      when(() => client.database).thenReturn(database);
      eventFound(event);
    });

    test('drops the cached file and answers with its URI', () async {
      final uri = Uri.parse('mxc://server/a');
      when(event.attachmentOrThumbnailMxcUrl).thenReturn(uri);
      when(() => database.deleteFile(uri)).thenAnswer((_) async => true);

      expect(await fetcher.purgeCached(descriptor), uri);
      verify(() => database.deleteFile(uri)).called(1);
    });

    test(
      'answers null, touching nothing, for an event without media',
      () async {
        when(event.attachmentOrThumbnailMxcUrl).thenReturn(null);

        expect(await fetcher.purgeCached(descriptor), isNull);
        verifyNever(() => database.deleteFile(any()));
      },
    );

    test('fails like a download when the event cannot be found', () {
      eventFound(null);

      expect(
        fetcher.purgeCached(descriptor),
        throwsA(isA<FileSystemException>()),
      );
    });
  });

  setUpAll(() => registerFallbackValue(Uri.parse('mxc://fallback')));
}
