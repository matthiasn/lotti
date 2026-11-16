import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/model/tts_voice.dart';

void main() {
  group('kSupertonicVoices catalog', () {
    test('ships exactly the ten upstream voices, female first', () {
      expect(
        kSupertonicVoices.map((v) => v.id).toList(),
        ['F1', 'F2', 'F3', 'F4', 'F5', 'M1', 'M2', 'M3', 'M4', 'M5'],
      );
    });

    test('splits five female and five male', () {
      final female = kSupertonicVoices.where(
        (v) => v.gender == TtsVoiceGender.female,
      );
      final male = kSupertonicVoices.where(
        (v) => v.gender == TtsVoiceGender.male,
      );
      expect(female.map((v) => v.id), ['F1', 'F2', 'F3', 'F4', 'F5']);
      expect(male.map((v) => v.id), ['M1', 'M2', 'M3', 'M4', 'M5']);
    });

    test('has unique ids', () {
      final ids = kSupertonicVoices.map((v) => v.id).toSet();
      expect(ids.length, kSupertonicVoices.length);
    });
  });

  group('TtsVoice', () {
    test('uses value equality on id and gender', () {
      const a = TtsVoice(id: 'F1', gender: TtsVoiceGender.female);
      const b = TtsVoice(id: 'F1', gender: TtsVoiceGender.female);
      const c = TtsVoice(id: 'F1', gender: TtsVoiceGender.male);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('default voice', () {
    test('is present in the catalog and is female', () {
      final defaultVoice = kSupertonicVoices.firstWhere(
        (v) => v.id == kDefaultTtsVoiceId,
      );
      expect(defaultVoice.gender, TtsVoiceGender.female);
    });
  });

  test('describes a voice by id and gender', () {
    expect(
      ttsVoiceByIdOrDefault('M4').toString(),
      'TtsVoice(M4, ${TtsVoiceGender.male})',
    );
  });

  group('ttsVoiceOfGender', () {
    test("keeps the voice's number across genders, both ways", () {
      for (final number in ['1', '2', '3', '4', '5']) {
        expect(
          ttsVoiceOfGender('F$number', TtsVoiceGender.male).id,
          'M$number',
        );
        expect(
          ttsVoiceOfGender('M$number', TtsVoiceGender.female).id,
          'F$number',
        );
      }
    });

    test('every voice has its counterpart: the catalog pairs each number', () {
      for (final voice in kSupertonicVoices) {
        for (final gender in TtsVoiceGender.values) {
          final matched = ttsVoiceOfGender(voice.id, gender);
          expect(matched.gender, gender, reason: voice.id);
          expect(matched.id.substring(1), voice.id.substring(1));
        }
      }
    });

    test('a voice of the gender already is itself', () {
      expect(ttsVoiceOfGender('F4', TtsVoiceGender.female).id, 'F4');
      expect(ttsVoiceOfGender('M2', TtsVoiceGender.male).id, 'M2');
    });

    test('an unknown or missing voice counts as the default one', () {
      expect(ttsVoiceOfGender('nope', TtsVoiceGender.male).id, 'M1');
      expect(ttsVoiceOfGender(null, TtsVoiceGender.female).id, 'F1');
    });
  });

  group('ttsVoiceByIdOrDefault', () {
    test('resolves a known id to its voice', () {
      expect(ttsVoiceByIdOrDefault('M4').id, 'M4');
    });

    test('falls back to the default voice for an unknown id', () {
      expect(ttsVoiceByIdOrDefault('does-not-exist').id, kDefaultTtsVoiceId);
    });

    test('falls back to the default voice for a null id', () {
      expect(ttsVoiceByIdOrDefault(null).id, kDefaultTtsVoiceId);
    });
  });
}
