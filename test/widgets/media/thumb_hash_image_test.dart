import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/thumbhash.dart';
import 'package:lotti/widgets/media/thumb_hash_image.dart';

/// An opaque 8×6 raster, red on the left and blue on the right, so the
/// decoded frame has recognisable content to compare pixel for pixel.
ThumbHash _splitHash() {
  const width = 8;
  const height = 6;
  final rgba = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      rgba[i] = x < width ~/ 2 ? 220 : 20;
      rgba[i + 1] = 30;
      rgba[i + 2] = x < width ~/ 2 ? 20 : 220;
      rgba[i + 3] = 255;
    }
  }
  return ThumbHash.encode(width: width, height: height, rgba: rgba);
}

/// A flat mid-grey raster: a different hash from [_splitHash].
ThumbHash _greyHash() => ThumbHash.encode(
  width: 4,
  height: 4,
  rgba: Uint8List.fromList(
    List.filled(4 * 4, [128, 128, 128, 255]).expand((px) => px).toList(),
  ),
);

/// Resolves [provider] to its first frame.
Future<ImageInfo> _firstFrame(ImageProvider<Object> provider) {
  final completer = Completer<ImageInfo>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      completer.complete(info);
    },
    onError: (error, stackTrace) {
      stream.removeListener(listener);
      completer.completeError(error, stackTrace);
    },
  );
  stream.addListener(listener);
  return completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    imageCache
      ..clear()
      ..clearLiveImages();
  });

  group('ThumbHashImage', () {
    test('obtainKey answers the provider itself, without a frame delay', () {
      final provider = ThumbHashImage(_splitHash());
      final key = provider.obtainKey(ImageConfiguration.empty);

      expect(key, isA<SynchronousFuture<ThumbHashImage>>());
      ThumbHashImage? resolved;
      key.then((value) => resolved = value);
      expect(resolved, same(provider));
    });

    test('providers of the same hash are equal, so the cache shares them', () {
      final hash = _splitHash();
      final a = ThumbHashImage(hash);
      final b = ThumbHashImage(ThumbHash.fromBase64(hash.toBase64()));

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(ThumbHashImage(_greyHash()))));
      expect(a == Object(), isFalse);
    });

    test('toString names the hash it draws', () {
      final hash = _splitHash();

      expect(
        ThumbHashImage(hash).toString(),
        'ThumbHashImage(${hash.toBase64()})',
      );
    });

    test('resolves to the decoded raster, pixel for pixel', () async {
      final hash = _splitHash();
      final expected = hash.decode();

      final info = await _firstFrame(ThumbHashImage(hash));
      addTearDown(info.dispose);

      expect(info.scale, 1);
      expect(info.image.width, expected.width);
      expect(info.image.height, expected.height);
      // Opaque source, so premultiplied and straight RGBA coincide and the
      // engine must hand back exactly the bytes the decoder produced.
      final bytes = await info.image.toByteData();
      expect(bytes!.buffer.asUint8List(), expected.rgba);
      expect(expected.width, thumbHashRasterExtent);
      // Left column reads red, right column reads blue: the raster is the
      // hash's content, not a blank of the right size.
      final rowStart = (expected.height ~/ 2) * expected.width * 4;
      final left = expected.rgba.sublist(rowStart, rowStart + 4);
      final right = expected.rgba.sublist(
        rowStart + (expected.width - 1) * 4,
        rowStart + expected.width * 4,
      );
      expect(left[0], greaterThan(left[2]));
      expect(right[2], greaterThan(right[0]));
    });

    test(
      'a second resolve of the same hash is served from the cache',
      () async {
        final hash = _splitHash();
        final first = await _firstFrame(ThumbHashImage(hash));
        addTearDown(first.dispose);

        final provider = ThumbHashImage(ThumbHash.fromBase64(hash.toBase64()));
        final key = await provider.obtainKey(ImageConfiguration.empty);

        expect(imageCache.containsKey(key), isTrue);
        expect(imageCache.currentSize, 1);
        final second = await _firstFrame(provider);
        addTearDown(second.dispose);
        expect(second.isCloneOf(first), isTrue);
      },
    );
  });

  group('ThumbHashStreamCompleter', () {
    late ImageStreamCompleter completer;
    late Completer<ImageInfo> frame;
    late List<ImageInfo> received;
    late List<Object> errors;
    late ImageStreamListener listener;

    setUp(() {
      frame = Completer<ImageInfo>();
      received = [];
      errors = [];
      completer = ThumbHashStreamCompleter(
        frame.future,
        debugLabel: 'test',
        informationCollector: () => [
          DiagnosticsProperty<String>('detail', 'under test'),
        ],
      );
      listener = ImageStreamListener(
        (info, _) => received.add(info),
        onError: (error, _) => errors.add(error),
      );
    });

    test('hands the frame to a listener that is still there', () async {
      completer.addListener(listener);
      final image = await createTestImage(width: 2, height: 2);
      addTearDown(image.dispose);

      frame.complete(ImageInfo(image: image.clone()));
      await pumpEventQueue();

      expect(received, hasLength(1));
      expect(received.single.image.width, 2);
      expect(completer.debugLabel, 'test');
      completer.removeListener(listener);
    });

    test('drops a frame that arrives after the last listener left', () async {
      completer
        ..addListener(listener)
        ..removeListener(listener);
      final image = await createTestImage(width: 2, height: 2);
      final late = ImageInfo(image: image.clone());
      addTearDown(image.dispose);

      // Would throw "Stream has been disposed" from setImage; must not.
      frame.complete(late);
      await pumpEventQueue();

      expect(received, isEmpty);
      expect(late.image.debugDisposed, isTrue);
    });

    test('reports an error to a listener that handles errors', () async {
      completer.addListener(listener);
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      frame.completeError(StateError('engine said no'));
      await pumpEventQueue();

      expect(errors, [isA<StateError>()]);
      expect(received, isEmpty);
      // A handled error is not also shouted at FlutterError.
      expect(reported, isEmpty);
      completer.removeListener(listener);
    });

    test('reports an error nobody handles to FlutterError, quietly, with the '
        'collected information', () async {
      final deaf = ImageStreamListener((info, _) => received.add(info));
      completer.addListener(deaf);
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      frame.completeError(StateError('engine said no'));
      await pumpEventQueue();

      expect(received, isEmpty);
      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<StateError>());
      expect(reported.single.silent, isTrue);
      expect(
        reported.single.informationCollector!().map((n) => n.toString()),
        contains('detail: under test'),
      );
      completer.removeListener(deaf);
    });

    test('keeps quiet about an error after the last listener left', () async {
      completer
        ..addListener(listener)
        ..removeListener(listener);
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      frame.completeError(StateError('engine said no'));
      await pumpEventQueue();

      expect(errors, isEmpty);
      expect(reported, isEmpty);
    });
  });
}
