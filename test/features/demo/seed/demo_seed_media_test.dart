import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/demo/seed/demo_seed_media.dart';
import 'package:lotti/utils/image_utils.dart';

import '../../../helpers/entity_factories.dart';

class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this.assets);

  final Map<String, Uint8List> assets;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(assets[key]!);
}

void main() {
  late Directory documentsDirectory;
  late Directory cacheRoot;

  setUp(() {
    documentsDirectory = Directory.systemTemp.createTempSync(
      'lotti-demo-seed-media-documents-',
    );
    cacheRoot = Directory.systemTemp.createTempSync(
      'lotti-demo-seed-media-cache-',
    );
  });

  tearDown(() {
    documentsDirectory.deleteSync(recursive: true);
    cacheRoot.deleteSync(recursive: true);
  });

  test(
    'downloads, verifies, caches, and installs remote image bytes',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final source = _source(bytes: bytes);
      final image = _image(source.fileName);
      var fetches = 0;
      final progress = <(int, int)>[];
      final installer = DemoSeedMediaInstaller(
        cacheRoot: cacheRoot,
        fetchUrl: (_) async {
          fetches++;
          return bytes;
        },
      );

      for (var run = 0; run < 2; run++) {
        final targetRoot = run == 0
            ? documentsDirectory
            : Directory.systemTemp.createTempSync(
                'lotti-demo-seed-media-second-',
              );
        if (run == 1) addTearDown(() => targetRoot.deleteSync(recursive: true));

        final installed = await installer.install(
          documentsDirectory: targetRoot,
          images: [image],
          sources: {image.meta.id: source},
          onProgress: ({required completed, required total}) {
            progress.add((completed, total));
          },
        );

        expect(installed, hasLength(1));
        expect(await installed.single.readAsBytes(), bytes);
        expect(
          installed.single.path,
          getFullImagePath(image, documentsDirectory: targetRoot.path),
        );
      }

      expect(fetches, 1, reason: 'the checksum-addressed cache is reused');
      expect(progress, [(0, 1), (1, 1), (0, 1), (1, 1)]);
    },
  );

  test(
    'falls back to a verified bundled asset when the network fails',
    () async {
      final bytes = Uint8List.fromList([5, 6, 7]);
      final source = _source(bytes: bytes, assetPath: 'assets/cover.webp');
      final image = _image(source.fileName);
      final installer = DemoSeedMediaInstaller(
        bundle: _MemoryAssetBundle({'assets/cover.webp': bytes}),
        cacheRoot: cacheRoot,
        fetchUrl: (_) async => throw const SocketException('offline'),
      );

      final installed = await installer.install(
        documentsDirectory: documentsDirectory,
        images: [image],
        sources: {image.meta.id: source},
      );

      expect(await installed.single.readAsBytes(), bytes);
    },
  );

  test('installs a verified asset-only source without fetching', () async {
    final bytes = Uint8List.fromList([11, 12, 13]);
    final image = _image('asset-only.webp');
    var fetched = false;
    final installer = DemoSeedMediaInstaller(
      bundle: _MemoryAssetBundle({'assets/asset-only.webp': bytes}),
      cacheRoot: cacheRoot,
      fetchUrl: (_) async {
        fetched = true;
        return bytes;
      },
    );

    final installed = await installer.install(
      documentsDirectory: documentsDirectory,
      images: [image],
      sources: {
        image.id: DemoSeedMediaSource(
          fileName: image.data.imageFile,
          sha256: sha256.convert(bytes).toString(),
          assetPath: 'assets/asset-only.webp',
        ),
      },
    );

    expect(fetched, isFalse);
    expect(await installed.single.readAsBytes(), bytes);
  });

  test('discards a corrupt cache entry and refetches verified bytes', () async {
    final bytes = Uint8List.fromList([14, 15, 16]);
    final source = _source(bytes: bytes);
    final image = _image(source.fileName);
    final cached = File('${cacheRoot.path}/${source.sha256}');
    await cached.writeAsBytes([99], flush: true);
    var fetches = 0;
    final installer = DemoSeedMediaInstaller(
      cacheRoot: cacheRoot,
      fetchUrl: (_) async {
        fetches++;
        return bytes;
      },
    );

    final installed = await installer.install(
      documentsDirectory: documentsDirectory,
      images: [image],
      sources: {image.id: source},
    );

    expect(fetches, 1);
    expect(await installed.single.readAsBytes(), bytes);
    expect(await cached.readAsBytes(), bytes);
  });

  test('rejects provenance whose filename differs from the image row', () {
    final bytes = Uint8List.fromList([17]);
    final image = _image('row.webp');
    final installer = DemoSeedMediaInstaller(cacheRoot: cacheRoot);

    expect(
      installer.install(
        documentsDirectory: documentsDirectory,
        images: [image],
        sources: {image.id: _source(bytes: bytes)},
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('does not match row.webp'),
        ),
      ),
    );
  });

  test(
    'default HTTP transport accepts 200 and rejects other statuses',
    () async {
      final bytes = Uint8List.fromList([18, 19]);
      final image = _image('cover.webp');
      final installer = DemoSeedMediaInstaller(
        cacheRoot: cacheRoot,
        httpClientFactory: () => MockClient((request) async {
          if (request.url.path == '/cover.webp') {
            return http.Response.bytes(bytes, HttpStatus.ok);
          }
          return http.Response('', HttpStatus.serviceUnavailable);
        }),
      );

      final installed = await installer.install(
        documentsDirectory: documentsDirectory,
        images: [image],
        sources: {
          image.id: DemoSeedMediaSource(
            fileName: image.data.imageFile,
            sha256: sha256.convert(bytes).toString(),
            sourceUrl: 'https://media.example/cover.webp',
          ),
        },
        allowAssetFallback: false,
      );
      expect(await installed.single.readAsBytes(), bytes);

      final unavailable = _image('unavailable.webp');
      final unavailableBytes = Uint8List.fromList([20]);
      await expectLater(
        installer.install(
          documentsDirectory: documentsDirectory,
          images: [unavailable],
          sources: {
            unavailable.id: DemoSeedMediaSource(
              fileName: unavailable.data.imageFile,
              sha256: sha256.convert(unavailableBytes).toString(),
              sourceUrl: 'https://media.example/unavailable.webp',
            ),
          },
          allowAssetFallback: false,
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('HTTP 503'),
          ),
        ),
      );
    },
  );

  test(
    'reports a missing usable source when its bundled fallback is absent',
    () async {
      final bytes = Uint8List.fromList([24]);
      final image = _image('bundle-only.webp');
      final installer = DemoSeedMediaInstaller(cacheRoot: cacheRoot);

      await expectLater(
        installer.install(
          documentsDirectory: documentsDirectory,
          images: [image],
          sources: {
            image.id: DemoSeedMediaSource(
              fileName: image.data.imageFile,
              sha256: sha256.convert(bytes).toString(),
              assetPath: 'assets/bundle-only.webp',
            ),
          },
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('No available seed media source'),
          ),
        ),
      );
    },
  );

  test('required remote media fails closed and leaves no image file', () async {
    final expected = Uint8List.fromList([8, 9, 10]);
    final source = _source(bytes: expected);
    final image = _image(source.fileName);
    final installer = DemoSeedMediaInstaller(
      cacheRoot: cacheRoot,
      fetchUrl: (_) async => Uint8List.fromList([99]),
    );

    await expectLater(
      installer.install(
        documentsDirectory: documentsDirectory,
        images: [image],
        sources: {image.meta.id: source},
        allowAssetFallback: false,
      ),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('Checksum mismatch'),
          'a checksum mismatch',
        ),
      ),
    );
    expect(
      File(
        getFullImagePath(image, documentsDirectory: documentsDirectory.path),
      ).existsSync(),
      isFalse,
    );
  });

  test('rejects an image whose seed provenance is missing', () async {
    final image = _image('missing.webp');
    final installer = DemoSeedMediaInstaller(cacheRoot: cacheRoot);

    await expectLater(
      installer.install(
        documentsDirectory: documentsDirectory,
        images: [image],
        sources: const {},
      ),
      throwsA(isA<StateError>()),
    );
  });
}

DemoSeedMediaSource _source({required Uint8List bytes, String? assetPath}) =>
    DemoSeedMediaSource(
      fileName: 'cover.webp',
      sha256: sha256.convert(bytes).toString(),
      sourceUrl: 'https://media.example/demo/cover.webp',
      assetPath: assetPath,
    );

JournalImage _image(String fileName) {
  final image = TestImageFactory.create(id: 'image-id');
  return image.copyWith(
    data: image.data.copyWith(
      imageFile: fileName,
      imageDirectory: '/manual_demo/',
    ),
  );
}
