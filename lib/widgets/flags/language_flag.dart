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
  };

  if (nigerianLanguageCodes.contains(languageCode)) {
    return CountryFlag.fromCountryCode(
      'ng',
      height: height,
      width: width,
      key: key ?? ValueKey('flag-$languageCode'),
    );
  }

  final overrideCountryCode = languageCountryOverrides[languageCode];
  if (overrideCountryCode != null) {
    return CountryFlag.fromCountryCode(
      overrideCountryCode,
      height: height,
      width: width,
      key: key ?? ValueKey('flag-$languageCode'),
    );
  }

  return CountryFlag.fromLanguageCode(
    languageCode,
    height: height,
    width: width,
    key: key ?? ValueKey('flag-$languageCode'),
  );
}
