import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

class SyncMaintenanceRepository {
  final JournalDb _journalDb = getIt<JournalDb>();
  final OutboxService _outboxService = getIt<OutboxService>();
  final LoggingService _loggingService = getIt<LoggingService>();
  final AiConfigRepository _aiConfigRepository = getIt<AiConfigRepository>();

  /// Generic method to sync any type of entity
  Future<void> syncEntities<T>({
    required Future<List<T>> Function() fetchEntities,
    required Future<void> Function(T) enqueueSync,
    required String domain,
    void Function(double)? onProgress,
    void Function(int processed, int total)? onDetailedProgress,
  }) async {
    try {
      final entities = await fetchEntities();
      final total = entities.length;
      var processed = 0;

      if (total == 0) {
        onDetailedProgress?.call(0, 0);
        onProgress?.call(1);
        return;
      }

      onDetailedProgress?.call(0, total);

      for (final entity in entities) {
        final isDeleted =
            entity is EntityDefinition && entity.deletedAt != null ||
                entity is TagEntity && entity.deletedAt != null;

        if (!isDeleted) {
          await enqueueSync(entity);
        }

        processed++;
        onDetailedProgress?.call(processed, total);
        if (onProgress != null) {
          onProgress(processed / total);
        }
      }
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_SERVICE',
        subDomain: domain,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> syncTags({
    void Function(double)? onProgress,
    void Function(int processed, int total)? onDetailedProgress,
  }) async {
    return syncEntities<TagEntity>(
      fetchEntities: () => _journalDb.watchTags().first,
      enqueueSync: (tag) => _outboxService.enqueueMessage(
        SyncMessage.tagEntity(
          tagEntity: tag,
          status: SyncEntryStatus.update,
        ),
      ),
      domain: 'syncTags',
      onProgress: onProgress,
      onDetailedProgress: onDetailedProgress,
    );
  }

  Future<void> syncMeasurables({
    void Function(double)? onProgress,
    void Function(int processed, int total)? onDetailedProgress,
  }) async {
    return syncEntities<EntityDefinition>(
      fetchEntities: () => _journalDb.watchMeasurableDataTypes().first,
      enqueueSync: (measurable) => _outboxService.enqueueMessage(
        SyncMessage.entityDefinition(
          entityDefinition: measurable,
          status: SyncEntryStatus.update,
        ),
      ),
      domain: 'syncMeasurables',
      onProgress: onProgress,
      onDetailedProgress: onDetailedProgress,
    );
  }

  Future<void> syncCategories({
    void Function(double)? onProgress,
    void Function(int processed, int total)? onDetailedProgress,
  }) async {
    return syncEntities<EntityDefinition>(
      fetchEntities: () => _journalDb.watchCategories().first,
      enqueueSync: (category) => _outboxService.enqueueMessage(
        SyncMessage.entityDefinition(
          entityDefinition: category,
          status: SyncEntryStatus.update,
        ),
      ),
      domain: 'syncCategories',
      onProgress: onProgress,
      onDetailedProgress: onDetailedProgress,
    );
  }

  Future<void> syncDashboards({
    void Function(double)? onProgress,
    void Function(int processed, int total)? onDetailedProgress,
  }) async {
    return syncEntities<EntityDefinition>(
      fetchEntities: () => _journalDb.watchDashboards().first,
      enqueueSync: (dashboard) => _outboxService.enqueueMessage(
        SyncMessage.entityDefinition(
          entityDefinition: dashboard,
          status: SyncEntryStatus.update,
        ),
      ),
      domain: 'syncDashboards',
      onProgress: onProgress,
      onDetailedProgress: onDetailedProgress,
    );
  }

  Future<void> syncHabits({
    void Function(double)? onProgress,
    void Function(int processed, int total)? onDetailedProgress,
  }) async {
    return syncEntities<EntityDefinition>(
      fetchEntities: () => _journalDb.watchHabitDefinitions().first,
      enqueueSync: (habit) => _outboxService.enqueueMessage(
        SyncMessage.entityDefinition(
          entityDefinition: habit,
          status: SyncEntryStatus.update,
        ),
      ),
      domain: 'syncHabits',
      onProgress: onProgress,
      onDetailedProgress: onDetailedProgress,
    );
  }

  Future<void> syncAiSettings({
    void Function(double)? onProgress,
    void Function(int processed, int total)? onDetailedProgress,
  }) async {
    Future<List<AiConfig>> fetchConfigsSafely() async {
      try {
        final configGroups = await Future.wait([
          _aiConfigRepository.getConfigsByType(AiConfigType.inferenceProvider),
          _aiConfigRepository.getConfigsByType(AiConfigType.model),
          _aiConfigRepository.getConfigsByType(AiConfigType.prompt),
        ]);

        return configGroups.expand((group) => group).toList();
      } catch (e, stackTrace) {
        _loggingService.captureException(
          e,
          domain: 'SYNC_SERVICE',
          subDomain: 'syncAiSettings_fetch',
          stackTrace: stackTrace,
        );
        rethrow;
      }
    }

    return syncEntities<AiConfig>(
      fetchEntities: fetchConfigsSafely,
      enqueueSync: (config) => _outboxService.enqueueMessage(
        SyncMessage.aiConfig(
          aiConfig: config,
          status: SyncEntryStatus.update,
        ),
      ),
      domain: 'syncAiSettings',
      onProgress: onProgress,
      onDetailedProgress: onDetailedProgress,
    );
  }
}

final syncMaintenanceRepositoryProvider =
    Provider<SyncMaintenanceRepository>((ref) {
  return SyncMaintenanceRepository();
});
