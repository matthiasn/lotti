import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/utils/attachment_decoding.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

class _MockEvent extends Mock implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  group('decodeAttachmentBytes', () {
    test(
      'returns bytes verbatim when no encoding header is present',
      () async {
        final logging = MockLoggingService();
        final event = _MockEvent();
        when(() => event.content).thenReturn(<String, dynamic>{});

        final payload = Uint8List.fromList([1, 2, 3, 4, 5]);
        final decoded = await decodeAttachmentBytes(
          event: event,
          downloadedBytes: payload,
          relativePath: '/foo.json',
          logging: logging,
        );

        expect(decoded, same(payload));
        verifyNever(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        );
      },
    );

    test(
      'returns bytes verbatim for unknown encoding values',
      () async {
        // Forward-compat: a future sender might add a new encoding; older
        // receivers must pass the bytes through untouched rather than
        // panic or corrupt the file.
        final logging = MockLoggingService();
        final event = _MockEvent();
        when(() => event.content).thenReturn(<String, dynamic>{
          attachmentEncodingKey: 'brotli',
        });

        final payload = Uint8List.fromList([9, 8, 7]);
        final decoded = await decodeAttachmentBytes(
          event: event,
          downloadedBytes: payload,
          relativePath: '/bar.json',
          logging: logging,
        );

        expect(decoded, same(payload));
      },
    );

    test(
      'decompresses a gzipped payload when encoding=gzip and logs ratio',
      () async {
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});

        final event = _MockEvent();
        when(() => event.content).thenReturn(<String, dynamic>{
          attachmentEncodingKey: attachmentEncodingGzip,
        });

        // A repetitive JSON-shaped payload so gzip has something to crunch.
        final original = List<String>.filled(
          64,
          '{"k":"value"},',
        ).join().codeUnits;
        final compressed = Uint8List.fromList(gzip.encode(original));

        final decoded = await decodeAttachmentBytes(
          event: event,
          downloadedBytes: compressed,
          relativePath: '/agent_entities/foo.json',
          logging: logging,
        );

        expect(decoded, equals(original));

        final captured = verify(
          () => logging.captureEvent(
            captureAny<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.decode',
          ),
        ).captured;
        expect(captured, hasLength(1));
        final line = captured.single as String;
        expect(line, contains('gzipDecoded'));
        expect(line, contains('path=/agent_entities/foo.json'));
        expect(line, contains('compressed=${compressed.length}'));
        expect(line, contains('decoded=${original.length}'));
        expect(line, contains('ratio='));
      },
    );

    test(
      'offloads large gzipped payloads via compute and round-trips bytes',
      () async {
        // The decoder gates on payload length: anything >= 2 KB hands off
        // to a worker isolate via `compute`. Feed it a payload well past the
        // threshold so that the offload branch runs end-to-end. The test
        // checks correctness (round-trip) and that the log line still fires
        // from the main isolate after the worker returns.
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});

        final event = _MockEvent();
        when(() => event.content).thenReturn(<String, dynamic>{
          attachmentEncodingKey: attachmentEncodingGzip,
        });

        // Deterministic but gzip-incompressible bytes (fixed seed for
        // reproducibility). Repetitive or low-entropy content compresses
        // below the 2 KB inline threshold and skips the offload branch
        // this test exists to exercise.
        final rng = Random(0x5EED);
        final original = List<int>.generate(32 * 1024, (_) => rng.nextInt(256));
        final compressed = Uint8List.fromList(gzip.encode(original));
        expect(
          compressed.length,
          greaterThan(2 * 1024),
          reason: 'compressed payload must cross the inline threshold',
        );

        final decoded = await decodeAttachmentBytes(
          event: event,
          downloadedBytes: compressed,
          relativePath: '/agent_entities/large.json',
          logging: logging,
        );

        expect(decoded, equals(original));

        final captured = verify(
          () => logging.captureEvent(
            captureAny<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: 'attachment.decode',
          ),
        ).captured;
        expect(captured, hasLength(1));
        final line = captured.single as String;
        expect(line, contains('gzipDecoded'));
        expect(line, contains('decoded=${original.length}'));
      },
    );

    test(
      'regression: gzipped JSON no longer explodes a downstream utf8.decode',
      () async {
        // This is the exact shape of the production bug that this helper
        // exists to prevent. Pre-fix, a caller would receive the raw gzip
        // bytes (0x1f 0x8b ...) and feed them to utf8.decode, which throws
        // `FormatException: Unexpected extension byte (at offset 1)`.
        final logging = MockLoggingService();
        when(
          () => logging.captureEvent(
            any<String>(),
            domain: any<String>(named: 'domain'),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});

        final event = _MockEvent();
        when(() => event.content).thenReturn(<String, dynamic>{
          attachmentEncodingKey: attachmentEncodingGzip,
        });
        const originalJson = '{"hello":"world","n":42}';
        final compressed = Uint8List.fromList(
          gzip.encode(originalJson.codeUnits),
        );

        final decoded = await decodeAttachmentBytes(
          event: event,
          downloadedBytes: compressed,
          relativePath: '/agent_entities/x.json',
          logging: logging,
        );

        expect(String.fromCharCodes(decoded), originalJson);
      },
    );
  });

  group('formatCompressionRatio', () {
    test('formats to 3 decimals', () {
      expect(
        formatCompressionRatio(raw: 1000, compressed: 250),
        '0.250',
      );
      expect(
        formatCompressionRatio(raw: 7, compressed: 2),
        '0.286',
      );
    });

    test('returns - for raw<=0 rather than dividing by zero', () {
      expect(formatCompressionRatio(raw: 0, compressed: 10), '-');
      expect(formatCompressionRatio(raw: -1, compressed: 10), '-');
    });
  });

  group('downloadAttachmentWithTimeout single-flight', () {
    test(
      'deduplicates concurrent downloads for the same eventId so the SDK '
      'is only hit once even under retry storms',
      () async {
        // Under retries, multiple prepare calls for the same Matrix
        // event must share one in-flight SDK download rather than each
        // spawning a fresh one (which would stack orphaned downloads
        // behind a hung peer).
        var downloadCalls = 0;
        final completer = Completer<MatrixFile>();
        final event = _MockEvent();
        when(() => event.eventId).thenReturn(r'$same-event-id');
        // ignore: unnecessary_lambdas
        when(() => event.downloadAndDecryptAttachment()).thenAnswer((_) {
          downloadCalls++;
          return completer.future;
        });

        final first = downloadAttachmentWithTimeout(
          event,
          timeout: const Duration(seconds: 10),
        );
        final second = downloadAttachmentWithTimeout(
          event,
          timeout: const Duration(seconds: 10),
        );

        final payload = Uint8List.fromList([1, 2, 3]);
        completer.complete(MatrixFile(bytes: payload, name: 'f'));

        final results = await Future.wait([first, second]);
        expect(
          downloadCalls,
          1,
          reason:
              'concurrent calls for the same eventId must share one '
              'underlying SDK download',
        );
        expect(results[0].bytes, payload);
        expect(results[1].bytes, payload);
      },
    );

    test(
      'releases the single-flight slot after completion so a later '
      'attempt triggers a fresh download',
      () async {
        var downloadCalls = 0;
        final event = _MockEvent();
        when(() => event.eventId).thenReturn(r'$release-test');
        // ignore: unnecessary_lambdas
        when(() => event.downloadAndDecryptAttachment()).thenAnswer((_) async {
          downloadCalls++;
          return MatrixFile(
            bytes: Uint8List.fromList([downloadCalls]),
            name: 'f',
          );
        });

        await downloadAttachmentWithTimeout(event);
        await downloadAttachmentWithTimeout(event);
        expect(
          downloadCalls,
          2,
          reason: 'sequential calls after completion must each hit the SDK',
        );
      },
    );

    test(
      'maps a timeout into FileSystemException carrying the supplied '
      'path for diagnostics',
      () async {
        final event = _MockEvent();
        when(() => event.eventId).thenReturn(r'$timeout-test');
        // ignore: unnecessary_lambdas
        when(
          () => event.downloadAndDecryptAttachment(),
        ).thenAnswer((_) => Completer<MatrixFile>().future);

        await expectLater(
          () => downloadAttachmentWithTimeout(
            event,
            pathForError: '/entries/stuck.json',
            timeout: const Duration(milliseconds: 50),
          ),
          throwsA(
            isA<FileSystemException>()
                .having((e) => e.message, 'message', contains('timed out'))
                .having((e) => e.path, 'path', '/entries/stuck.json'),
          ),
        );
      },
    );
  });
}
