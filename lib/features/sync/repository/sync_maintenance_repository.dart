import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/models/sync_models.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';

typedef SyncProgressCallback = void Function(double progress);
typedef SyncDetailedProgressCallback = void Function(int processed, int total);

class SyncOperation<T> {
  const SyncOperation({
    required this.step,
    required this.syncDomain,
    required this.totalsDomain,
    required this.fetchEntities,
    required this.enqueueEntity,
    required this.shouldSync,
  });

  final SyncStep step;
  final String syncDomain;
  final String totalsDomain;
  final Future<List<T>> Function() fetchEntities;
  final Future<void> Function(T entity) enqueueEntity;
  final bool Function(T entity) shouldSync;
}

class SyncMaintenanceRepository {
  SyncMaintenanceRepository({
    JournalDb? journalDb,
    OutboxService? outboxService,
    LoggingService? loggingService,
    AiConfigRepository? aiConfigRepository,
  })  : _journalDb = journalDb ?? getIt<JournalDb>(),
        _outboxService = outboxService ?? getIt<OutboxService>(),
        _loggingService = loggingService ?? getIt<LoggingService>(),
        _aiConfigRepository = aiConfigRepository ?? getIt<AiConfigRepository>();

  final JournalDb _journalDb;
  final OutboxService _outboxService;
  final LoggingService _loggingService;
  final AiConfigRepository _aiConfigRepository;

  late final SyncOperation<TagEntity> _tagSyncOperation =
      _createOperation<TagEntity>(
    step: SyncStep.tags,
    fetchEntities: () => _journalDb.watchTags().first,
    enqueueEntity: (tag) => _outboxService.enqueueMessage(
      SyncMessage.tagEntity(
        tagEntity: tag,
        status: SyncEntryStatus.update,
      ),
    ),
    shouldSync: (tag) => tag.deletedAt == null,
  );

  late final SyncOperation<MeasurableDataType> _measurableSyncOperation =
      _createOperation<MeasurableDataType>(
    step: SyncStep.measurables,
    fetchEntities: () => _journalDb.watchMeasurableDataTypes().first,
    enqueueEntity: (measurable) => _outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: measurable,
        status: SyncEntryStatus.update,
      ),
    ),
    shouldSync: (measurable) => measurable.deletedAt == null,
  );

  late final SyncOperation<CategoryDefinition> _categorySyncOperation =
      _createOperation<CategoryDefinition>(
    step: SyncStep.categories,
    fetchEntities: () => _journalDb.watchCategories().first,
    enqueueEntity: (category) => _outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: category,
        status: SyncEntryStatus.update,
      ),
    ),
    shouldSync: (category) => category.deletedAt == null,
  );

  late final SyncOperation<DashboardDefinition> _dashboardSyncOperation =
      _createOperation<DashboardDefinition>(
    step: SyncStep.dashboards,
    fetchEntities: () => _journalDb.watchDashboards().first,
    enqueueEntity: (dashboard) => _outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: dashboard,
        status: SyncEntryStatus.update,
      ),
    ),
    shouldSync: (dashboard) => dashboard.deletedAt == null,
  );

  late final SyncOperation<HabitDefinition> _habitSyncOperation =
      _createOperation<HabitDefinition>(
    step: SyncStep.habits,
    fetchEntities: () => _journalDb.watchHabitDefinitions().first,
    enqueueEntity: (habit) => _outboxService.enqueueMessage(
      SyncMessage.entityDefinition(
        entityDefinition: habit,
        status: SyncEntryStatus.update,
      ),
    ),
    shouldSync: (habit) => habit.deletedAt == null,
  );

  late final SyncOperation<AiConfig> _aiConfigSyncOperation =
      _createOperation<AiConfig>(
    step: SyncStep.aiSettings,
    fetchEntities: _fetchAiConfigsSafely,
    enqueueEntity: (config) => _outboxService.enqueueMessage(
      SyncMessage.aiConfig(
        aiConfig: config,
        status: SyncEntryStatus.update,
      ),
    ),
    shouldSync: (_) => true,
  );

  late final Map<SyncStep, SyncOperation<dynamic>> _operations = {
    SyncStep.tags: _tagSyncOperation,
    SyncStep.measurables: _measurableSyncOperation,
    SyncStep.categories: _categorySyncOperation,
    SyncStep.dashboards: _dashboardSyncOperation,
    SyncStep.habits: _habitSyncOperation,
    SyncStep.aiSettings: _aiConfigSyncOperation,
  };

  Future<void> syncTags({
    SyncProgressCallback? onProgress,
    SyncDetailedProgressCallback? onDetailedProgress,
  }) {
    return _runOperation<TagEntity>(
      _tagSyncOperation,
      onProgress: onProgress,
      onDetailedProgress: onDetailedProgress,
    );
  }

  Future<void> syncMeasurables({
    SyncProgressCallback? onProgress,
    SyncDetailedProgressCallback? onDetailedProgress,
  }) {
    return _runOperation<MeasurableDataType>(
      _measurableSyncOperation,
      onProgress: onProgress,
      onDetailedProgress: onDetailedProgress,
    );
  }

  Future<void> syncCategories({
    SyncProgressCallback? onProgress,
    SyncDetailedProgressCallback? onDetailedProgress,
  }) {
    return _runOperation<CategoryDefinition>(
      _categorySyncOperation,
      onProgress: onProgress,
      onDetailedProgress: onDetailedProgress,
    );
  }

  Future<void> syncDashboards({
    SyncProgressCallback? onProgress,
    SyncDetailedProgressCallback? onDetailedProgress,
  }) {
    return _runOperation<DashboardDefinition>(
      _dashboardSyncOperation,
      onProgress: onProgress,
      onDetailedProgress: onDetailedProgress,
    );
  }

  Future<void> syncHabits({
    SyncProgressCallback? onProgress,
    SyncDetailedProgressCallback? onDetailedProgress,
  }) {
    return _runOperation<HabitDefinition>(
      _habitSyncOperation,
      onProgress: onProgress,
      onDetailedProgress: onDetailedProgress,
    );
  }

  Future<void> syncAiSettings({
    SyncProgressCallback? onProgress,
    SyncDetailedProgressCallback? onDetailedProgress,
  }) {
    return _runOperation<AiConfig>(
      _aiConfigSyncOperation,
      onProgress: onProgress,
      onDetailedProgress: onDetailedProgress,
    );
  }

  Future<Map<SyncStep, int>> fetchTotalsForSteps(Set<SyncStep> steps) async {
    if (steps.isEmpty) {
      return const {};
    }

    final entries = await Future.wait(
      steps.map((step) async {
        final total = await _calculateTotalForStep(step);
        return MapEntry(step, total);
      }),
    );

    return Map<SyncStep, int>.fromEntries(entries);
  }

  Future<int> _calculateTotalForStep(SyncStep step) async {
    if (step == SyncStep.complete) {
      return 0;
    }

    final operation = _operations[step];
    if (operation == null) {
      return 0;
    }

    return _runWithLogging<int>(
      () async {
        final entities = await operation.fetchEntities();
        return entities.length;
      },
      operation.totalsDomain,
    );
  }

  Future<void> _runOperation<T>(
    SyncOperation<T> operation, {
    SyncProgressCallback? onProgress,
    SyncDetailedProgressCallback? onDetailedProgress,
  }) {
    return _runWithLogging<void>(
      () async {
        final entities = await operation.fetchEntities();
        final total = entities.length;

        if (total == 0) {
          onDetailedProgress?.call(0, 0);
          onProgress?.call(1);
          return;
        }

        onDetailedProgress?.call(0, total);

        var processed = 0;
        for (final entity in entities) {
          if (operation.shouldSync(entity)) {
            await operation.enqueueEntity(entity);
          }

          processed++;
          onDetailedProgress?.call(processed, total);
          onProgress?.call(processed / total);
        }
      },
      operation.syncDomain,
    );
  }

  Future<T> _runWithLogging<T>(
    Future<T> Function() run,
    String subDomain,
  ) async {
    try {
      return await run();
    } catch (e, stackTrace) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_SERVICE',
        subDomain: subDomain,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<List<AiConfig>> _fetchAiConfigsSafely() async {
    return _runWithLogging<List<AiConfig>>(
      () async {
        final configGroups = await Future.wait([
          _aiConfigRepository.getConfigsByType(
            AiConfigType.inferenceProvider,
          ),
          _aiConfigRepository.getConfigsByType(AiConfigType.model),
          _aiConfigRepository.getConfigsByType(AiConfigType.prompt),
        ]);

        return configGroups.expand((group) => group).toList();
      },
      'syncAiSettings_fetch',
    );
  }

  SyncOperation<T> _createOperation<T>({
    required SyncStep step,
    required Future<List<T>> Function() fetchEntities,
    required Future<void> Function(T entity) enqueueEntity,
    required bool Function(T entity) shouldSync,
  }) {
    return SyncOperation<T>(
      step: step,
      syncDomain: _syncDomainFor(step),
      totalsDomain: _totalsDomainFor(step),
      fetchEntities: fetchEntities,
      enqueueEntity: enqueueEntity,
      shouldSync: shouldSync,
    );
  }

  String _syncDomainFor(SyncStep step) {
    switch (step) {
      case SyncStep.tags:
        return 'syncTags';
      case SyncStep.measurables:
        return 'syncMeasurables';
      case SyncStep.categories:
        return 'syncCategories';
      case SyncStep.dashboards:
        return 'syncDashboards';
      case SyncStep.habits:
        return 'syncHabits';
      case SyncStep.aiSettings:
        return 'syncAiSettings';
      case SyncStep.complete:
        throw UnsupportedError('SyncStep.complete has no sync domain.');
    }
  }

  String _totalsDomainFor(SyncStep step) {
    switch (step) {
      case SyncStep.tags:
        return 'fetchTotals_tags';
      case SyncStep.measurables:
        return 'fetchTotals_measurables';
      case SyncStep.categories:
        return 'fetchTotals_categories';
      case SyncStep.dashboards:
        return 'fetchTotals_dashboards';
      case SyncStep.habits:
        return 'fetchTotals_habits';
      case SyncStep.aiSettings:
        return 'fetchTotals_aiSettings';
      case SyncStep.complete:
        throw UnsupportedError('SyncStep.complete has no totals domain.');
    }
  }
}

final syncMaintenanceRepositoryProvider =
    Provider<SyncMaintenanceRepository>((ref) {
  return SyncMaintenanceRepository();
});
