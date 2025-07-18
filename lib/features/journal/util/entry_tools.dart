import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/themes/theme.dart';

NumberFormat nf = NumberFormat('###.##');

Duration entryDuration(JournalEntity journalEntity) {
  return journalEntity.meta.dateTo.difference(journalEntity.meta.dateFrom);
}

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

String formatType(String s) => s.replaceAll('HealthDataType.', '');
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
      style: monospaceTextStyle,
    );
  }
}

String entryTextForQuant(QuantitativeEntry qe) {
  return qe.data.map(
    cumulativeQuantityData: (qd) => '${formatType(qd.dataType)}: '
        '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
    discreteQuantityData: (qd) => '${formatType(qd.dataType)}: '
        '${nf.format(qd.value)} ${formatUnit(qd.unit)}',
  );
}

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

String entryTextForMeasurable(
  MeasurementData data,
  MeasurableDataType dataType,
) {
  return '${dataType.displayName}: '
      '${nf.format(data.value)} '
      '${dataType.unitName}';
}
