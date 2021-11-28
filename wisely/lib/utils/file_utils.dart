import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wisely/classes/journal_entities.dart';

Future<void> saveJournalEntryJson(JournalEntry journalEntry) async {
  String json = jsonEncode(journalEntry);
  var docDir = await getApplicationDocumentsDirectory();
  DateFormat df = DateFormat('yyyy-MM-dd');
  String folder = df.format(journalEntry.meta.createdAt);
  String fileName = '${journalEntry.meta.id}.json';
  String path = '${docDir.path}/entries/$folder/$fileName';
  File file = await File(path).create(recursive: true);
  await file.writeAsString(json);
}

Future<void> saveSurveyEntryJson(SurveyEntry surveyEntry) async {
  String json = jsonEncode(surveyEntry);
  var docDir = await getApplicationDocumentsDirectory();
  DateFormat df = DateFormat('yyyy-MM-dd');
  String folder = df.format(surveyEntry.meta.createdAt);
  String fileName = '${surveyEntry.meta.id}.survey.json';
  String path = '${docDir.path}/surveys/$folder/$fileName';
  File file = await File(path).create(recursive: true);
  await file.writeAsString(json);
}

Future<void> saveQuantitativeEntryJson(
    QuantitativeEntry quantitativeEntry) async {
  String json = jsonEncode(quantitativeEntry);
  var docDir = await getApplicationDocumentsDirectory();
  DateFormat df = DateFormat('yyyy-MM-dd');
  String folder = df.format(quantitativeEntry.meta.createdAt);
  String fileName = '${quantitativeEntry.meta.id}.quantitative.json';
  String path = '${docDir.path}/quantitative/$folder/$fileName';
  File file = await File(path).create(recursive: true);
  await file.writeAsString(json);
}
