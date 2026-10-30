import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/cloud/cloud_voice_samples.dart';

void main() {
  const english = 'Hello! This is how I sound reading your summaries aloud.';

  test("a language the app ships speaks the app's own translation", () {
    expect(
      cloudVoiceSample('de'),
      'Hallo! So klinge ich, wenn ich dir deine Zusammenfassungen vorlese.',
    );
    expect(cloudVoiceSample('en'), english);
  });

  test('every other language of the Voxtral catalog has its own sentence', () {
    // The live catalog's languages without an app translation (2026-10-30).
    for (final language in [
      'ar',
      'ca',
      'hi',
      'hu',
      'ja',
      'ko',
      'no',
      'pl',
      'ru',
      'tr',
      'uk',
      'vi',
      'zh',
    ]) {
      final sample = cloudVoiceSample(language);
      expect(sample, isNot(english), reason: language);
      expect(sample.trim(), isNotEmpty, reason: language);
    }
  });

  test('a language with no sentence of its own falls back to English', () {
    expect(cloudVoiceSample('sw'), english);
    expect(cloudVoiceSample(''), english);
  });
}
