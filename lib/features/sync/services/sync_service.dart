import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

class SyncService {
  final JournalDb _journalDb = getIt<JournalDb>();
  final OutboxService _outboxService = getIt<OutboxService>();
  final LoggingService _loggingService = getIt<LoggingService>();

  Future<void> syncTags() async {
    try {
      // getting here all tags from the database
      final tags = await _journalDb.watchTags().first;

      // syncing each tag
      for (final tag in tags) {
        // Skip deleted or inactive tags
        if (tag.deletedAt != null || tag.inactive!) {
          continue;
        }

        // enqueue the tag for sync
        await _outboxService.enqueueMessage(
          SyncMessage.tagEntity(
            tagEntity: tag,
            status: SyncEntryStatus.update,
          ),
        );
      }
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_SERVICE',
        subDomain: 'syncTags',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> syncMeasurables() async {
    try {
      // getting here all measurables from the database
      final measurables = await _journalDb.watchMeasurableDataTypes().first;

      // syncing each measurable
      for (final measurable in measurables) {
        // Skip deleted or inactive measurables
        if (measurable.deletedAt != null) {
          continue;
        }

        // enqueue the measurable for sync
        await _outboxService.enqueueMessage(
          SyncMessage.entityDefinition(
            entityDefinition: measurable,
            status: SyncEntryStatus.update,
          ),
        );
      }
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_SERVICE',
        subDomain: 'syncMeasurables',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> syncCategories() async {
    try {
      // getting here all categories from the database
      final categories = await _journalDb.watchCategories().first;

      // syncing each category
      for (final category in categories) {
        // Skip deleted or inactive categories
        if (category.deletedAt != null || category.active == false) {
          continue;
        }

        // enqueue the category for sync
        await _outboxService.enqueueMessage(
          SyncMessage.entityDefinition(
            entityDefinition: category,
            status: SyncEntryStatus.update,
          ),
        );
      }
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_SERVICE',
        subDomain: 'syncCategories',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> syncDashboards() async {
    try {
      // getting here all dashboards from the database
      final dashboards = await _journalDb.watchDashboards().first;

      // syncing each dashboard
      for (final dashboard in dashboards) {
        // Skip deleted or inactive dashboards
        if (dashboard.deletedAt != null || dashboard.active == false) {
          continue;
        }

        // enqueue the dashboard for sync
        await _outboxService.enqueueMessage(
          SyncMessage.entityDefinition(
            entityDefinition: dashboard,
            status: SyncEntryStatus.update,
          ),
        );
      }
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_SERVICE',
        subDomain: 'syncDashboards',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> syncHabits() async {
    try {
      // getting here all habits from the database
      final habits = await _journalDb.watchHabitDefinitions().first;

      // syncing each habit
      for (final habit in habits) {
        // Skip deleted or inactive habits
        if (habit.deletedAt != null || habit.active == false) {
          continue;
        }

        // enqueue the habit for sync
        await _outboxService.enqueueMessage(
          SyncMessage.entityDefinition(
            entityDefinition: habit,
            status: SyncEntryStatus.update,
          ),
        );
      }
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_SERVICE',
        subDomain: 'syncHabits',
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});
