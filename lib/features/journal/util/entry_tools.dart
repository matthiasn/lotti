import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/dashboards/config/dashboard_health_config.dart';
import 'package:lotti/themes/theme.dart';

NumberFormat nf = NumberFormat('###.##');

/// Whole-number formatter for metrics where decimals add noise (kcal, steps).
NumberFormat nfWhole = NumberFormat('###');

/// The span between an entry's `dateFrom` and `dateTo` (e.g. a timer's elapsed
/// time).
Duration entryDuration(JournalEntity journalEntity) {
  return journalEntity.meta.dateTo.difference(journalEntity.meta.dateFrom);
}

/// Formats a duration as zero-padded `H:MM:SS`, dropping sub-second precision;
/// returns an empty string for null. See [formatRangeDuration] for the
/// day-aware, seconds-less variant used by the date-time editor.
String formatDuration(Duration? duration) {
  if (duration == null) {
    return '';
  }

  var durationString = duration.toString().split('.').first;

  if (durationString.substring(1, 2) == ':') {
    durationString = '0$durationString';
  }

  return durationString;
}

/// Formats a span as a compact, multi-day-aware readout (e.g. `45m`, `1h 30m`,
/// `1d 7h 45m`) for the start/end date-time editor.
///
/// Unlike [formatDuration] (which renders `H:MM:SS` and would show a multi-day
/// span as `31:45:00`), this drops seconds and rolls whole days into a `d`
/// component. A non-positive span returns `0m`; callers gate truly invalid
/// (negative) ranges separately, so this never needs to render a sign.
String formatRangeDuration(Duration duration) {
  if (duration <= Duration.zero) {
    return '0m';
  }
  final days = duration.inDays;
  final hours = duration.inHours % 24;
  final minutes = duration.inMinutes % 60;
  final parts = <String>[
    if (days > 0) '${days}d',
    if (hours > 0) '${hours}h',
    if (minutes > 0) '${minutes}m',
  ];
  return parts.isEmpty ? '0m' : parts.join(' ');
}

/// Treats a nullable flag (e.g. `meta.private`/`meta.starred`) as false when
/// unset.
// ignore: avoid_positional_boolean_parameters
bool fromNullableBool(bool? value) {
  if (value != null) {
    return value;
  } else {
    return false;
  }
}

DateFormat df = DateFormat('yyyy-MM-dd HH:mm:ss');
DateFormat dfShorter = DateFormat('yyyy-MM-dd HH:mm');
DateFormat dfShort = DateFormat('yyyy-MM-dd');
DateFormat dfYmd = DateFormat('yyyy-MM-dd');
DateFormat hhMmFormat = DateFormat('HH:mm');

/// Strips the `HealthDataType.` enum prefix for display.
String formatType(String s) => s.replaceAll('HealthDataType.', '');

/// Strips the `HealthDataUnit.` enum prefix for display.
String formatUnit(String s) => s.replaceAll('HealthDataUnit.', '');

/// Human-readable name for a health/quantitative data type, e.g.
/// `HealthDataType.BLOOD_PRESSURE_SYSTOLIC` → `Systolic Blood Pressure`.
///
/// Prefers the curated [healthTypes] registry (which also feeds dashboards);
/// falls back to a title-cased version of the stripped enum name so unknown
/// types never surface raw `SCREAMING_SNAKE` identifiers.
String humanHealthTypeName(String dataType) {
  final fromConfig = healthTypes[dataType]?.displayName;
  if (fromConfig != null && fromConfig.isNotEmpty) {
    return fromConfig;
  }
  return _titleCaseTokens(formatType(dataType));
}

/// Human-readable unit for a quantitative entry, e.g. `mmHg`, `bpm`, `kg`.
///
/// Prefers the curated [healthTypes] registry unit; falls back to a cleaned-up
/// version of the stored `HealthDataUnit.*` enum so raw identifiers like
/// `MILLIMETER_OF_MERCURY` never reach the UI.
String humanHealthUnit(QuantitativeData qd) {
  final fromConfig = healthTypes[qd.dataType]?.unit;
  if (fromConfig != null && fromConfig.isNotEmpty) {
    return fromConfig;
  }
  return _titleCaseTokens(formatUnit(qd.unit)).toLowerCase();
}

/// Human-readable workout activity name, e.g. `running` → `Running`,
/// `functionalStrengthTraining` → `Functional Strength Training`.
String humanWorkoutType(String workoutType) => _titleCaseTokens(workoutType);

/// Splits a `camelCase` / `SNAKE_CASE` / `dot.separated` identifier into
/// space-separated, title-cased words.
String _titleCaseTokens(String raw) {
  final spaced = raw
      .replaceAll(RegExp('[_.]'), ' ')
      .replaceAllMapped(
        RegExp('([a-z0-9])([A-Z])'),
        (m) => '${m[1]} ${m[2]}',
      );
  return spaced
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map(
        (w) => w.length == 1
            ? w.toUpperCase()
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');
}

/// A locale-aware, de-emphasized date label for list cards. Keeps the feed
/// scannable by showing only what's needed: the time for today, a weekday for
/// the past/coming week, `MMM d` within the current year, and `MMM d, y` for
/// anything older. [now] is injected so the logic stays deterministic in tests.
String relativeEntryDateLabel(
  DateTime date,
  DateTime now, {
  String? locale,
}) {
  final local = date.toLocal();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfThatDay = DateTime(local.year, local.month, local.day);
  final dayDelta = startOfThatDay.difference(startOfToday).inDays;
  final time = DateFormat.jm(locale).format(local);

  if (dayDelta == 0) {
    return time;
  }
  if (dayDelta.abs() < 7) {
    return '${DateFormat.E(locale).format(local)} $time';
  }
  if (local.year == now.year) {
    return DateFormat.MMMd(locale).format(local);
  }
  return DateFormat.yMMMd(locale).format(local);
}

/// [relativeEntryDateLabel] resolved against the current wall clock and the
/// active locale. Used by list cards; the underlying pure function is unit
/// tested with a fixed `now`.
String entryDateLabel(BuildContext context, DateTime date) {
  return relativeEntryDateLabel(
    date,
    DateTime.now(),
    locale: Localizations.localeOf(context).toString(),
  );
}

class InfoText extends StatelessWidget {
  const InfoText(
    this.text, {
    super.key,
    this.maxLines = 5,
  });

  final String text;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      style: tabularFigureStyle(fontSize: fontSizeMedium),
    );
  }
}

/// Renders a quantitative (health) entry as `type: value unit`, handling both
/// cumulative and discrete data shapes.
String entryTextForQuant(QuantitativeEntry qe) {
  final qd = qe.data;
  return '${humanHealthTypeName(qd.dataType)}: '
      '${nf.format(qd.value)} ${humanHealthUnit(qd)}';
}

/// Multi-line workout summary (type, energy in kcal, duration in minutes);
/// omit the leading type line by passing `includeTitle: false`.
String entryTextForWorkout(
  WorkoutData data, {
  bool includeTitle = true,
}) {
  final duration = data.dateTo.difference(data.dateFrom);
  final title = includeTitle ? '${data.workoutType}\n' : '';
  final energy = data.energy ?? 0;

  return '$title'
      'energy: ${nf.format(energy)} kcal\n'
      'duration: ${duration.inMinutes} minutes';
}

/// Renders a measurement as `name: value unit` using the measurable type's
/// display name and unit.
String entryTextForMeasurable(
  MeasurementData data,
  MeasurableDataType dataType,
) {
  return '${dataType.displayName}: '
      '${nf.format(data.value)} '
      '${dataType.unitName}';
}
