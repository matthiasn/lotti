import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/utils/thumbhash.dart';

// Relative import: the backfill is a repo tool, not part of the `lotti`
// package, so it has no `package:` URI.
import '../../../tool/demo_media/thumb_hash_backfill.dart';

/// PNG bytes for a flat-colour image of the given size.
Uint8List _png({
  int width = 6,
  int height = 4,
  int red = 200,
  int green = 40,
  int blue = 40,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(red, green, blue));
  return Uint8List.fromList(img.encodePng(image));
}

String _digest(Uint8List bytes) => sha256.convert(bytes).toString();

DemoMediaAsset _asset(String name, Uint8List bytes) => DemoMediaAsset(
  id: 'image-$name',
  fileName: '$name.webp',
  sha256: _digest(bytes),
  taskId: 'task-$name',
  categoryId: 'category',
  capturedDaysAgo: 1,
  capturedHour: 9,
  isCover: true,
);

/// A downloader that answers each URI from a scripted queue of outcomes —
/// bytes to return or an exception to throw — and remembers every call.
class _ScriptedDownloads {
  _ScriptedDownloads(Map<String, List<Object>> script)
    : _script = {
        for (final entry in script.entries)
          entry.key: List<Object>.of(entry.value),
      };

  final Map<String, List<Object>> _script;
  final List<String> calls = [];

  Future<Uint8List> call(Uri uri) async {
    final name = uri.pathSegments.last;
    calls.add(name);
    final queue = _script[name];
    if (queue == null || queue.isEmpty) {
      throw StateError('No scripted outcome left for $name');
    }
    final outcome = queue.removeAt(0);
    if (outcome is Uint8List) return outcome;
    throw outcome as Exception;
  }
}

ThumbHashDownloadException _status(DemoMediaAsset asset, int statusCode) =>
    ThumbHashDownloadException(asset.uri, statusCode: statusCode);

void main() {
  late Uint8List redBytes;
  late Uint8List blueBytes;
  late Uint8List greenBytes;
  late DemoMediaAsset red;
  late DemoMediaAsset blue;
  late DemoMediaAsset green;
  late List<Duration> delays;
  late StringBuffer log;

  Future<void> noDelay(Duration duration) async => delays.add(duration);

  setUp(() {
    redBytes = _png();
    blueBytes = _png(red: 40, blue: 200);
    greenBytes = _png(red: 40, green: 200);
    red = _asset('red', redBytes);
    blue = _asset('blue', blueBytes);
    green = _asset('green', greenBytes);
    delays = [];
    log = StringBuffer();
  });

  group('thumbHashForImageBytes', () {
    test('hashes a small image from its own pixels', () {
      final decoded = img.decodeImage(redBytes)!;
      final expected = ThumbHash.encode(
        width: decoded.width,
        height: decoded.height,
        rgba: decoded
            .convert(format: img.Format.uint8, numChannels: 4)
            .getBytes(order: img.ChannelOrder.rgba),
      );

      expect(thumbHashForImageBytes(redBytes), expected);
    });

    test('shrinks a large image to the encoder input limit, keeping its '
        'aspect ratio', () {
      final hash = thumbHashForImageBytes(_png(width: 300, height: 200));

      // 300×200 shrinks to 100×67, whose luminance grid is 7×5 wide; the
      // raster the hash decodes to carries that landscape ratio.
      expect(hash.aspectRatio, 7 / 5);
      final pixels = hash.decode();
      expect(pixels.width, thumbHashRasterExtent);
      expect(pixels.height, (thumbHashRasterExtent / (7 / 5)).round());
    });

    test('keeps the colour of what it shrinks', () {
      final pixels = thumbHashForImageBytes(
        _png(width: 400, height: 400, red: 40, green: 200),
      ).decode();

      final centre = (pixels.height ~/ 2) * pixels.width + pixels.width ~/ 2;
      expect(pixels.rgba[centre * 4 + 1], greaterThan(pixels.rgba[centre * 4]));
      expect(
        pixels.rgba[centre * 4 + 1],
        greaterThan(pixels.rgba[centre * 4 + 2]),
      );
    });

    test('rejects bytes that are not an image', () {
      expect(
        () => thumbHashForImageBytes(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('runThumbHashBackfill', () {
    test('hashes every object the map does not cover and leaves covered '
        'ones alone', () async {
      final downloads = _ScriptedDownloads({
        'red.webp': [redBytes],
        'green.webp': [greenBytes],
      });
      const blueHash = 'already-there';

      final report = await runThumbHashBackfill(
        catalog: [red, blue, green],
        existing: {blue.sha256: blueHash},
        download: downloads.call,
        delay: noDelay,
        log: log,
      );

      expect(report.processed, ['red.webp', 'green.webp']);
      expect(report.skipped, ['blue.webp']);
      expect(report.pruned, isEmpty);
      expect(report.hasFailures, isFalse);
      expect(report.hashes, {
        red.sha256: thumbHashForImageBytes(redBytes).toBase64(),
        blue.sha256: blueHash,
        green.sha256: thumbHashForImageBytes(greenBytes).toBase64(),
      });
      expect(downloads.calls, ['red.webp', 'green.webp']);
      expect(delays, isEmpty);
      expect(report.summary, 'processed 2, skipped 1, pruned 0, failed 0');
      expect(log.toString(), contains('- blue.webp: already hashed'));
      expect(
        log.toString(),
        contains('+ red.webp: ${report.hashes[red.sha256]}'),
      );
    });

    test(
      'a second run downloads nothing and leaves the map as it was',
      () async {
        final first = await runThumbHashBackfill(
          catalog: [red, blue],
          existing: const {},
          download: _ScriptedDownloads({
            'red.webp': [redBytes],
            'blue.webp': [blueBytes],
          }).call,
          delay: noDelay,
          log: log,
        );
        final downloads = _ScriptedDownloads(const {});

        final second = await runThumbHashBackfill(
          catalog: [red, blue],
          existing: first.hashes,
          download: downloads.call,
          delay: noDelay,
          log: log,
        );

        expect(downloads.calls, isEmpty);
        expect(second.processed, isEmpty);
        expect(second.skipped, ['red.webp', 'blue.webp']);
        expect(second.hashes, first.hashes);
        expect(
          renderThumbHashMap(second.hashes),
          renderThumbHashMap(first.hashes),
        );
      },
    );

    test('force recomputes objects that already have a hash', () async {
      final downloads = _ScriptedDownloads({
        'red.webp': [redBytes],
      });

      final report = await runThumbHashBackfill(
        catalog: [red],
        existing: {red.sha256: 'stale'},
        download: downloads.call,
        delay: noDelay,
        log: log,
        force: true,
      );

      expect(downloads.calls, ['red.webp']);
      expect(report.processed, ['red.webp']);
      expect(report.skipped, isEmpty);
      expect(report.hashes[red.sha256], isNot('stale'));
    });

    test('one failing object does not abort the batch, and keeps the hash it '
        'had', () async {
      final downloads = _ScriptedDownloads({
        'red.webp': [redBytes],
        'blue.webp': [_status(blue, 404)],
        'green.webp': [greenBytes],
      });

      final report = await runThumbHashBackfill(
        catalog: [red, blue, green],
        existing: {blue.sha256: 'kept'},
        download: downloads.call,
        delay: noDelay,
        log: log,
        force: true,
      );

      expect(report.processed, ['red.webp', 'green.webp']);
      expect(report.failures.keys, ['blue.webp']);
      expect(
        report.failures['blue.webp'],
        isA<ThumbHashDownloadException>().having(
          (e) => e.statusCode,
          'statusCode',
          404,
        ),
      );
      expect(report.hasFailures, isTrue);
      expect(report.hashes[blue.sha256], 'kept');
      expect(report.hashes.keys, containsAll([red.sha256, green.sha256]));
      // A missing object is a dead end: no retry, no wait.
      expect(downloads.calls, ['red.webp', 'blue.webp', 'green.webp']);
      expect(delays, isEmpty);
      expect(log.toString(), contains('! blue.webp: HTTP 404'));
      expect(report.summary, 'processed 2, skipped 0, pruned 0, failed 1');
    });

    test('retries a rate-limited download with growing backoff', () async {
      final downloads = _ScriptedDownloads({
        'red.webp': [_status(red, 429), _status(red, 503), redBytes],
      });

      final report = await runThumbHashBackfill(
        catalog: [red],
        existing: const {},
        download: downloads.call,
        delay: noDelay,
        log: log,
      );

      expect(report.processed, ['red.webp']);
      expect(report.hasFailures, isFalse);
      expect(downloads.calls, ['red.webp', 'red.webp', 'red.webp']);
      expect(delays, const [Duration(seconds: 1), Duration(seconds: 2)]);
      expect(
        log.toString(),
        contains(
          'red.webp: HTTP 429 for ${red.uri}, retrying in 1s '
          '(attempt 1 of $thumbHashBackfillMaxAttempts)',
        ),
      );
    });

    test('gives up on an object that stays rate-limited', () async {
      final downloads = _ScriptedDownloads({
        'red.webp': [for (var i = 0; i < 3; i++) _status(red, 429)],
      });

      final report = await runThumbHashBackfill(
        catalog: [red],
        existing: const {},
        download: downloads.call,
        delay: noDelay,
        log: log,
        maxAttempts: 3,
      );

      expect(report.failures.keys, ['red.webp']);
      expect(downloads.calls, hasLength(3));
      expect(delays, const [Duration(seconds: 1), Duration(seconds: 2)]);
      expect(report.hashes, isEmpty);
    });

    test('rejects bytes whose digest disagrees with the catalog', () async {
      final downloads = _ScriptedDownloads({
        'red.webp': [blueBytes],
      });

      final report = await runThumbHashBackfill(
        catalog: [red],
        existing: const {},
        download: downloads.call,
        delay: noDelay,
        log: log,
      );

      expect(report.failures['red.webp'], isA<StateError>());
      expect(
        report.failures['red.webp'].toString(),
        contains('catalog says ${red.sha256}'),
      );
      expect(report.hashes, isEmpty);
    });

    test('rejects an object that is not a decodable image', () async {
      final junk = Uint8List.fromList([9, 8, 7, 6, 5]);
      final asset = _asset('junk', junk);

      final report = await runThumbHashBackfill(
        catalog: [asset],
        existing: const {},
        download: _ScriptedDownloads({
          'junk.webp': [junk],
        }).call,
        delay: noDelay,
        log: log,
      );

      expect(report.failures['junk.webp'], isA<FormatException>());
      expect(report.hashes, isEmpty);
    });

    test('prunes digests no catalog object carries any more', () async {
      final report = await runThumbHashBackfill(
        catalog: [red],
        existing: {red.sha256: 'current', 'deadbeef': 'stale'},
        download: _ScriptedDownloads(const {}).call,
        delay: noDelay,
        log: log,
      );

      expect(report.pruned, ['deadbeef']);
      expect(report.hashes, {red.sha256: 'current'});
      expect(log.toString(), contains('x deadbeef: no longer in the catalog'));
      expect(report.summary, 'processed 0, skipped 1, pruned 1, failed 0');
    });
  });

  group('downloadWithClient', () {
    final uri = Uri.parse('https://example.test/demo/red.webp');

    test('hands back the body of a 200', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url, uri);
        return http.Response.bytes(redBytes, 200);
      });

      expect(await downloadWithClient(client, uri), redBytes);
    });

    test('maps a 404 onto a failure that is not worth retrying', () async {
      final client = MockClient((_) async => http.Response('gone', 404));

      await expectLater(
        () => downloadWithClient(client, uri),
        throwsA(
          isA<ThumbHashDownloadException>()
              .having((e) => e.statusCode, 'statusCode', 404)
              .having((e) => e.isTransient, 'isTransient', isFalse)
              .having((e) => e.toString(), 'toString', 'HTTP 404 for $uri'),
        ),
      );
    });

    test('treats rate limiting and server errors as transient', () async {
      for (final status in [429, 500, 503]) {
        final client = MockClient((_) async => http.Response('', status));
        await expectLater(
          () => downloadWithClient(client, uri),
          throwsA(
            isA<ThumbHashDownloadException>()
                .having((e) => e.statusCode, 'statusCode', status)
                .having((e) => e.isTransient, 'isTransient', isTrue),
          ),
        );
      }
    });

    test('treats a connection failure as transient', () async {
      final client = MockClient(
        (_) async => throw http.ClientException('refused', uri),
      );

      await expectLater(
        () => downloadWithClient(client, uri),
        throwsA(
          isA<ThumbHashDownloadException>()
              .having((e) => e.statusCode, 'statusCode', isNull)
              .having((e) => e.isTransient, 'isTransient', isTrue)
              .having((e) => e.cause, 'cause', isA<http.ClientException>())
              .having(
                (e) => e.toString(),
                'toString',
                startsWith('No response for $uri: '),
              ),
        ),
      );
    });

    test('treats a timeout as transient', () {
      fakeAsync((async) {
        final client = MockClient(
          (_) => Completer<http.Response>().future,
        );
        Object? failure;
        unawaited(
          downloadWithClient(
            client,
            uri,
            timeout: const Duration(seconds: 1),
          ).then<void>((_) {}, onError: (Object error) => failure = error),
        );

        async.elapse(const Duration(seconds: 2));

        expect(
          failure,
          isA<ThumbHashDownloadException>()
              .having((e) => e.isTransient, 'isTransient', isTrue)
              .having((e) => e.cause, 'cause', isA<TimeoutException>()),
        );
      });
    });
  });

  group('renderThumbHashMap', () {
    test('renders an empty map on one line', () {
      final source = renderThumbHashMap(const {});

      expect(source, startsWith('// GENERATED CODE - DO NOT MODIFY BY HAND\n'));
      expect(source, contains('make demo_media_thumb_hashes'));
      expect(
        source,
        endsWith(
          '/// Base64 ThumbHash by demo-media object `sha256`.\n'
          'const Map<String, String> demoMediaThumbHashes = '
          '<String, String>{};\n',
        ),
      );
    });

    test('renders entries sorted by digest, one formatted entry each', () {
      final source = renderThumbHashMap({
        'ffff': 'last',
        '0000': 'first',
        '7777': 'middle',
      });

      expect(
        source,
        endsWith(
          'const Map<String, String> demoMediaThumbHashes = <String, String>{\n'
          "  '0000':\n"
          "      'first',\n"
          "  '7777':\n"
          "      'middle',\n"
          "  'ffff':\n"
          "      'last',\n"
          '};\n',
        ),
      );
    });
  });
}
