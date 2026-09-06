import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../../../mocks/mocks.dart';

void main() {
  test('provider closes its owned HTTP client on disposal', () async {
    final client = MockHttpClient();
    await http.runWithClient(() async {
      final container = ProviderContainer();
      try {
        final repository = container.read(sherpaModelRepositoryProvider);
        expect(await repository.isAvailable('unknown-model'), isFalse);
        verifyNever(client.close);
      } finally {
        container.dispose();
      }
      verify(client.close).called(1);
    }, () => client);
  });

  late Directory directory;
  final data = utf8.encode('verified model');
  final spec = SherpaModel(
    id: 'tiny',
    name: 'Whisper Tiny',
    revision: 'pinned-revision',
    files: [
      SherpaModelFile(
        'model.onnx',
        data.length,
        sha256.convert(data).toString(),
      ),
    ],
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('sherpa-model-test-');
  });
  tearDown(() async => directory.delete(recursive: true));

  SherpaModelRepository repository(http.Client client) {
    final repo = SherpaModelRepository(
      client: client,
      supportDirectory: () async => directory,
      models: [spec],
    );
    addTearDown(repo.close);
    return repo;
  }

  test(
    'publishes verified files, reports progress, and reuses installation',
    () async {
      var requests = 0;
      final repo = repository(
        MockClient((request) async {
          requests++;
          expect(request.url.path, contains('/resolve/pinned-revision/'));
          return http.Response.bytes(data, 200);
        }),
      );
      expect(await repo.isInstalled('tiny'), isFalse);
      final progress = <double>[];
      final path = await repo.install('tiny', onProgress: progress.add);
      expect(await File(p.join(path, 'model.onnx')).readAsBytes(), data);
      expect(await repo.isInstalled('tiny'), isTrue);
      expect(progress.last, 1);
      expect(progress, everyElement(inInclusiveRange(0, 1)));
      await repo.install('tiny');
      expect(requests, 1);
    },
  );

  for (final corrupt in [
    <int>[1],
    List.filled(data.length, 0),
    List.filled(data.length + 1, 0),
  ]) {
    test(
      'rejects invalid artifact of ${corrupt.length} bytes without publishing',
      () async {
        final repo = repository(
          MockClient((_) async => http.Response.bytes(corrupt, 200)),
        );
        await expectLater(repo.install('tiny'), throwsFormatException);
        expect(await repo.isInstalled('tiny'), isFalse);
        expect(
          await directory
              .list(recursive: true)
              .where((e) => e is File)
              .toList(),
          isEmpty,
        );
      },
    );
  }

  test('failed request can be retried', () async {
    var requests = 0;
    final repo = repository(
      MockClient(
        (_) async => ++requests == 1
            ? http.Response('Unavailable', 503)
            : http.Response.bytes(data, 200),
      ),
    );
    await expectLater(repo.install('tiny'), throwsA(isA<HttpException>()));
    expect(await repo.isInstalled('tiny'), isFalse);
    await repo.install('tiny');
    expect(await repo.isInstalled('tiny'), isTrue);
    expect(requests, 2);
  });

  test('same-size corruption is detected and repaired', () async {
    final repo = repository(
      MockClient((_) async => http.Response.bytes(data, 200)),
    );
    final path = await repo.install('tiny');
    await File(
      p.join(path, 'model.onnx'),
    ).writeAsBytes(List.filled(data.length, 0));
    expect(await repo.isInstalled('tiny'), isFalse);
    await repo.install('tiny');
    expect(await File(p.join(path, 'model.onnx')).readAsBytes(), data);
  });

  test('concurrent installs share one download', () async {
    final response = Completer<http.Response>();
    var requests = 0;
    final repo = repository(
      MockClient((_) {
        requests++;
        return response.future;
      }),
    );
    final first = repo.install('tiny');
    final second = repo.install('tiny');
    response.complete(http.Response.bytes(data, 200));
    expect(await first, await second);
    expect(requests, 1);
  });

  test(
    'availability follows installation and removal without downloading',
    () async {
      var requests = 0;
      final repo = repository(
        MockClient((_) async {
          requests++;
          return http.Response.bytes(data, 200);
        }),
      );
      expect(await repo.isAvailable('unknown'), isFalse);
      expect(await repo.isAvailable('tiny'), isFalse);
      expect(requests, 0);
      final path = await repo.install('tiny');
      expect(await repo.isAvailable('tiny'), isTrue);
      await repo.remove('tiny');
      expect(Directory(path).existsSync(), isFalse);
      expect(await repo.isAvailable('tiny'), isFalse);
      await repo.remove('tiny');
      expect(requests, 1);
    },
  );

  test('removal cannot race an active download', () async {
    final response = Completer<http.Response>();
    final repo = repository(MockClient((_) => response.future));
    final installation = repo.install('tiny');
    await expectLater(repo.remove('tiny'), throwsStateError);
    response.complete(http.Response.bytes(data, 200));
    await installation;
    expect(await repo.isInstalled('tiny'), isTrue);
  });

  test('interrupted stream cleans up its partial file', () async {
    final repo = repository(
      MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream<List<int>>.error(const HttpException('Interrupted')),
          200,
        ),
      ),
    );
    await expectLater(repo.install('tiny'), throwsA(isA<HttpException>()));
    expect(
      await directory.list(recursive: true).where((e) => e is File).toList(),
      isEmpty,
    );
  });

  test(
    'unknown model IDs cannot become filesystem paths or download URLs',
    () async {
      final repo = repository(
        MockClient((_) async => throw StateError('Must not download')),
      );
      await expectLater(repo.install('../escape'), throwsArgumentError);
      await expectLater(repo.isInstalled('../escape'), throwsArgumentError);
      expect(await directory.list().toList(), isEmpty);
    },
  );
}
