import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/sync/matrix/descriptor_downloader.dart';
import 'package:lotti/features/sync/matrix/vector_clock_validator.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class _MockEvent extends Mock implements Event {}

class _MockMatrixRoom extends Mock implements Room {}

class _MockMatrixClient extends Mock implements Client {}

class _MockMatrixDatabase extends Mock implements DatabaseApi {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('mxc://placeholder'));
  });

  group('DescriptorDownloader', () {
    late MockLoggingService logging;
    late VectorClockValidator validator;
    late DescriptorDownloader downloader;
    late _MockEvent descriptorEvent;
    late _MockMatrixRoom room;
    late _MockMatrixClient client;
    late _MockMatrixDatabase database;

    setUp(() {
      logging = MockLoggingService();
      stubLoggingService(logging);
      validator = VectorClockValidator(loggingService: logging);
      downloader = DescriptorDownloader(
        loggingService: logging,
        validator: validator,
      );

      descriptorEvent = _MockEvent();
      room = _MockMatrixRoom();
      client = _MockMatrixClient();
      database = _MockMatrixDatabase();

      when(() => descriptorEvent.room).thenReturn(room);
      when(() => room.client).thenReturn(client);
      when(() => client.database).thenReturn(database);
      when(
        () => descriptorEvent.attachmentMimetype,
      ).thenReturn('application/json');
      when(() => descriptorEvent.content).thenReturn({'relativePath': '/path'});
      when(
        () => descriptorEvent.attachmentOrThumbnailMxcUrl(),
      ).thenReturn(Uri.parse('mxc://server/file'));
    });

    JournalEntry buildEntry(VectorClock? vc) => JournalEntry(
      meta: Metadata(
        id: 'entry',
        createdAt: DateTime(2024, 3, 15),
        updatedAt: DateTime(2024, 3, 15),
        dateFrom: DateTime(2024, 3, 15),
        dateTo: DateTime(2024, 3, 15),
        vectorClock: vc,
      ),
      entryText: const EntryText(plainText: 'text'),
    );

    Future<DescriptorDownloadResult> download({
      required VectorClock incoming,
      required List<JournalEntry> responses,
      void Function()? onCachePurge,
    }) async {
      if (onCachePurge != null) {
        downloader.onCachePurge = onCachePurge;
      }
      var index = 0;
      when(descriptorEvent.downloadAndDecryptAttachment).thenAnswer((_) async {
        final entry = responses[index.clamp(0, responses.length - 1)];
        index++;
        final bytes = Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits);
        return MatrixFile(bytes: bytes, name: 'entry.json');
      });
      when(() => database.deleteFile(any<Uri>())).thenAnswer((_) async => true);
      return downloader.download(
        descriptorEvent: descriptorEvent,
        incomingVectorClock: incoming,
        jsonPath: '/path.json',
      );
    }

    test(
      'returns fresh descriptor payload when vector clock is current',
      () async {
        final entry = buildEntry(const VectorClock({'n': 2}));
        final result = await download(
          incoming: const VectorClock({'n': 1}),
          responses: [entry],
        );
        final decoded = JournalEntity.fromJson(
          json.decode(result.json) as Map<String, dynamic>,
        );
        expect(decoded, isA<JournalEntry>());
        final journal = decoded as JournalEntry;
        expect(journal.entryText?.plainText, 'text');
        expect(journal.meta.vectorClock, const VectorClock({'n': 2}));
        expect(result.bytesLength, isPositive);
        verifyNever(() => database.deleteFile(any<Uri>()));
      },
    );

    test('purges cache and retries stale descriptor once', () async {
      var purges = 0;
      final stale = buildEntry(const VectorClock({'n': 1}));
      final fresh = buildEntry(const VectorClock({'n': 3}));
      final result = await download(
        incoming: const VectorClock({'n': 3}),
        responses: [stale, fresh],
        onCachePurge: () => purges++,
      );
      final decoded = JournalEntity.fromJson(
        json.decode(result.json) as Map<String, dynamic>,
      );
      expect(decoded, isA<JournalEntry>());
      final journal = decoded as JournalEntry;
      expect(journal.entryText?.plainText, 'text');
      expect(journal.meta.vectorClock, const VectorClock({'n': 3}));
      expect(purges, 1);
      verify(() => database.deleteFile(any<Uri>())).called(1);
      verify(
        () => logging.captureEvent(
          contains('smart.fetch.stale_vc.refresh path=/path.json'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('throws when descriptor remains stale after refresh', () async {
      final stale = buildEntry(const VectorClock({'n': 1}));
      await expectLater(
        download(
          incoming: const VectorClock({'n': 3}),
          responses: [stale, stale],
        ),
        throwsA(
          isA<FileSystemException>().having(
            (error) => error.message,
            'message',
            contains('after refresh'),
          ),
        ),
      );
      verify(() => database.deleteFile(any<Uri>())).called(1);
    });

    test('throws circuit breaker after repeated stale downloads', () async {
      final stale = buildEntry(const VectorClock({'n': 1}));
      Future<DescriptorDownloadResult> attempt() => download(
        incoming: const VectorClock({'n': 5}),
        responses: [stale, stale],
      );

      await expectLater(
        attempt(),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        attempt(),
        throwsA(isA<FileSystemException>()),
      );
      await expectLater(
        attempt(),
        throwsA(
          isA<FileSystemException>().having(
            (error) => error.message,
            'message',
            contains('circuit breaker'),
          ),
        ),
      );
      verify(
        () => logging.captureEvent(
          contains('smart.fetch.stale_vc.breaker path=/path.json'),
          domain: 'MATRIX_SERVICE',
          subDomain: 'SmartLoader.fetch',
        ),
      ).called(1);
    });

    test('throws when descriptor lacks vector clock metadata', () async {
      final missing = buildEntry(null);
      await expectLater(
        download(
          incoming: const VectorClock({'n': 2}),
          responses: [missing],
        ),
        throwsA(
          isA<FileSystemException>().having(
            (error) => error.message,
            'message',
            contains('missing attachment vector clock'),
          ),
        ),
      );
      verifyNever(() => database.deleteFile(any<Uri>()));
    });
  });
}
