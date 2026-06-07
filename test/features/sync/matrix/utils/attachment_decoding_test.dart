// ignore_for_file: unnecessary_lambdas
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/utils/attachment_decoding.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  // Contract boundary: this file owns decoding/transport concerns
  // (decodeAttachmentBytes, download dedup, gzip helpers). Persisting the
  // decoded bytes is atomicWriteBytes' contract, owned by
  // atomic_write_test.dart — no write-path coverage belongs here.
  group('decodeAttachmentBytes', () {
    test(
      'returns bytes verbatim when no encoding header is present',
      () async {
        final logging = MockDomainLogger();
        final event = MockEvent();
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
          () => logging.log(
            any<LogDomain>(),
            any<String>(),
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
        final logging = MockDomainLogger();
        final event = MockEvent();
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
        final logging = MockDomainLogger();
        when(
          () => logging.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});

        final event = MockEvent();
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
          () => logging.log(
            any<LogDomain>(),
            captureAny<String>(),
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
        final logging = MockDomainLogger();
        when(
          () => logging.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});

        final event = MockEvent();
        when(() => event.content).thenReturn(<String, dynamic>{
          attachmentEncodingKey: attachmentEncodingGzip,
        });

        // Deterministic but gzip-incompressible bytes (fixed seed for
        // reproducibility). Repetitive or low-entropy content compresses
        // below the 2 KB inline threshold and skips the offload branch
        // this test exists to exercise.
        // fakeAsync is inapplicable: the offload runs through compute(),
        // and a real isolate spawn cannot be driven by a fake clock — the
        // ~100-400 ms cost is the price of exercising the real boundary.
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
          () => logging.log(
            any<LogDomain>(),
            captureAny<String>(),
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
        final logging = MockDomainLogger();
        when(
          () => logging.log(
            any<LogDomain>(),
            any<String>(),
            subDomain: any<String>(named: 'subDomain'),
          ),
        ).thenAnswer((_) async {});

        final event = MockEvent();
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

    glados.Glados(
      glados.any.generatedCompressionRatio,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'matches generated compression ratio formatting model',
      (scenario) {
        expect(
          formatCompressionRatio(
            raw: scenario.raw,
            compressed: scenario.compressed,
          ),
          scenario.expected,
          reason: '$scenario',
        );
      },
      tags: 'glados',
    );
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
        final event = MockEvent();
        when(() => event.eventId).thenReturn(r'$same-event-id');
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
        final event = MockEvent();
        when(() => event.eventId).thenReturn(r'$release-test');
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
      'no dedup when eventId is unavailable so a legacy/unidentified '
      'event still downloads on its own',
      () async {
        // Historically some events have had empty ids (rare) or mocks
        // that return null. In those cases we fall back to running each
        // call independently rather than stacking them on a shared key.
        var downloadCalls = 0;
        final event = MockEvent();
        when(() => event.eventId).thenReturn('');
        when(() => event.downloadAndDecryptAttachment()).thenAnswer((_) async {
          downloadCalls++;
          return MatrixFile(
            bytes: Uint8List.fromList([downloadCalls]),
            name: 'f',
          );
        });

        final first = downloadAttachmentWithTimeout(event);
        final second = downloadAttachmentWithTimeout(event);
        await Future.wait([first, second]);

        expect(
          downloadCalls,
          2,
          reason:
              'empty eventId must skip the shared-future slot so the '
              'caller retains independent retry semantics',
        );
      },
    );

    test(
      'no dedup when eventId access throws so a pathological mock does '
      'not poison the shared map',
      () async {
        var downloadCalls = 0;
        final event = MockEvent();
        when(() => event.eventId).thenThrow(StateError('no id'));
        when(() => event.downloadAndDecryptAttachment()).thenAnswer((_) async {
          downloadCalls++;
          return MatrixFile(
            bytes: Uint8List.fromList([downloadCalls]),
            name: 'f',
          );
        });

        await downloadAttachmentWithTimeout(event);
        await downloadAttachmentWithTimeout(event);
        expect(downloadCalls, 2);
      },
    );

    test(
      'maps a timeout into FileSystemException carrying the supplied '
      'path for diagnostics',
      () {
        // Runs under fakeAsync so we advance the virtual clock past the
        // configured timeout rather than awaiting a real Duration.
        fakeAsync((async) {
          final event = MockEvent();
          when(() => event.eventId).thenReturn(r'$timeout-test');
          when(
            () => event.downloadAndDecryptAttachment(),
          ).thenAnswer((_) => Completer<MatrixFile>().future);

          Object? caught;
          unawaited(
            downloadAttachmentWithTimeout(
              event,
              pathForError: '/entries/stuck.json',
              timeout: const Duration(seconds: 30),
            ).catchError((Object err) {
              caught = err;
              // Satisfy Future<MatrixFile> return type; the value is
              // swallowed because we never await this future directly.
              return MatrixFile(bytes: Uint8List(0), name: 'err');
            }),
          );

          // Advance past the timeout so `Future.timeout` fires
          // deterministically without a real Timer.
          async.elapse(const Duration(seconds: 31));

          expect(caught, isA<FileSystemException>());
          final err = caught! as FileSystemException;
          expect(err.message, contains('timed out'));
          expect(err.path, '/entries/stuck.json');
        });
      },
    );
  });

  group('wire-format constants', () {
    test(
      'encoding key and gzip marker are pinned against accidental rename',
      () {
        // These are wire-format identifiers shared with remote peers; renaming
        // them breaks decoding of already-sent attachments.
        expect(attachmentEncodingKey, 'com.lotti.encoding');
        expect(attachmentEncodingGzip, 'gzip');
      },
    );
  });

  group('gzipEncodeJson', () {
    test(
      'round-trips a Map through json.encode + utf8.encode + gzip on a '
      'worker isolate, producing bytes that gunzip back into the '
      'original structure — this is the helper used by the outbox bundle '
      'sender to encode the manifest off the UI thread',
      () async {
        final manifest = <String, dynamic>{
          'version': 1,
          'entries': [
            for (var i = 0; i < 5; i++)
              <String, dynamic>{
                'envelope': <String, dynamic>{'id': 'cfg-$i'},
                if (i.isEven)
                  'payload': <String, dynamic>{
                    'index': i,
                    'note': 'entry $i body',
                  },
              },
          ],
        };

        final gzipped = await gzipEncodeJson(manifest);

        expect(gzipped, isA<Uint8List>());
        // Gzip magic bytes confirm the worker actually compressed the
        // payload rather than handing back raw UTF-8 by accident.
        expect(gzipped[0], 0x1f);
        expect(gzipped[1], 0x8b);

        final roundTripped =
            json.decode(utf8.decode(gzip.decode(gzipped)))
                as Map<String, dynamic>;
        expect(roundTripped, manifest);
      },
    );
  });

  group('decodeJsonStringMaybeIsolate', () {
    test(
      'parses small JSON inline (below the 4 KB threshold) without '
      'crossing the isolate boundary',
      () async {
        const tiny = '{"a":1,"b":[true,null,"x"]}';

        final decoded = await decodeJsonStringMaybeIsolate(tiny);

        expect(decoded, <String, dynamic>{
          'a': 1,
          'b': <dynamic>[true, null, 'x'],
        });
      },
    );

    test(
      'offloads large JSON (above the 4 KB threshold) to a worker '
      'isolate and returns the parsed structure intact — covers the '
      'compute hop used by the outbox bundle manifest decode path',
      () async {
        final entries = <Map<String, dynamic>>[
          for (var i = 0; i < 200; i++)
            <String, dynamic>{
              'id': 'entry-$i',
              'note':
                  'a fairly long body string used to push the '
                  'serialised manifest past the inline threshold for '
                  'compute() so the off-isolate parse path runs.',
            },
        ];
        final big = json.encode(<String, dynamic>{'entries': entries});
        expect(big.length, greaterThan(4 * 1024));

        final decoded =
            (await decodeJsonStringMaybeIsolate(big))! as Map<String, dynamic>;

        expect(decoded.keys.toSet(), {'entries'});
        final roundTripped = (decoded['entries'] as List)
            .cast<Map<String, dynamic>>();
        expect(roundTripped, hasLength(200));
        expect(roundTripped.first, entries.first);
        expect(roundTripped.last, entries.last);
      },
    );
  });
}

class _GeneratedCompressionRatio {
  const _GeneratedCompressionRatio({
    required this.raw,
    required this.compressed,
  });

  final int raw;
  final int compressed;

  String get expected => raw <= 0 ? '-' : (compressed / raw).toStringAsFixed(3);

  @override
  String toString() {
    return '_GeneratedCompressionRatio('
        'raw: $raw, '
        'compressed: $compressed, '
        'expected: $expected)';
  }
}

extension _AnyAttachmentDecoding on glados.Any {
  glados.Generator<_GeneratedCompressionRatio> get generatedCompressionRatio =>
      glados.CombinableAny(this).combine2(
        glados.IntAnys(this).intInRange(-10, 10000),
        glados.IntAnys(this).intInRange(0, 10000),
        (raw, compressed) => _GeneratedCompressionRatio(
          raw: raw,
          compressed: compressed,
        ),
      );
}
