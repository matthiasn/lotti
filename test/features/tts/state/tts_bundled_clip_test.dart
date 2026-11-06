import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/state/tts_bundled_clip.dart';

/// Serves fixed bytes for every asset it is asked for, and records the keys.
class _Bundle extends CachingAssetBundle {
  _Bundle(this.bytes);

  final List<int> bytes;
  final keys = <String>[];

  @override
  Future<ByteData> load(String key) async {
    keys.add(key);
    // A view into a larger buffer, as the engine hands assets over: only
    // the asset's own bytes may be written.
    final buffer = Uint8List(bytes.length + 4)
      ..setRange(2, 2 + bytes.length, bytes);
    return ByteData.sublistView(buffer, 2, 2 + bytes.length);
  }
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bundled_clip_test');
  });
  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  test(
    "copies exactly the asset's bytes into a file named after it",
    () async {
      final bundle = _Bundle([1, 2, 3, 4]);

      final file = await copyBundledClip(
        'assets/onboarding/voice_samples/voxtral.wav',
        bundle: bundle,
        tempDirectory: () async => dir,
      );

      expect(bundle.keys, ['assets/onboarding/voice_samples/voxtral.wav']);
      expect(file.parent.path, dir.path);
      expect(file.path, endsWith('_voxtral.wav'));
      expect(await file.readAsBytes(), [1, 2, 3, 4]);
    },
  );

  test('each copy is a file of its own', () async {
    final bundle = _Bundle([9]);

    final first = await copyBundledClip(
      'a.wav',
      bundle: bundle,
      tempDirectory: () async => dir,
    );
    final second = await copyBundledClip(
      'a.wav',
      bundle: bundle,
      tempDirectory: () async => dir,
    );

    expect(first.path, isNot(second.path));
    expect(first.existsSync() && second.existsSync(), isTrue);
  });

  test('the provider hands out the app copier', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(ttsBundledClipCopierProvider), copyBundledClip);
  });
}
