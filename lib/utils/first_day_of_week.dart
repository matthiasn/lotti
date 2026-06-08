/// Resolves which weekday a calendar week starts on, by region, plus the
/// month-grid layout offset that follows from it.
///
/// The week-start convention is a *regional* property, not a language one:
/// a German user running the app in English still expects weeks to begin on
/// Monday. So the calendar derives its first day from the device region
/// (see `DeviceRegion`), using the CLDR `weekData/firstDay` table.
///
/// First-day indices use Flutter's weekday convention, matching
/// `MaterialLocalizations.firstDayOfWeekIndex`:
/// `0 = Sunday`, `1 = Monday`, … `6 = Saturday`.
library;

/// Territories whose week starts on **Sunday** (CLDR `firstDay = sun`).
const _sundayFirstCountries = <String>{
  'AG',
  'AS',
  'AU',
  'BD',
  'BR',
  'BS',
  'BT',
  'BW',
  'BZ',
  'CA',
  'CN',
  'CO',
  'DM',
  'DO',
  'ET',
  'GT',
  'GU',
  'HK',
  'HN',
  'ID',
  'IL',
  'IN',
  'JM',
  'JP',
  'KE',
  'KH',
  'KR',
  'LA',
  'MH',
  'MM',
  'MO',
  'MT',
  'MX',
  'MZ',
  'NI',
  'NP',
  'PA',
  'PE',
  'PH',
  'PK',
  'PR',
  'PY',
  'SA',
  'SG',
  'SV',
  'TH',
  'TT',
  'TW',
  'UM',
  'US',
  'VE',
  'VI',
  'WS',
  'YE',
  'ZA',
  'ZW',
};

/// Territories whose week starts on **Saturday** (CLDR `firstDay = sat`).
const _saturdayFirstCountries = <String>{
  'AE',
  'AF',
  'BH',
  'DJ',
  'DZ',
  'EG',
  'IQ',
  'IR',
  'JO',
  'KW',
  'LY',
  'OM',
  'QA',
  'SD',
  'SY',
};

/// First weekday for [countryCode] (an ISO-3166 region like `DE`, `US`).
///
/// Defaults to **Monday** — the CLDR global default — for unknown or missing
/// regions. Case-insensitive.
int firstDayOfWeekIndexForCountry(String? countryCode) {
  if (countryCode == null || countryCode.isEmpty) return DateTime.monday % 7;
  final code = countryCode.toUpperCase();
  if (_sundayFirstCountries.contains(code)) return DateTime.sunday % 7;
  if (_saturdayFirstCountries.contains(code)) return DateTime.saturday % 7;
  return DateTime.monday % 7;
}

/// Extracts the ISO-3166 region from an OS locale identifier such as
/// `en_DE`, `en_DE.UTF-8`, `de-DE`, or `zh_Hant_HK`. Returns null when the
/// identifier carries no region.
///
/// Used as the region source on platforms that expose it through the locale
/// name (Linux/Windows/mobile); macOS needs a native lookup instead.
String? regionFromLocaleName(String localeName) {
  // Drop any charset/modifier suffix ("en_DE.UTF-8" -> "en_DE").
  final base = localeName.split('.').first.split('@').first;
  // The first subtag is the language; the region is a later two-letter
  // subtag. Matching by position (rather than by case) accepts a lowercase
  // region ("en_us") without mistaking a two-letter language ("en") for one.
  for (final part in base.split(RegExp('[_-]')).skip(1)) {
    if (RegExp(r'^[A-Za-z]{2}$').hasMatch(part)) return part.toUpperCase();
  }
  return null;
}

/// Number of blank leading cells before day 1 of [month]/[year] in a month
/// grid whose columns start on [firstDayOfWeekIndex].
///
/// Mirrors `DateUtils.firstDayOffset`, but takes an explicit first-day index
/// so the grid can start on a chosen weekday rather than the app locale's.
int leadingBlankDayCount({
  required int year,
  required int month,
  required int firstDayOfWeekIndex,
}) {
  // Catches passing `DateTime.sunday` (7) instead of its index (0): 7 would
  // silently offset the grid as if the week started on Saturday.
  assert(
    firstDayOfWeekIndex >= 0 && firstDayOfWeekIndex <= 6,
    'firstDayOfWeekIndex must be 0 (Sunday) … 6 (Saturday), got '
    '$firstDayOfWeekIndex',
  );
  // UTC so a local DST/timezone anomaly can never shift the 1st's weekday.
  // Relies on Dart's Euclidean %: for a positive divisor the result is
  // always non-negative (e.g. -1 % 7 == 6, -2 % 7 == 5), unlike C/JS — so
  // a Sunday index (0) and negative dividends below resolve correctly.
  // `weekday` is 1 (Mon) … 7 (Sun); shift to 0 (Mon) … 6 (Sun).
  final weekdayFromMonday = DateTime.utc(year, month).weekday - 1;
  // Convert the Sunday-based first-day index to the same Monday-based frame.
  final firstDayFromMonday = (firstDayOfWeekIndex - 1) % 7;
  return (weekdayFromMonday - firstDayFromMonday) % 7;
}
