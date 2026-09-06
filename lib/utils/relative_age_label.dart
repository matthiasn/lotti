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
