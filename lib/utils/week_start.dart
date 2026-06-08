/// Locale-aware first-day-of-week resolution for calendar grids.
///
/// Calendars in the app render a Monday-to-Sunday (or Sunday-to-Saturday)
/// grid. The starting weekday is a *regional* convention, not a language
/// one: most of the world starts the week on Monday, the US/Canada and a
/// number of other countries start on Sunday, and a few Middle-Eastern
/// countries start on Saturday.
///
/// The naive source — `MaterialLocalizations.firstDayOfWeekIndex` — is keyed
/// by the resolved *app UI language*, so an English UI always reports Sunday
/// even when the user lives in a Monday-first region. The same is true of
/// `intl`'s `DateSymbols.FIRSTDAYOFWEEK`: both flatten English to Sunday.
///
/// To match what the user actually expects we resolve the start of the week
/// from the *device region* (the country code of the platform locale),
/// independent of which language the app is shown in. The region → weekday
/// mapping below is taken verbatim from CLDR **v46** `weekData/firstDay`
/// (`001` defaults to Monday). v46 is the version bundled by `intl 0.20.2`,
/// this app's pinned `intl`, so the two stay consistent — e.g. intl's own
/// `pt_PT`/`mt` data also reports Sunday, and `en_AU` reports Monday. When
/// upgrading `intl`/CLDR, re-derive these sets from the new `weekData`.
///
/// All indices use `MaterialLocalizations.firstDayOfWeekIndex` conventions:
/// `0` = Sunday, `1` = Monday, … `6` = Saturday — so the result is a drop-in
/// replacement for that property in the existing calendar grid math.
library;

import 'package:flutter/material.dart';

const int _sunday = 0;
const int _monday = 1;
const int _saturday = 6;

/// ISO 3166-1 alpha-2 regions whose week starts on **Sunday**
/// (CLDR v46 `weekData/firstDay = sun`).
const Set<String> sundayFirstRegions = {
  'AG',
  'AS',
  'BD',
  'BR',
  'BS',
  'BT',
  'BW',
  'BZ',
  'CA',
  'CO',
  'DM',
  'DO',
  'ET',
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
  'PT',
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

/// ISO 3166-1 alpha-2 regions whose week starts on **Saturday**
/// (CLDR v46 `weekData/firstDay = sat`).
const Set<String> saturdayFirstRegions = {
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

/// Resolves the first day of the week for [regionCode] (an ISO 3166-1
/// alpha-2 country code, case-insensitive).
///
/// Returns a `MaterialLocalizations.firstDayOfWeekIndex`-style value
/// (`0` = Sunday … `6` = Saturday). When [regionCode] is null/empty or not a
/// recognised Sunday/Saturday region, [fallback] is returned — for an
/// unknown region that defaults to Monday via the caller, while a missing
/// region falls back to the UI-locale value the caller passes in.
int firstDayOfWeekIndexForRegion(String? regionCode, {required int fallback}) {
  if (regionCode == null || regionCode.isEmpty) {
    return fallback;
  }
  final region = regionCode.toUpperCase();
  if (sundayFirstRegions.contains(region)) {
    return _sunday;
  }
  if (saturdayFirstRegions.contains(region)) {
    return _saturday;
  }
  return _monday;
}

/// Resolves the first day of the week from the *device* region rather than
/// the app UI language, so an English UI on a Monday-first device still
/// starts the week on Monday.
///
/// Reads the country code from the platform locale and maps it via
/// [firstDayOfWeekIndexForRegion]. When the device exposes no region, falls
/// back to the resolved UI locale's
/// `MaterialLocalizations.firstDayOfWeekIndex`.
///
/// Note: the platform locale is read directly rather than through an
/// inherited dependency, so a calendar will not rebuild on its own if the OS
/// region changes mid-session — it picks up the new value on the next
/// rebuild. In practice an OS region change rebuilds `MaterialApp`, so the
/// calendars refresh anyway.
int deviceFirstDayOfWeekIndex(BuildContext context) {
  final deviceLocale = WidgetsBinding.instance.platformDispatcher.locale;
  return firstDayOfWeekIndexForRegion(
    deviceLocale.countryCode,
    fallback: MaterialLocalizations.of(context).firstDayOfWeekIndex,
  );
}

/// Number of leading empty cells before day 1 in a month grid that starts
/// the week on [firstDayOfWeekIndex] (`0` = Sunday … `6` = Saturday).
///
/// [firstOfMonth] is the first day of the month. The result is in
/// `[0, 6]`: it converts `DateTime.weekday` (1 = Mon … 7 = Sun) into the
/// Sunday-indexed column, then rotates so the grid's first column lands on
/// [firstDayOfWeekIndex].
int leadingDayOffset(DateTime firstOfMonth, int firstDayOfWeekIndex) =>
    (firstOfMonth.weekday % 7 - firstDayOfWeekIndex + 7) % 7;
