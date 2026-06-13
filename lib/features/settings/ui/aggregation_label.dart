import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Localized display name for an [AggregationType].
///
/// Settings surfaces (the measurables editor's aggregation picker, the
/// dashboard charts list) must never leak raw enum identifiers like
/// `dailySum` into the UI; this maps every aggregation type onto its
/// l10n label ("Daily sum", "None", ...).
String aggregationTypeLabel(
  AppLocalizations messages,
  AggregationType aggregationType,
) {
  switch (aggregationType) {
    case AggregationType.none:
      return messages.aggregationNone;
    case AggregationType.dailySum:
      return messages.aggregationDailySum;
    case AggregationType.dailyMax:
      return messages.aggregationDailyMax;
    case AggregationType.dailyAvg:
      return messages.aggregationDailyAvg;
    case AggregationType.hourlySum:
      return messages.aggregationHourlySum;
  }
}
