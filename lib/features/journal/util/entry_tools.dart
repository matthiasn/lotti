import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/health.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/themes/theme.dart';

NumberFormat nf = NumberFormat('###.##');

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
  return switch (qd) {
    CumulativeQuantityData(:final dataType, :final value, :final unit) =>
      '${formatType(dataType)}: ${nf.format(value)} ${formatUnit(unit)}',
    DiscreteQuantityData(:final dataType, :final value, :final unit) =>
      '${formatType(dataType)}: ${nf.format(value)} ${formatUnit(unit)}',
  };
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
