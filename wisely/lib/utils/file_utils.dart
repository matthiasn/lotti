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
