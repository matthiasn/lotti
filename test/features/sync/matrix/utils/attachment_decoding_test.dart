import 'dart:io';
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
}
