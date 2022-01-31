import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';

NumberFormat nf = NumberFormat('###.##');

NumberFormat latLonFormat = NumberFormat('###.##');

Duration entryDuration(JournalEntity journalEntity) {
  return journalEntity.meta.dateTo.difference(journalEntity.meta.dateFrom);
}

String formatDuration(Duration? duration) {
  return duration?.toString().split('.').first ?? '';
}

String formatLatLon(double? number) {
  if (number != null) {
    return latLonFormat.format(number);
  } else {
    return '';
  }
}

bool fromNullableBool(bool? value) {
  if (value != null) {
    return value;
  } else {
    return false;
  }
}

DateFormat df = DateFormat('yyyy-MM-dd HH:mm:ss');

String formatType(String s) => s.replaceAll('HealthDataType.', '');
String formatUnit(String s) => s.replaceAll('HealthDataUnit.', '');
String formatAudio(JournalAudio journalAudio) =>
    'Audio Note: ${journalAudio.data.duration.toString().split('.')[0]}';

class InfoText extends StatelessWidget {
  final String text;
  final int maxLines;
  const InfoText(
    this.text, {
    Key? key,
    this.maxLines = 5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        maxLines: maxLines,
        style: const TextStyle(
          fontFamily: 'ShareTechMono',
          fontSize: 14.0,
        ));
  }
}
