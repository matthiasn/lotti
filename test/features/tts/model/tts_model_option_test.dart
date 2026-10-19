import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/model/tts_model_option.dart';

void main() {
  group('kTtsModels catalog', () {
    test('ships Supertonic 3 pointing at the real Hugging Face repo', () {
      final model = kTtsModels.firstWhere((m) => m.id == 'supertonic-3');
      expect(model.displayName, 'Supertonic 3');
      expect(model.huggingFaceRepoId, 'Supertone/supertonic-3');
      expect(model.huggingFaceRepoId, kSupertonic3RepoId);
    });

    test('marks exactly one model as the recommended default', () {
      final recommended = kTtsModels.where((m) => m.recommended).toList();
      expect(recommended, hasLength(1));
      expect(recommended.single.id, kDefaultTtsModelId);
    });

    test('pins Supertonic 3 to a commit, with the size of every file', () {
      final model = ttsModelByIdOrDefault('supertonic-3');

      expect(model.revision, matches(RegExp(r'^[0-9a-f]{40}$')));
      expect(model.files.map((f) => f.name), [
        'duration_predictor.onnx',
        'text_encoder.onnx',
        'vector_estimator.onnx',
        'vocoder.onnx',
        'tts.json',
        'unicode_indexer.json',
      ]);
      for (final file in model.files) {
        expect(file.bytes, greaterThan(0), reason: file.name);
      }
      // Measured at the pinned commit; the prompt shows "398.4 MB".
      expect(model.totalBytes, 398361202);
    });

    test('has unique ids', () {
      final ids = kTtsModels.map((m) => m.id).toSet();
      expect(ids.length, kTtsModels.length);
    });
  });

  group('TtsModelOption equality', () {
    test('compares by all fields', () {
      const a = TtsModelOption(
        id: 'x',
        displayName: 'X',
        huggingFaceRepoId: 'owner/x',
        revision: 'r1',
        files: [TtsModelFile('a.onnx', 1)],
      );
      const b = TtsModelOption(
        id: 'x',
        displayName: 'X',
        huggingFaceRepoId: 'owner/x',
        revision: 'r1',
        files: [TtsModelFile('a.onnx', 1)],
      );
      const c = TtsModelOption(
        id: 'x',
        displayName: 'X',
        huggingFaceRepoId: 'owner/x',
        revision: 'r1',
        files: [TtsModelFile('a.onnx', 1)],
        recommended: true,
      );
      const otherRevision = TtsModelOption(
        id: 'x',
        displayName: 'X',
        huggingFaceRepoId: 'owner/x',
        revision: 'r2',
        files: [TtsModelFile('a.onnx', 1)],
      );
      const otherSize = TtsModelOption(
        id: 'x',
        displayName: 'X',
        huggingFaceRepoId: 'owner/x',
        revision: 'r1',
        files: [TtsModelFile('a.onnx', 2)],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a, isNot(otherRevision));
      expect(a, isNot(otherSize));
    });
  });

  test('describes a model by id and Hugging Face repository', () {
    const option = TtsModelOption(
      id: 'x',
      displayName: 'X',
      huggingFaceRepoId: 'owner/x',
      revision: 'r1',
      files: [],
    );
    expect(option.toString(), 'TtsModelOption(x, owner/x)');
  });

  group('ttsModelByIdOrDefault', () {
    test('resolves a known id', () {
      expect(ttsModelByIdOrDefault('supertonic-3').id, 'supertonic-3');
    });

    test('falls back to the default model for unknown/null ids', () {
      expect(ttsModelByIdOrDefault('nope').id, kDefaultTtsModelId);
      expect(ttsModelByIdOrDefault(null).id, kDefaultTtsModelId);
    });
  });
}
