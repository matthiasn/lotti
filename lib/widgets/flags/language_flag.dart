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
  const flagBorderRadius = 4.0;
  const languageCountryOverrides = {
    'zh': 'cn',
    'tw': 'gh',
  };

  if (nigerianLanguageCodes.contains(languageCode)) {
    return CountryFlag.fromCountryCode(
      'ng',
      theme: ImageTheme(
        height: height,
        width: width,
        shape: const RoundedRectangle(flagBorderRadius),
      ),
      key: key ?? ValueKey('flag-$languageCode'),
    );
  }

  final overrideCountryCode = languageCountryOverrides[languageCode];
  if (overrideCountryCode != null) {
    return CountryFlag.fromCountryCode(
      overrideCountryCode,
      theme: ImageTheme(
        height: height,
        width: width,
        shape: const RoundedRectangle(flagBorderRadius),
      ),
      key: key ?? ValueKey('flag-$languageCode'),
    );
  }

  return CountryFlag.fromLanguageCode(
    languageCode,
    theme: ImageTheme(
      height: height,
      width: width,
      shape: const RoundedRectangle(flagBorderRadius),
    ),
    key: key ?? ValueKey('flag-$languageCode'),
  );
}
