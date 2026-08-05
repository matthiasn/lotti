import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/media/demo_media_hydrator.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('demo_media_hydrator_');
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  DemoMediaAsset asset(String name, List<int> bytes) => DemoMediaAsset(
    id: 'image-$name',
    fileName: '$name.webp',
    sha256: sha256.convert(bytes).toString(),
    taskId: 'task-$name',
    categoryId: 'test-category',
    capturedDaysAgo: 0,
    capturedHour: 10,
    isCover: true,
  );

  File target(DemoMediaAsset asset) =>
      File(p.joinAll([root.path, ...asset.relativePath.split('/')]));

  test(
    'downloads a missing catalog asset and installs it atomically',
    () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final image = asset('missing', bytes);
      var requests = 0;
      final hydrator = DemoMediaHydrator(
        root: root,
        assets: [image],
        download: (uri) async {
          requests++;
          expect(uri, image.uri);
          return bytes;
        },
      );

      final result = await hydrator.hydrate();

      expect(requests, 1);
      expect(await target(image).readAsBytes(), bytes);
      expect(File('${target(image).path}.part').existsSync(), isFalse);
      expect(result.downloaded, 1);
      expect(result.alreadyComplete, 0);
      expect(result.isComplete, isTrue);
    },
  );

  test('does not request an asset whose local checksum is current', () async {
    final bytes = Uint8List.fromList([5, 6, 7]);
    final image = asset('complete', bytes);
    await target(image).parent.create(recursive: true);
    await target(image).writeAsBytes(bytes);
    var requests = 0;
    final hydrator = DemoMediaHydrator(
      root: root,
      assets: [image],
      download: (uri) async {
        requests++;
        return bytes;
      },
    );

    final result = await hydrator.hydrate();

    expect(requests, 0);
    expect(result.alreadyComplete, 1);
    expect(result.downloaded, 0);
  });

  test('replaces a corrupt local file with the catalog bytes', () async {
    final bytes = Uint8List.fromList([8, 9, 10]);
    final image = asset('corrupt', bytes);
    await target(image).parent.create(recursive: true);
    await target(image).writeAsBytes([99]);
    final hydrator = DemoMediaHydrator(
      root: root,
      assets: [image],
      download: (uri) async => bytes,
    );

    final result = await hydrator.hydrate();

    expect(await target(image).readAsBytes(), bytes);
    expect(result.downloaded, 1);
  });

  test('contains one failure and continues hydrating other assets', () async {
    final goodBytes = Uint8List.fromList([11, 12]);
    final badBytes = Uint8List.fromList([13, 14]);
    final good = asset('good', goodBytes);
    final bad = asset('bad', badBytes);
    final errors = <String>[];
    final hydrator = DemoMediaHydrator(
      root: root,
      assets: [bad, good],
      concurrency: 1,
      download: (uri) async => uri == bad.uri ? goodBytes : goodBytes,
      onError: (asset, error, stackTrace) => errors.add(asset.fileName),
    );

    final result = await hydrator.hydrate();

    expect(target(bad).existsSync(), isFalse);
    expect(await target(good).readAsBytes(), goodBytes);
    expect(errors, [bad.fileName]);
    expect(result.failed, 1);
    expect(result.downloaded, 1);
    expect(result.isComplete, isFalse);
  });

  test(
    'dispose prevents an in-flight response from writing into the tenant',
    () async {
      final bytes = Uint8List.fromList([15, 16]);
      final image = asset('cancelled', bytes);
      final response = Completer<Uint8List>();
      final requested = Completer<void>();
      var downloaderClosed = false;
      final hydrator = DemoMediaHydrator(
        root: root,
        assets: [image],
        download: (uri) {
          requested.complete();
          return response.future;
        },
        closeDownloader: () => downloaderClosed = true,
      );

      final hydration = hydrator.hydrate();
      await requested.future;
      hydrator.dispose();
      response.complete(bytes);
      final result = await hydration;

      expect(downloaderClosed, isTrue);
      expect(target(image).existsSync(), isFalse);
      expect(result.cancelled, 1);
    },
  );

  test('network downloader installs a successful HTTP response', () async {
    final bytes = Uint8List.fromList([17, 18, 19]);
    final image = asset('network', bytes);
    final client = MockClient((request) async {
      expect(request.url, image.uri);
      return http.Response.bytes(bytes, HttpStatus.ok);
    });
    final hydrator = DemoMediaHydrator.network(
      root: root,
      assets: [image],
      client: client,
    );

    final result = await hydrator.hydrate();
    hydrator.dispose();

    expect(result.downloaded, 1);
    expect(await target(image).readAsBytes(), bytes);
  });

  test(
    'network factory owns its default client for an empty catalog',
    () async {
      final hydrator = DemoMediaHydrator.network(
        root: root,
        assets: const [],
      );

      final result = await hydrator.hydrate();
      hydrator.dispose();

      expect(result.isComplete, isTrue);
      expect(result.downloaded, 0);
      expect(result.alreadyComplete, 0);
    },
  );

  test('network downloader contains a non-success HTTP response', () async {
    final bytes = Uint8List.fromList([20]);
    final image = asset('not-found', bytes);
    final errors = <Object>[];
    final hydrator = DemoMediaHydrator.network(
      root: root,
      assets: [image],
      client: MockClient(
        (request) async => http.Response('', HttpStatus.notFound),
      ),
      onError: (asset, error, stackTrace) => errors.add(error),
    );

    final result = await hydrator.hydrate();
    hydrator.dispose();

    expect(result.failed, 1);
    expect(errors.single, isA<HttpException>());
    expect(target(image).existsSync(), isFalse);
  });

  test('dispose cancels the in-flight and queued catalog assets', () async {
    final bytes = Uint8List.fromList([21, 22]);
    final images = [
      asset('first', bytes),
      asset('second', bytes),
      asset('third', bytes),
    ];
    final response = Completer<Uint8List>();
    final firstRequested = Completer<void>();
    final requested = <Uri>[];
    final hydrator = DemoMediaHydrator(
      root: root,
      assets: images,
      concurrency: 1,
      download: (uri) {
        requested.add(uri);
        firstRequested.complete();
        return response.future;
      },
    );

    final hydration = hydrator.hydrate();
    await firstRequested.future;
    hydrator.dispose();
    response.complete(bytes);
    final result = await hydration;

    expect(requested, [images.first.uri]);
    expect(result.cancelled, 3);
    expect(images.map(target).any((file) => file.existsSync()), isFalse);
  });

  test('retries rename after removing a Windows-style destination', () async {
    final bytes = Uint8List.fromList([23, 24]);
    final image = asset('rename-fallback', bytes);
    var renameCalls = 0;
    final hydrator = DemoMediaHydrator(
      root: root,
      assets: [image],
      download: (uri) async {
        await target(image).parent.create(recursive: true);
        await target(image).writeAsBytes([99]);
        return bytes;
      },
      renameFile: (source, targetPath) {
        renameCalls++;
        if (renameCalls == 1) {
          throw FileSystemException('destination exists', targetPath);
        }
        return source.rename(targetPath);
      },
    );

    final result = await hydrator.hydrate();

    expect(result.downloaded, 1);
    expect(renameCalls, 2);
    expect(await target(image).readAsBytes(), bytes);
  });

  test('redownloads an existing file whose digest cannot be read', () async {
    final bytes = Uint8List.fromList([25, 26]);
    final image = asset('unreadable', bytes);
    await target(image).parent.create(recursive: true);
    await target(image).writeAsBytes([99]);
    var requests = 0;
    final hydrator = DemoMediaHydrator(
      root: root,
      assets: [image],
      download: (uri) async {
        requests++;
        return bytes;
      },
      digestFile: (file) => throw const FileSystemException('unreadable'),
    );

    final result = await hydrator.hydrate();

    expect(requests, 1);
    expect(result.downloaded, 1);
    expect(await target(image).readAsBytes(), bytes);
  });
}
