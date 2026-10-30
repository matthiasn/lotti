import 'package:lotti/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The sentence a cloud voice previews itself with, in [language]: the
/// app's own translation where it ships one, else one of the sentences below
/// for the other languages Voxtral speaks, else English — so every voice in
/// the catalog can be heard before it is picked.
///
/// The sentence is spoken, never shown, so the languages the app does not
/// ship are kept here rather than as ARB catalogs of one string.
String cloudVoiceSample(String language) {
  final shipped = AppLocalizations.supportedLocales.any(
    (locale) => locale.languageCode == language,
  );
  if (shipped) {
    return lookupAppLocalizations(
      Locale(language),
    ).speechSettingsCloudVoiceSample;
  }
  return _unshippedSamples[language] ??
      lookupAppLocalizations(const Locale('en')).speechSettingsCloudVoiceSample;
}

/// "Hello! This is how I sound reading your summaries aloud." in the
/// languages of Voxtral's catalog that have no app translation.
const Map<String, String> _unshippedSamples = <String, String>{
  'ar': 'مرحبًا! هكذا يبدو صوتي عندما أقرأ ملخصاتك بصوت عالٍ.',
  'ca': 'Hola! Així és com sono quan et llegeixo els resums en veu alta.',
  'hi': 'नमस्ते! आपके सारांश ज़ोर से पढ़ते समय मेरी आवाज़ ऐसी सुनाई देती है।',
  'hu': 'Szia! Így hangzom, amikor felolvasom az összefoglalóidat.',
  'ja': 'こんにちは！要約を読み上げるとき、私はこんな声です。',
  'ko': '안녕하세요! 요약을 소리 내어 읽을 때 제 목소리는 이렇게 들려요.',
  'no': 'Hei! Slik høres jeg ut når jeg leser opp sammendragene dine.',
  'pl': 'Cześć! Tak brzmię, kiedy czytam na głos twoje podsumowania.',
  'ru': 'Привет! Вот так звучит мой голос, когда я читаю вслух твои сводки.',
  'tr': 'Merhaba! Özetlerini sesli okurken sesim böyle duyuluyor.',
  'uk': 'Привіт! Ось так звучить мій голос, коли я читаю вголос твої підсумки.',
  'vi': 'Xin chào! Đây là giọng của tôi khi đọc to các bản tóm tắt của bạn.',
  'zh': '你好！这就是我为你朗读摘要时的声音。',
};
