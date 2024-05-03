import 'package:flutter/foundation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

class DatabaseUpdateNotifications {
  DatabaseUpdateNotifications() {
    listen();
  }

  final JournalDb _journalDb = getIt<JournalDb>();

  void listen() {
    _journalDb.countJournalEntries().watch().listen((event) async {
      final start = DateTime.now();
      final count = await _journalDb.countJournalEntries().getSingle();
      final end = DateTime.now();
      final duration = end.difference(start).inMicroseconds / 1000;
      debugPrint('DatabaseUpdateNotifications $count - $duration ms');
    });
  }
}
