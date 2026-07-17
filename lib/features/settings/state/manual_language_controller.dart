import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:url_launcher/url_launcher.dart';

/// SettingsDb key for the optional external-manual language override.
const manualLanguageSettingsKey = 'MANUAL_LANGUAGE';

/// Languages currently published by the Lotti Manual.
///
/// English is the manual's default locale and therefore has no locale segment
/// in its URL. The other values map directly to the Docusaurus locale paths.
enum ManualLanguage {
  english('en'),
  german('de'),
  french('fr'),
  czech('cs'),
  romanian('ro'),
  portuguese('pt');

  const ManualLanguage(this.languageCode);

  final String languageCode;

  static ManualLanguage? fromStoredValue(String? value) {
    for (final language in values) {
      if (language.languageCode == value) return language;
    }
    return null;
  }
}

/// The published development manual's root URL.
const lottiManualBaseUrl =
    'https://matthiasn.github.io/lotti/manual/development/';

/// Resolves [systemLocale] to a published manual language, falling back to
/// English whenever the manual does not offer that language yet.
ManualLanguage manualLanguageForSystemLocale(Locale systemLocale) {
  for (final language in ManualLanguage.values) {
    if (language.languageCode == systemLocale.languageCode.toLowerCase()) {
      return language;
    }
  }
  return ManualLanguage.english;
}

/// Builds the external manual URL for an optional user [override].
///
/// A `null` override follows [systemLocale]. English intentionally remains on
/// the default route; translated manuals add their locale segment.
Uri manualUriFor({
  required Locale systemLocale,
  ManualLanguage? override,
}) {
  final language = override ?? manualLanguageForSystemLocale(systemLocale);
  final localeSegment = language == ManualLanguage.english
      ? ''
      : '${language.languageCode}/';
  return Uri.parse('$lottiManualBaseUrl$localeSegment');
}

/// Opens the locale-aware Lotti Manual in the system browser.
Future<void> openManualInBrowser({
  required Locale systemLocale,
  ManualLanguage? override,
}) async {
  await launchUrl(
    manualUriFor(systemLocale: systemLocale, override: override),
    mode: LaunchMode.externalApplication,
  );
}

/// Persists the optional language override for the external Lotti Manual.
///
/// `null` represents the default *Follow system* choice. The controller
/// hydrates lazily, while [_userChanged] prevents a late database read from
/// replacing a selection made immediately after the settings page opens.
class ManualLanguageController extends Notifier<ManualLanguage?> {
  bool _userChanged = false;

  @override
  ManualLanguage? build() {
    unawaited(_load());
    return null;
  }

  Future<void> _load() async {
    if (!getIt.isRegistered<SettingsDb>()) return;
    final stored = await getIt<SettingsDb>().itemByKey(
      manualLanguageSettingsKey,
    );
    if (!ref.mounted || _userChanged) return;
    state = ManualLanguage.fromStoredValue(stored);
  }

  /// Selects a specific manual language, or clears the override with `null`.
  Future<void> setOverride(ManualLanguage? override) async {
    _userChanged = true;
    state = override;

    if (!getIt.isRegistered<SettingsDb>()) return;
    final settingsDb = getIt<SettingsDb>();
    if (override == null) {
      await settingsDb.removeSettingsItem(manualLanguageSettingsKey);
      return;
    }
    await settingsDb.saveSettingsItem(
      manualLanguageSettingsKey,
      override.languageCode,
    );
  }
}

final manualLanguageControllerProvider =
    NotifierProvider<ManualLanguageController, ManualLanguage?>(
      ManualLanguageController.new,
      name: 'manualLanguageControllerProvider',
    );
