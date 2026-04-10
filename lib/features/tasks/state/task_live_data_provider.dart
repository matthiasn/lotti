import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';

/// Lightweight provider that keeps a single [Task] up-to-date by listening
/// to [UpdateNotifications].
///
/// Unlike `EntryController`, this provider does NOT initialise focus nodes,
/// editor state, hotkeys, or agent infrastructure — making it safe to use
/// for every visible row in a scrolling list. Auto-disposes when the list
/// item scrolls off-screen.
final FutureProviderFamily<Task?, String> taskLiveDataProvider = FutureProvider
    .autoDispose
    .family<Task?, String>((
      ref,
      taskId,
    ) async {
      final db = getIt<JournalDb>();
      final notifications = getIt<UpdateNotifications>();

      final sub = notifications.updateStream.listen((affectedIds) {
        if (affectedIds.contains(taskId)) {
          ref.invalidateSelf();
        }
      });

      ref.onDispose(sub.cancel);

      final entity = await db.journalEntityById(taskId);
      return entity is Task ? entity : null;
    });
