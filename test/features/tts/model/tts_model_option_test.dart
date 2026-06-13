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
      );
      const b = TtsModelOption(
        id: 'x',
        displayName: 'X',
        huggingFaceRepoId: 'owner/x',
      );
      const c = TtsModelOption(
        id: 'x',
        displayName: 'X',
        huggingFaceRepoId: 'owner/x',
        recommended: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
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
