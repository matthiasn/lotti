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
    required this.fetchEntities,
    required this.enqueueEntity,
    this.shouldSync,
    this.fetchTotalCount,
    String? totalCountDomain,
  }) : totalCountDomain = totalCountDomain ?? syncDomain;

  final SyncStep step;
  final String syncDomain;
  final String totalCountDomain;
  final Future<List<T>> Function() fetchEntities;
  final Future<void> Function(T entity) enqueueEntity;
  final bool Function(T entity)? shouldSync;
  final Future<int> Function()? fetchTotalCount;
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
      SyncOperation<TagEntity>(
    step: SyncStep.tags,
    syncDomain: 'syncTags',
    totalCountDomain: 'fetchTotals_tags',
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
      SyncOperation<MeasurableDataType>(
    step: SyncStep.measurables,
    syncDomain: 'syncMeasurables',
    totalCountDomain: 'fetchTotals_measurables',
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
      SyncOperation<CategoryDefinition>(
    step: SyncStep.categories,
    syncDomain: 'syncCategories',
    totalCountDomain: 'fetchTotals_categories',
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
      SyncOperation<DashboardDefinition>(
    step: SyncStep.dashboards,
    syncDomain: 'syncDashboards',
    totalCountDomain: 'fetchTotals_dashboards',
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
      SyncOperation<HabitDefinition>(
    step: SyncStep.habits,
    syncDomain: 'syncHabits',
    totalCountDomain: 'fetchTotals_habits',
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
      SyncOperation<AiConfig>(
    step: SyncStep.aiSettings,
    syncDomain: 'syncAiSettings',
    totalCountDomain: 'fetchTotals_aiSettings',
    fetchEntities: _fetchAiConfigsSafely,
    enqueueEntity: (config) => _outboxService.enqueueMessage(
      SyncMessage.aiConfig(
        aiConfig: config,
        status: SyncEntryStatus.update,
      ),
    ),
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
        final fetchTotal = operation.fetchTotalCount;
        if (fetchTotal != null) {
          return fetchTotal();
        }
        final entities = await operation.fetchEntities();
        return entities.length;
      },
      operation.totalCountDomain,
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
          if (_shouldSyncEntity(operation, entity)) {
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

  bool _shouldSyncEntity<T>(SyncOperation<T> operation, T entity) {
    final predicate = operation.shouldSync;
    if (predicate != null) {
      return predicate(entity);
    }
    return _defaultShouldSync(entity);
  }

  bool _defaultShouldSync(Object? entity) {
    if (entity == null) {
      return true;
    }
    if (entity is TagEntity) {
      return entity.deletedAt == null;
    }
    if (entity is EntityDefinition) {
      return entity.deletedAt == null;
    }
    return true;
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
}

final syncMaintenanceRepositoryProvider =
    Provider<SyncMaintenanceRepository>((ref) {
  return SyncMaintenanceRepository();
});
