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
