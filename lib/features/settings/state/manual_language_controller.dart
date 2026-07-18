import 'dart:async' show FutureOr;
import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:url_launcher/url_launcher.dart';

/// SettingsDb key for the optional app and external-manual language override.
///
/// The stored key intentionally retains its original name so existing user
/// preferences keep working after the setting began controlling Lotti's UI.
const manualLanguageSettingsKey = 'MANUAL_LANGUAGE';

/// Languages currently published by the Lotti Manual and supported by Lotti.
///
/// English is the manual's default locale and therefore has no locale segment
/// in its URL. The other values map directly to the Docusaurus locale paths.
enum ManualLanguage {
  english('en'),
  german('de'),
  french('fr'),
  italian('it'),
  spanish('es'),
  czech('cs'),
  dutch('nl'),
  romanian('ro'),
  portuguese('pt');

  const ManualLanguage(this.languageCode);

  final String languageCode;

  /// The locale used by Lotti's localized widget tree.
  Locale get locale => Locale(languageCode);

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
Uri manualUriFor({required Locale systemLocale, ManualLanguage? override}) {
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

/// Persists the optional language override for Lotti and the external Manual.
///
/// `AsyncLoading` represents initial hydration; `AsyncData(null)` is the
/// default *Follow system* choice. [_userChanged] prevents a late database
/// read from replacing a selection made immediately after settings opens.
class ManualLanguageController extends AsyncNotifier<ManualLanguage?> {
  bool _userChanged = false;

  @override
  FutureOr<ManualLanguage?> build() async {
    if (!getIt.isRegistered<SettingsDb>()) return null;

    try {
      final stored = await getIt<SettingsDb>().itemByKey(
        manualLanguageSettingsKey,
      );
      return _userChanged
          ? state.value
          : ManualLanguage.fromStoredValue(stored);
    } on Object {
      // A settings read must not keep the app on its loading shell forever.
      return state.value;
    }
  }

  /// Selects a specific Lotti and Manual language, or clears the override.
  Future<void> setOverride(ManualLanguage? override) async {
    _userChanged = true;
    state = AsyncData(override);

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
    AsyncNotifierProvider<ManualLanguageController, ManualLanguage?>(
      ManualLanguageController.new,
      name: 'manualLanguageControllerProvider',
    );
