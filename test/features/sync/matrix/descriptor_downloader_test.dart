import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/sync/matrix/descriptor_downloader.dart';
import 'package:lotti/features/sync/matrix/pipeline/attachment_descriptor.dart';
import 'package:lotti/features/sync/matrix/vector_clock_validator.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  const descriptor = AttachmentDescriptor(
    eventId: r'$descriptor',
    roomId: '!room:example.org',
    relativePath: '/path',
    mimetype: 'application/json',
  );
  final purgedUri = Uri.parse('mxc://server/file');

  setUpAll(() {
    registerFallbackValue(descriptor);
  });

  group('DescriptorDownloader', () {
    late MockDomainLogger logging;
    late VectorClockValidator validator;
    late DescriptorDownloader downloader;
    late MockSyncAttachmentFetcher fetcher;

    setUp(() {
      logging = MockDomainLogger();
      validator = VectorClockValidator(loggingService: logging);
      fetcher = MockSyncAttachmentFetcher();
      downloader = DescriptorDownloader(
        loggingService: logging,
        validator: validator,
        fetcher: fetcher,
      );
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
      when(
        () => fetcher.download(
          descriptor,
          pathForError: any(named: 'pathForError'),
        ),
      ).thenAnswer((_) async {
        final entry = responses[index.clamp(0, responses.length - 1)];
        index++;
        return Uint8List.fromList(jsonEncode(entry.toJson()).codeUnits);
      });
      when(
        () => fetcher.purgeCached(descriptor),
      ).thenAnswer((_) async => purgedUri);
      return downloader.download(
        descriptor: descriptor,
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
        verifyNever(() => fetcher.purgeCached(any()));
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
      verify(() => fetcher.purgeCached(descriptor)).called(1);
      verify(
        () => logging.log(
          LogDomain.sync,
          any<String>(
            that: contains('smart.fetch.stale_vc.refresh path=/path.json'),
          ),
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
      verify(() => fetcher.purgeCached(descriptor)).called(1);
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
        () => logging.log(
          LogDomain.sync,
          any<String>(
            that: contains('smart.fetch.stale_vc.breaker path=/path.json'),
          ),
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
      verifyNever(() => fetcher.purgeCached(any()));
    });
  });
}
