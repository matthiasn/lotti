import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';
import 'package:lotti/features/ai/speech/sherpa_transcription_repository.dart';
import 'package:lotti/features/ai/speech/sherpa_worker.dart';

void main() {
  late Directory directory;
  late SherpaModelRepository models;
  var downloads = 0;
  final artifact = utf8.encode('model');
  final wav = Uint8List.fromList(utf8.encode('RIFF0000WAVEdata'));

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'sherpa-transcribe-test-',
    );
    downloads = 0;
    models = SherpaModelRepository(
      supportDirectory: () async => directory,
      client: MockClient((_) async {
        downloads++;
        return http.Response.bytes(artifact, 200);
      }),
      models: [
        SherpaModel(
          id: 'tiny',
          name: 'Tiny',
          revision: 'test',
          files: [
            SherpaModelFile(
              'model',
              artifact.length,
              sha256.convert(artifact).toString(),
            ),
          ],
        ),
      ],
    );
  });
  tearDown(() async {
    models.close();
    await directory.delete(recursive: true);
  });

  SherpaTranscriptionRepository repository(
    Stream<String> Function(SherpaWorkerRequest) decode, {
    Future<Uint8List> Function(Uint8List)? convert,
  }) => SherpaTranscriptionRepository(
    models: models,
    decode: decode,
    convert: convert ?? (_) async => throw StateError('Unexpected conversion'),
    temporaryDirectory: directory,
  );

  test(
    'provider refuses a missing local model without network access',
    () async {
      final container = ProviderContainer(
        overrides: [sherpaModelRepositoryProvider.overrideWithValue(models)],
      );
      addTearDown(container.dispose);
      await expectLater(
        container
            .read(sherpaTranscriptionRepositoryProvider)
            .transcribeAudio(model: 'tiny', audioBase64: base64Encode(wav))
            .toList(),
        throwsA(isA<TranscriptionException>()),
      );
      expect(downloads, 0);
    },
  );

  test(
    'missing model fails without downloading or invoking the worker',
    () async {
      final repo = repository((_) => throw StateError('Unexpected worker'));
      await expectLater(
        repo
            .transcribeAudio(model: 'tiny', audioBase64: base64Encode(wav))
            .toList(),
        throwsA(isA<TranscriptionException>()),
      );
      expect(downloads, 0);
    },
  );

  test(
    'WAV skips conversion, emits ordered text without token usage, and cleans up',
    () async {
      await models.install('tiny');
      late String scratch;
      final repo = repository((request) async* {
        scratch = request.wavPath;
        expect(await File(scratch).readAsBytes(), wav);
        expect(request.modelId, 'tiny');
        yield ' First ';
        yield '';
        yield 'second';
      });
      final responses = await repo
          .transcribeAudio(model: 'tiny', audioBase64: base64Encode(wav))
          .toList();
      expect(
        responses.map((r) => r.choices!.single.delta!.content).join(),
        'First second',
      );
      expect(responses.every((r) => r.usage == null), isTrue);
      expect(File(scratch).existsSync(), isFalse);
      expect(downloads, 1);
    },
  );

  test('M4A uses the existing converter without changing the source', () async {
    await models.install('tiny');
    final source = Uint8List.fromList([1, 2, 3]);
    var conversions = 0;
    final repo = repository(
      (request) async* {
        expect(await File(request.wavPath).readAsBytes(), wav);
        yield 'transcribed';
      },
      convert: (bytes) async {
        conversions++;
        expect(bytes, source);
        return wav;
      },
    );
    final responses = await repo
        .transcribeAudio(model: 'tiny', audioBase64: base64Encode(source))
        .toList();
    expect(responses.single.choices!.single.delta!.content, 'transcribed');
    expect(conversions, 1);
    expect(source, [1, 2, 3]);
  });

  for (final fail in [false, true]) {
    test(
      'empty or failed decoding cleans up scratch files (failure=$fail)',
      () async {
        await models.install('tiny');
        late String scratch;
        final repo = repository((request) async* {
          scratch = request.wavPath;
          if (fail) throw StateError('decoder failed');
          yield ' ';
        });
        await expectLater(
          repo
              .transcribeAudio(model: 'tiny', audioBase64: base64Encode(wav))
              .toList(),
          throwsA(fail ? isA<StateError>() : isA<TranscriptionException>()),
        );
        expect(File(scratch).existsSync(), isFalse);
      },
    );
  }

  test('cancellation releases worker and scratch recording', () async {
    await models.install('tiny');
    late String scratch;
    var cleaned = false;
    final repo = repository((request) async* {
      scratch = request.wavPath;
      try {
        yield 'first';
        yield 'second';
      } finally {
        cleaned = true;
      }
    });
    final result = await repo
        .transcribeAudio(model: 'tiny', audioBase64: base64Encode(wav))
        .take(1)
        .toList();
    expect(result.single.choices!.single.delta!.content, 'first');
    expect(cleaned, isTrue);
    expect(File(scratch).existsSync(), isFalse);
  });

  test('empty audio fails before decoding', () async {
    await models.install('tiny');
    final repo = repository((_) => throw StateError('Unexpected worker'));
    await expectLater(
      repo.transcribeAudio(model: 'tiny', audioBase64: '').toList(),
      throwsFormatException,
    );
  });
}
