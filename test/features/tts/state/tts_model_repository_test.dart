import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/tts/state/tts_model_repository.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tts_repo_test');
  });
  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<Directory> supportDir() async => tempDir;

  SupertonicModelRepository repo(http.Client client) =>
      SupertonicModelRepository(client: client, supportDirectory: supportDir);

  void writeAllFiles(String dir) {
    Directory(dir).createSync(recursive: true);
    for (final file in kSupertonicModelFiles) {
      File('$dir/$file').writeAsStringSync('x');
    }
  }

  test('isInstalled is false until every file exists, then true', () async {
    final r = repo(
      MockClient.streaming(
        (_, _) async => http.StreamedResponse(const Stream.empty(), 200),
      ),
    );
    expect(await r.isInstalled('supertonic-3'), isFalse);

    writeAllFiles(await r.modelDirectory('supertonic-3'));
    expect(await r.isInstalled('supertonic-3'), isTrue);
  });

  test(
    'ensureInstalled downloads each missing file and reaches 100%',
    () async {
      final requested = <String>[];
      final client = MockClient.streaming((request, _) async {
        requested.add(request.url.path);
        final bytes = utf8.encode('data:${request.url.pathSegments.last}');
        return http.StreamedResponse(
          Stream.value(bytes),
          200,
          contentLength: bytes.length,
        );
      });
      final r = repo(client);

      final progress = <double>[];
      final dir = await r.ensureInstalled(
        'supertonic-3',
        onProgress: progress.add,
      );

      expect(
        requested.where((p) => p.contains('/resolve/main/onnx/')).length,
        kSupertonicModelFiles.length,
      );
      for (final file in kSupertonicModelFiles) {
        expect(File('$dir/$file').existsSync(), isTrue, reason: file);
      }
      expect(progress.last, 1.0);
      expect(await r.isInstalled('supertonic-3'), isTrue);
    },
  );

  test('ensureInstalled skips the network when already installed', () async {
    var calls = 0;
    final client = MockClient.streaming((_, _) async {
      calls++;
      return http.StreamedResponse(const Stream.empty(), 200);
    });
    final r = repo(client);
    writeAllFiles(await r.modelDirectory('supertonic-3'));

    final progress = <double>[];
    await r.ensureInstalled('supertonic-3', onProgress: progress.add);

    expect(calls, 0);
    expect(progress, [1.0]);
  });

  test('ensureInstalled throws on a non-200 response', () async {
    final client = MockClient.streaming(
      (_, _) async => http.StreamedResponse(const Stream.empty(), 404),
    );
    final r = repo(client);

    expect(
      () => r.ensureInstalled('supertonic-3'),
      throwsA(isA<HttpException>()),
    );
  });
}
