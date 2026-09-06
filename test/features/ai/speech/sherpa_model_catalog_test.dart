import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/speech/sherpa_model_catalog.dart';
import 'package:lotti/features/ai/util/known_models.dart';

void main() {
  test(
    'each native artifact role is covered by the pinned download manifest',
    () {
      expect(
        sherpaModels.map((model) => model.id).toSet().length,
        sherpaModels.length,
      );
      for (final model in sherpaModels) {
        expect(model.revision, matches(RegExp(r'^[a-f0-9]{40}$')));
        final files = model.files.map((file) => file.name).toSet();
        expect(files.length, model.files.length);
        for (final role in model.recognizerFiles.entries) {
          if (role.key == 'tokenizer') {
            final required =
                model.architecture == SherpaModelArchitecture.qwen3Asr
                ? ['vocab.json', 'merges.txt', 'tokenizer_config.json']
                : ['vocab.json', 'merges.txt', 'tokenizer.json'];
            expect(
              files,
              containsAll(required.map((name) => '${role.value}/$name')),
            );
          } else {
            expect(
              files,
              contains(role.value),
              reason: '${model.id}: ${role.key}',
            );
          }
        }
        if (!model.recognizerFiles.containsKey('tokenizer')) {
          expect(files, contains(model.tokensFile));
        }
        for (final file in model.files) {
          expect(file.bytes, greaterThan(0));
          expect(file.sha256, matches(RegExp(r'^[a-f0-9]{64}$')));
          expect(file.name.split('/'), isNot(contains('..')));
          expect(file.name.startsWith('/'), isFalse);
          expect(model.uri(file).host, 'huggingface.co');
          expect(model.uri(file).path, contains('/resolve/${model.revision}/'));
        }
      }
    },
  );

  test('configurations and downloads use the same catalog identities', () {
    expect(
      sherpaSpeechModels.map((model) => model.providerModelId),
      sherpaModels.map((model) => model.id),
    );
    for (final (index, known) in sherpaSpeechModels.indexed) {
      expect(known.name, sherpaModels[index].name);
      expect(known.publisher, sherpaModels[index].publisher);
      expect(known.inputModalities, [Modality.audio]);
      expect(known.outputModalities, [Modality.text]);
    }
  });
}
