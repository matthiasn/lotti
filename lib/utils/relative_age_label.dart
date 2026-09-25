import 'package:intl/intl.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// "just now" · "3 min ago" · "1 h ago" · "2 days ago" — the one
/// minute/hour/day bucketing every "as of …" line uses, on the generic
/// relative-age catalog entries so no parallel vocabulary drifts per
/// language.
String relativeAgoLabel(AppLocalizations messages, Duration age) {
  if (age.inMinutes < 1) return messages.conflictBannerAgoJustNow;
  if (age.inHours < 1) return messages.conflictBannerAgoMinutes(age.inMinutes);
  if (age.inDays < 1) return messages.conflictBannerAgoHours(age.inHours);
  return messages.conflictBannerAgoDays(age.inDays);
}

/// How long until [relativeAgoLabel] would say something different for an
/// age of [age] — the next minute, hour or day boundary, plus a second of
/// slack. A surface that shows an "as of" line arms one timer for this
/// rather than ticking every second.
Duration untilNextAgeBucket(Duration age) {
  if (age.inHours < 1) {
    return Duration(seconds: 60 - (age.inSeconds % 60) + 1);
  }
  if (age.inDays < 1) {
    return Duration(seconds: 3600 - (age.inSeconds % 3600) + 1);
  }
  return Duration(seconds: 86400 - (age.inSeconds % 86400) + 1);
}

/// How old a timestamp may be before [relativeAgeOrDateLabel] names the date
/// instead: "12 days ago" asks the reader to count back, "Sep 13" does not.
const relativeAgeDateThreshold = Duration(days: 7);

/// [relativeAgoLabel] for [at] up to [relativeAgeDateThreshold] before [now],
/// and the date beyond it — "Sep 13", with the year once it is not [now]'s.
///
/// The date is the viewer's: both instants are read in local time, so a
/// timestamp parsed from a `Z`-suffixed string names the day it was on the
/// reader's calendar, and "this year" is the reader's year.
String relativeAgeOrDateLabel(
  AppLocalizations messages, {
  required DateTime at,
  required DateTime now,
}) {
  final age = now.difference(at);
  if (age < relativeAgeDateThreshold) return relativeAgoLabel(messages, age);
  final localAt = at.toLocal();
  final format = localAt.year == now.toLocal().year
      ? DateFormat.MMMd(messages.localeName)
      : DateFormat.yMMMd(messages.localeName);
  return format.format(localAt);
}
