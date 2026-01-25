import 'package:country_flags/country_flags.dart';
import 'package:flutter/widgets.dart';

/// Utility for rendering language flags with consistent overrides.
Widget buildLanguageFlag({
  required String languageCode,
  required double height,
  required double width,
  Key? key,
}) {
  const nigerianLanguageCodes = {'ig', 'pcm', 'yo'};
  const languageCountryOverrides = {
    'zh': 'cn',
    'tw': 'gh',
  };

  final imageTheme = ImageTheme(
    height: height,
    width: width,
    shape: const RoundedRectangle(4),
  );
  final flagKey = key ?? ValueKey('flag-$languageCode');

  if (nigerianLanguageCodes.contains(languageCode)) {
    return CountryFlag.fromCountryCode('ng', theme: imageTheme, key: flagKey);
  }

  final overrideCountryCode = languageCountryOverrides[languageCode];
  if (overrideCountryCode != null) {
    return CountryFlag.fromCountryCode(
      overrideCountryCode,
      theme: imageTheme,
      key: flagKey,
    );
  }

  return CountryFlag.fromLanguageCode(
    languageCode,
    theme: imageTheme,
    key: flagKey,
  );
}
