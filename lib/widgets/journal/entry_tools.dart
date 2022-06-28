import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme/theme.dart';

NumberFormat nf = NumberFormat('###.##');

NumberFormat latLonFormat = NumberFormat('###.##');

Duration entryDuration(JournalEntity journalEntity) {
  return journalEntity.meta.dateTo.difference(journalEntity.meta.dateFrom);
}

String formatDuration(Duration? duration) {
  var durationString = duration?.toString().split('.').first ?? '';

  if (durationString.substring(0, 2) == '0:') {
    durationString = '0$durationString';
  }

  return durationString;
}

String formatLatLon(double? number) {
  if (number != null) {
    return latLonFormat.format(number);
  } else {
    return '';
  }
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
DateFormat hhMmFormat = DateFormat('HH:mm');

String formatType(String s) => s.replaceAll('HealthDataType.', '');
String formatUnit(String s) => s.replaceAll('HealthDataUnit.', '');
String formatAudio(JournalAudio journalAudio) =>
    'Audio Note: ${journalAudio.data.duration.toString().split('.')[0]}';

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
      style: TextStyle(
        fontFamily: 'ShareTechMono',
        fontSize: 14,
        color: getIt<ThemeService>().colors.entryTextColor,
      ),
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

String entryTextForWorkout(WorkoutData data) {
  final duration = data.dateTo.difference(data.dateFrom);

  return '${data.workoutType}\n'
      'energy: ${nf.format(data.energy)} kcal\n'
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
