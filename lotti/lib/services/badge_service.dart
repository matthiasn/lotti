import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';

class BadgeService {
  static Future<void> setFlaggedCounter() async {
    final JournalDb _journalDb = getIt<JournalDb>();
    int counter = await _journalDb.getCountImportFlagEntries();
    FlutterAppBadger.updateBadgeCount(counter);
  }
}
