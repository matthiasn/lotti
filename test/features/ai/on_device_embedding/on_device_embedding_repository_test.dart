import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/on_device_embedding/embedding_model.dart';
import 'package:lotti/features/ai/on_device_embedding/gemma_embedder.dart';
import 'package:lotti/features/ai/on_device_embedding/on_device_embedding_repository.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() => registerFallbackValue(embeddingGemma));

  late MockPinnedModelFiles files;
  late MockGemmaEmbedder embedder;
  late List<String> loadedFrom;
  late Future<GemmaEmbedder> Function(String) load;

  final document = Float32List.fromList([1, 0]);
  final query = Float32List.fromList([0, 1]);

  setUp(() {
    files = MockPinnedModelFiles();
    embedder = MockGemmaEmbedder();
    loadedFrom = [];
    load = (directory) async => embedder;
    when(() => files.isInstalled(any())).thenAnswer((_) async => true);
    when(
      () => files.directory(any()),
    ).thenAnswer((_) async => '/support/embedding_models/model');
    when(() => embedder.embedDocument(any())).thenAnswer((_) async => document);
    when(() => embedder.embedQuery(any())).thenAnswer((_) async => query);
    when(embedder.dispose).thenAnswer((_) async {});
  });

  OnDeviceEmbeddingRepository repository() => OnDeviceEmbeddingRepository(
    files: files,
    load: (directory) {
      loadedFrom.add(directory);
      return load(directory);
    },
  );

  test('makes vectors with EmbeddingGemma and names it on every vector', () {
    final repo = repository();

    expect(repo.model, same(embeddingGemma));
    expect(repo.modelId, 'embeddinggemma-300m-q4');
  });

  group('isPlatformSupported', () {
    late List<bool> original;

    setUp(() {
      original = [
        platform.isMacOS,
        platform.isIOS,
        platform.isLinux,
        platform.isAndroid,
        platform.isWindows,
      ];
      // A clean baseline, so the host platform does not leak in.
      platform.isMacOS = false;
      platform.isIOS = false;
      platform.isLinux = false;
      platform.isAndroid = false;
      platform.isWindows = false;
    });
    tearDown(() {
      platform.isMacOS = original[0];
      platform.isIOS = original[1];
      platform.isLinux = original[2];
      platform.isAndroid = original[3];
      platform.isWindows = original[4];
    });

    test('is false on Windows, whose plugin runs on the platform thread', () {
      platform.isWindows = true;

      expect(OnDeviceEmbeddingRepository.isPlatformSupported, isFalse);
    });

    for (final entry in <String, void Function()>{
      'macOS': () => platform.isMacOS = true,
      'iOS': () => platform.isIOS = true,
      'Linux': () => platform.isLinux = true,
      'Android': () => platform.isAndroid = true,
    }.entries) {
      test('is true on ${entry.key}', () {
        entry.value();

        expect(OnDeviceEmbeddingRepository.isPlatformSupported, isTrue);
      });
    }
  });

  test('is absent until the composition root supplies one', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(onDeviceEmbeddingRepositoryProvider), isNull);
  });

  test('keeps its own download files when none are given', () async {
    final repo = OnDeviceEmbeddingRepository();

    expect(repo.model, same(embeddingGemma));
    expect(repo.isInstalling, isFalse);
    await repo.close();
  });

  test('embeds documents and queries with the model it loads once', () async {
    final repo = repository();

    expect(await repo.embedDocument('a note'), same(document));
    expect(await repo.embedQuery('a search'), same(query));
    await repo.embedDocument('another note');

    expect(loadedFrom, ['/support/embedding_models/model']);
    verify(() => embedder.embedDocument('a note')).called(1);
    verify(() => embedder.embedQuery('a search')).called(1);
  });

  test('concurrent first calls share one load', () async {
    final loaded = Completer<GemmaEmbedder>();
    load = (_) => loaded.future;
    final repo = repository();

    final first = repo.embedDocument('one');
    final second = repo.embedQuery('two');
    await pumpEventQueue();
    loaded.complete(embedder);

    expect(await first, same(document));
    expect(await second, same(query));
    expect(loadedFrom, hasLength(1));
  });

  test('refuses to embed while the model is not downloaded', () async {
    when(() => files.isInstalled(any())).thenAnswer((_) async => false);
    final repo = repository();

    await expectLater(
      repo.embedDocument('a note'),
      throwsA(
        isA<EmbeddingModelNotInstalledException>()
            .having((e) => e.modelId, 'modelId', 'embeddinggemma-300m-q4')
            .having((e) => '$e', 'message', contains('not downloaded')),
      ),
    );
    expect(loadedFrom, isEmpty);
  });

  test('tries a failed load again on the next call', () async {
    var attempts = 0;
    load = (_) async {
      if (attempts++ == 0) throw StateError('broken session');
      return embedder;
    };
    final repo = repository();

    await expectLater(repo.embedDocument('a note'), throwsStateError);
    expect(await repo.embedDocument('a note'), same(document));
    expect(loadedFrom, hasLength(2));
  });

  test('installs through the pinned files, reporting progress', () async {
    when(
      () => files.install(any(), onProgress: any(named: 'onProgress')),
    ).thenAnswer((invocation) async {
      (invocation.namedArguments[#onProgress] as void Function(double))(0.5);
      return '/support/embedding_models/model';
    });
    when(() => files.isDownloading(any())).thenReturn(true);
    final repo = repository();
    final progress = <double>[];

    await repo.install(onProgress: progress.add);

    expect(progress, [0.5]);
    expect(repo.isInstalling, isTrue);
    expect(await repo.isInstalled(), isTrue);
    verify(
      () => files.install(embeddingGemma, onProgress: any(named: 'onProgress')),
    ).called(1);
  });

  group('close', () {
    test('releases the loaded model and the download client', () async {
      final repo = repository();
      await repo.embedDocument('a note');

      await repo.close();

      verify(embedder.dispose).called(1);
      verify(files.close).called(1);
    });

    test('with no model loaded closes only the download client', () async {
      await repository().close();

      verifyNever(embedder.dispose);
      verify(files.close).called(1);
    });

    test('ignores a model that failed to load', () async {
      load = (_) async => throw StateError('broken session');
      final repo = repository();
      final failed = repo.embedDocument('a note');

      await repo.close();

      await expectLater(failed, throwsStateError);
      verify(files.close).called(1);
    });
  });
}
