import 'package:intl/intl.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_wrapper.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/voice/day_plan_functions.dart';
import 'package:lotti/features/daily_os/voice/day_plan_voice_strategy.dart';
import 'package:lotti/features/tasks/ui/utils.dart' show openTaskStatuses;
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'day_plan_voice_service.g.dart';

/// Result of processing a voice day plan transcript.
class DayPlanVoiceResult {
  const DayPlanVoiceResult({
    required this.actions,
    required this.hadErrors,
  });

  final List<DayPlanActionResult> actions;
  final bool hadErrors;
}

/// Service that orchestrates voice-based day planning.
///
/// Processes transcribed voice commands through an LLM with function calling
/// to manipulate day plan blocks and tasks.
@riverpod
class DayPlanVoiceService extends _$DayPlanVoiceService {
  @override
  void build() {} // No state, just methods

  /// Processes a transcribed voice command and executes resulting day plan actions.
  Future<DayPlanVoiceResult> processTranscript({
    required String transcript,
    required DateTime date,
  }) async {
    // Get dependencies via GetIt (singletons) and Riverpod (scoped providers)
    final cacheService = getIt<EntitiesCacheService>();
    final db = getIt<JournalDb>();
    final fts5Db = getIt<Fts5Db>();
    final aiConfigRepo = ref.read(aiConfigRepositoryProvider);
    final cloudInferenceRepo = ref.read(cloudInferenceRepositoryProvider);

    // 1. Get current day plan state
    final unifiedData = await ref.read(
      unifiedDailyOsDataControllerProvider(date: date).future,
    );

    // 2. Fetch open tasks for context
    final taskEntities = await db.getTasks(
      starredStatuses: [false, true],
      taskStatuses: openTaskStatuses,
      categoryIds: [],
      limit: 50,
    );
    final openTasks = taskEntities.whereType<Task>().toList();

    // 3. Build system prompt with context
    final categories = cacheService.sortedCategories;
    final systemPrompt = _buildSystemPrompt(
      date: date,
      currentPlan: unifiedData.dayPlan.data,
      categories: categories,
      openTasks: openTasks,
    );

    // 4. Get inference model/provider (prefer function-calling capable)
    final (model, provider) = await _selectFunctionCallingModel(aiConfigRepo);

    // 5. Create conversation and process
    final conversationRepo = ref.read(conversationRepositoryProvider.notifier);
    final conversationId = conversationRepo.createConversation(
      systemMessage: systemPrompt,
      maxTurns: 3,
    );

    final strategy = DayPlanVoiceStrategy(
      date: date,
      dayPlanController: ref.read(
        unifiedDailyOsDataControllerProvider(date: date).notifier,
      ),
      categoryResolver: CategoryResolver(cacheService),
      taskSearcher: TaskSearcher(db, fts5Db),
      currentPlanData: unifiedData.dayPlan.data,
    );

    try {
      await conversationRepo.sendMessage(
        conversationId: conversationId,
        message: transcript,
        model: model.providerModelId,
        provider: provider,
        inferenceRepo:
            CloudInferenceWrapper(cloudRepository: cloudInferenceRepo),
        tools: DayPlanFunctions.getTools(),
        temperature: 0.1,
        strategy: strategy,
      );
    } finally {
      conversationRepo.deleteConversation(conversationId);
    }

    return DayPlanVoiceResult(
      actions: strategy.results,
      hadErrors: strategy.results.any((r) => !r.success),
    );
  }

  /// Selects a model with function calling capability.
  ///
  /// Model selection rationale for voice day planning:
  /// - **Speed**: Voice interactions require low latency for good UX
  /// - **Cost**: Day planning is a frequent operation, so cost efficiency matters
  /// - **Function calling**: Must reliably follow tool schemas
  ///
  /// Preferred models (in order):
  /// 1. Mistral Small - Fast, cost-effective, excellent function calling
  /// 2. Gemini 2.5 Flash - Good balance of speed and capability
  /// 3. Gemini 2.0 Flash - Reliable fallback with function support
  ///
  /// If none of the preferred models are configured, falls back to the first
  /// available model that supports function calling.
  Future<(AiConfigModel, AiConfigInferenceProvider)>
      _selectFunctionCallingModel(
    AiConfigRepository aiConfigRepo,
  ) async {
    final models = await aiConfigRepo.getConfigsByType(AiConfigType.model);
    final providers =
        await aiConfigRepo.getConfigsByType(AiConfigType.inferenceProvider);

    // Filter to models that support function calling
    final functionModels = models
        .whereType<AiConfigModel>()
        .where((m) => m.supportsFunctionCalling)
        .toList();

    if (functionModels.isEmpty) {
      throw Exception('No function-calling capable models configured');
    }

    // Preferred models for voice day planning (fast, cost-effective, reliable)
    // Order matters: first match wins
    final preferredIds = [
      'mistral-small',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
    ];
    final model = functionModels.firstWhere(
      (m) => preferredIds.any((id) => m.providerModelId.contains(id)),
      orElse: () => functionModels.first,
    );

    final provider =
        providers.whereType<AiConfigInferenceProvider>().firstWhere(
              (p) => p.id == model.inferenceProviderId,
              orElse: () => throw Exception('Provider not found for model'),
            );

    return (model, provider);
  }

  String _buildSystemPrompt({
    required DateTime date,
    required DayPlanData? currentPlan,
    required List<CategoryDefinition> categories,
    required List<Task> openTasks,
  }) {
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(date);
    final categoryMap = {for (final cat in categories) cat.id: cat.name};

    return '''
You are a day planning assistant helping organize the schedule for $dateStr.

## Available Categories
${_formatCategories(categories)}

## Current Day Plan (blocks with IDs for reference)
${_formatCurrentPlan(currentPlan, categoryMap)}

## Open Tasks (for pinning)
${_formatTasks(openTasks.take(20).toList())}

## Instructions
- Match category names case-insensitively
- Use 24-hour HH:mm format for times (e.g., "09:00", "14:30")
- Reference existing blocks by their ID from "Current Day Plan"
- Search tasks by partial title match
- Execute ALL relevant actions from the user's request

## Examples
"Add 2 hours of work starting at 9" → add_time_block(categoryName="Work", startTime="09:00", endTime="11:00")
"Move the exercise block to 7 AM" → move_time_block(blockId="[id]", newStartTime="07:00")
"Shrink the meeting to just one hour" → resize_time_block(blockId="[id]", newEndTime="[startTime + 1hr]")
"Pin the API task to today" → link_task_to_day(taskTitle="API")
''';
  }

  String _formatCategories(List<CategoryDefinition> categories) {
    if (categories.isEmpty) return 'No categories defined.';
    return categories.map((c) => '- ${c.name}').join('\n');
  }

  String _formatCurrentPlan(
    DayPlanData? plan,
    Map<String, String> categoryIdToName,
  ) {
    if (plan == null || plan.plannedBlocks.isEmpty) {
      return 'No blocks scheduled yet.';
    }
    final buffer = StringBuffer();
    for (final block in plan.plannedBlocks) {
      final start = DateFormat.Hm().format(block.startTime);
      final end = DateFormat.Hm().format(block.endTime);
      final categoryName = categoryIdToName[block.categoryId] ?? 'Unknown';
      // Format: [block-id] HH:mm-HH:mm CategoryName (optional note)
      buffer.writeln(
        '- [${block.id}] $start-$end $categoryName'
        '${block.note != null ? " (${block.note})" : ""}',
      );
    }
    return buffer.toString();
  }

  String _formatTasks(List<Task> tasks) {
    if (tasks.isEmpty) return 'No open tasks.';
    return tasks.map((t) => '- "${t.data.title}" (ID: ${t.id})').join('\n');
  }
}
