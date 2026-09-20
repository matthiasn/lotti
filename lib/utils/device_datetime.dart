/// Dates and times in the **device's** conventions rather than the app's
/// language.
///
/// Language and region are separate settings on every platform Lotti runs on:
/// a phone can speak English and still write `20.9.2026, 19:08`. Formatting a
/// timestamp with `Localizations.localeOf(context)` ties the two together and
/// hands that phone `Sep 20, 2026 7:08 PM`, which is neither what it asked for
/// nor what any other app on it shows.
library;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// The locale to format dates and times with: the platform's, resolved the
/// way intl resolves it.
///
/// Through [Intl.verifiedLocale] rather than a bare
/// [DateFormat.localeExists]: intl files symbols under the closest name it
/// has, so `de_DE` resolves to `de` and an existence check on `de_DE` answers
/// **false** — quietly handing a German phone English dates, which is the
/// whole bug. Falls back to the app's locale when the platform's has no data
/// at all.
String deviceFormatLocale(BuildContext context) {
  final appLocale = Localizations.localeOf(context).toString();
  final device = WidgetsBinding.instance.platformDispatcher.locale.toString();
  // Non-null by construction: `verifiedLocale` returns null only when
  // `onFailure` does, and this one always answers with [appLocale]. A `??`
  // after it would be a branch nothing can take.
  return Intl.verifiedLocale(
    device,
    DateFormat.localeExists,
    onFailure: (_) => appLocale,
  )!;
}

/// A wall-clock reading on the device's own clock: `19:08` where the phone is
/// set to 24 hours, `7:08 PM` where it is not.
///
/// Through [TimeOfDay.format] rather than `DateFormat.jm`, because only the
/// former consults the device setting on top of the locale's default.
/// `DateFormat.jm('en_US')` is hard-wired to 12-hour, so 19:08 reads back as
/// "7:08 PM" for everyone running an English app on a 24-hour device.
///
/// A locale with no AM/PM form (German, Czech, …) stays 24-hour whatever the
/// device flag says — the locale wins, which is what [TimeOfDay.format]
/// already encodes.
String deviceClockLabel(BuildContext context, DateTime date) =>
    TimeOfDay.fromDateTime(date.toLocal()).format(context);

/// The date alone, numerically, in the device's order: `20.9.2026`,
/// `9/20/2026`, `2026/9/20`.
///
/// Numeric rather than `yMMMd` on purpose: digits carry no language, so a
/// German phone running an English app gets German *order* without German
/// month names appearing mid-sentence.
String deviceDateLabel(BuildContext context, DateTime date) =>
    DateFormat.yMd(deviceFormatLocale(context)).format(date.toLocal());

/// Date and clock together, each in the device's own convention.
String deviceTimestampLabel(BuildContext context, DateTime date) =>
    '${deviceDateLabel(context, date)} ${deviceClockLabel(context, date)}';
