import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/workflow/change_set_builder.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/services/onboarding_task_structuring_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Outcome of turning a captured transcript into a task.
///
/// [isRealAha] distinguishes the structured win (title + checklist from the
/// LLM) from the title-only [OnboardingStructuringFailure] soft landing, so the
/// UI can reserve the celebration for the real thing. [task] is null only when
/// persistence itself failed or there was nothing to title.
@immutable
class OnboardingCaptureResult {
  const OnboardingCaptureResult({
    required this.task,
    required this.title,
    required this.checklistItems,
    required this.isRealAha,
    this.failure,
  });

  final Task? task;
  final String title;
  final List<String> checklistItems;
  final bool isRealAha;

  /// The structuring failure that forced the soft landing, if any.
  final OnboardingStructuringFailure? failure;

  bool get created => task != null;
}

/// Orchestrates the onboarding aha: structure a transcript into `{title,
/// checklist}` and materialise it as a real task, recording the funnel events
/// and soft-landing on a title-only task when structuring fails.
class OnboardingCaptureToTaskService {
  OnboardingCaptureToTaskService({
    required this._structuringService,
    required this._metricsRepository,
    required this._categoryRepository,
    required this._taskAgentService,
    PersistenceLogic? persistenceLogic,
    JournalRepository? journalRepository,
    DateTime Function()? clock,
  }) : _persistenceLogic = persistenceLogic ?? getIt<PersistenceLogic>(),
       // `journalRepositoryProvider` is itself just `JournalRepository()` (the
       // repo is stateless and resolves its DB via getIt), so this fallback is
       // equivalent to the injected instance — not a divergent graph.
       _journalRepository = journalRepository ?? JournalRepository(),
       _clock = clock ?? DateTime.now;

  final OnboardingTaskStructuringService _structuringService;
  final OnboardingMetricsRepository _metricsRepository;
  final CategoryRepository _categoryRepository;
  final TaskAgentService _taskAgentService;
  final PersistenceLogic _persistenceLogic;
  final JournalRepository _journalRepository;
  final DateTime Function() _clock;

  static const int _maxFloorTitleLength = 80;

  /// Recorded as the `structuring_failed` reason when structuring succeeded but
  /// the task could not be persisted.
  static const String _persistFailedReason = 'persist_failed';

  /// Structures [transcript] and persists the resulting task in [categoryId].
  ///
  /// Always emits [OnboardingEventName.makeTaskTapped] up front, then either
  /// [OnboardingEventName.realAha] (structured task landed) or the
  /// `structuring_failed` + `structuring_floor_used` pair (title-only soft
  /// landing). [providerName] is an optional low-cardinality funnel dimension.
  ///
  /// [audioId] is the `JournalAudio` entry the capture controller persisted for
  /// the spoken capture (null on the typed path); it is linked under the task
  /// so the recording — transcript, playback, and downstream affordances like
  /// cover art — lives on the task instead of orphaned in the journal.
  Future<OnboardingCaptureResult> createTaskFromTranscript({
    required String transcript,
    required String categoryId,
    String? providerName,
    String? audioId,
  }) async {
    await _metricsRepository.recordEvent(
      OnboardingEventName.makeTaskTapped,
      provider: providerName,
    );

    final OnboardingStructuredTask structured;
    try {
      structured = await _structuringService.structure(
        transcript: transcript,
        categoryId: categoryId,
      );
    } on OnboardingStructuringException catch (exception) {
      return _softLand(
        transcript: transcript,
        categoryId: categoryId,
        failure: exception.failure,
        providerName: providerName,
        audioId: audioId,
      );
    }

    final task = await _materialize(
      title: structured.title,
      items: structured.checklistItems,
      categoryId: categoryId,
      audioId: audioId,
    );

    if (task == null) {
      // Structuring succeeded but the write failed — not a real aha.
      await _metricsRepository.recordEvent(
        OnboardingEventName.structuringFailed,
        reason: _persistFailedReason,
        provider: providerName,
      );
      return OnboardingCaptureResult(
        task: null,
        title: structured.title,
        checklistItems: structured.checklistItems,
        isRealAha: false,
      );
    }

    await _metricsRepository.recordEvent(
      OnboardingEventName.realAha,
      provider: providerName,
    );
    return OnboardingCaptureResult(
      task: task,
      title: structured.title,
      checklistItems: structured.checklistItems,
      isRealAha: true,
    );
  }

  /// Builds a title-only task straight from the transcript when structuring
  /// failed, so the user still leaves with a real artifact.
  Future<OnboardingCaptureResult> _softLand({
    required String transcript,
    required String categoryId,
    required OnboardingStructuringFailure failure,
    required String? providerName,
    required String? audioId,
  }) async {
    await _metricsRepository.recordEvent(
      OnboardingEventName.structuringFailed,
      reason: failure.name,
      provider: providerName,
    );

    final title = _fallbackTitle(transcript);
    if (title.isEmpty) {
      // Nothing intelligible to title (e.g. an empty transcript) — never make a
      // blank artifact.
      return OnboardingCaptureResult(
        task: null,
        title: '',
        checklistItems: const [],
        isRealAha: false,
        failure: failure,
      );
    }

    final task = await _materialize(
      title: title,
      items: const [],
      categoryId: categoryId,
      audioId: audioId,
    );
    if (task != null) {
      await _metricsRepository.recordEvent(
        OnboardingEventName.structuringFloorUsed,
        provider: providerName,
      );
    }
    return OnboardingCaptureResult(
      task: task,
      title: title,
      checklistItems: const [],
      isRealAha: false,
      failure: failure,
    );
  }

  /// Creates the title-only task, then links the captured audio entry and
  /// assigns the category's default agent — seeding the structured checklist
  /// as pending proposals rather than committing it (see [_assignCategoryAgent]
  /// / [_seedChecklistProposals]). All best effort, so a hiccup in any
  /// follow-up step degrades to a bare-title task rather than failing.
  Future<Task?> _materialize({
    required String title,
    required List<String> items,
    required String categoryId,
    required String? audioId,
  }) async {
    // Resolved through the repository, not EntitiesCacheService: the category
    // was created moments ago in this same flow and the cache refreshes
    // asynchronously off the notification stream. Best effort — the task must
    // land even without profile inheritance or an agent.
    CategoryDefinition? category;
    try {
      category = await _categoryRepository.getCategoryById(categoryId);
    } catch (_) {
      category = null;
    }

    final now = _clock();
    final task = await _persistenceLogic.createTaskEntry(
      data: TaskData(
        // The onboarding task lands already in progress — the user just spoke it
        // into being and is dropped straight onto it, so "in progress" reads
        // truer than "open" and the task page opens mid-flow.
        status: TaskStatus.inProgress(
          id: _uuid.v4(),
          createdAt: now,
          utcOffset: now.timeZoneOffset.inMinutes,
        ),
        title: title,
        statusHistory: const [],
        dateFrom: now,
        dateTo: now,
        estimate: Duration.zero,
        profileId: category?.defaultProfileId,
      ),
      entryText: EntryText(plainText: title, markdown: title),
      categoryId: categoryId,
    );

    if (task != null && audioId != null) {
      // Attach the spoken capture under the task, mirroring how in-task
      // recordings are linked — including the category: the capture
      // controller persisted the audio entry without one, and an
      // uncategorized recording would vanish from every category-filtered
      // view of the area the task just landed in. Best effort: the task must
      // land even if either write fails.
      try {
        await _persistenceLogic.createLink(fromId: task.id, toId: audioId);
        await _journalRepository.updateCategoryId(
          audioId,
          categoryId: categoryId,
        );
      } catch (_) {
        // Keep the task without the audio link/category.
      }
    }

    if (task != null) {
      await _assignCategoryAgent(
        task: task,
        category: category,
        items: items,
        audioId: audioId,
      );
    }
    return task;
  }

  /// Spawns the category's default agent for [task], mirroring the
  /// auto-assign hook on the normal task-creation path (`create_entry.dart`):
  /// gated on the category carrying a `defaultTemplateId` (e.g. Laura), with
  /// the category's default profile.
  ///
  /// Unlike the normal path — which creates the agent for a *blank* task and
  /// must wait for content — the onboarding agent is created last, after the
  /// title and transcribed audio have landed. So no `awaitContent` gate (whose
  /// skipped wake would be dropped, leaving the agent inert on a task that
  /// never gets edited again): the creation wake runs the first full turn right
  /// away, and [audioId] rides along in the wake's trigger tokens so that turn
  /// attends to the spoken capture exactly like the `transcriptionComplete`
  /// wake after an in-task recording.
  ///
  /// Once the agent exists, [items] (the structured checklist) are seeded as
  /// pending proposals under it via [_seedChecklistProposals], so the user
  /// lands on a task page that is already alive — the checklist waiting as
  /// confirmable suggestions ("Confirm all"), plus Laura's summary and any
  /// suggestions from her concurrent wake, which merge into the same card.
  ///
  /// Best effort: the task must land even if agent creation fails.
  Future<void> _assignCategoryAgent({
    required Task task,
    required CategoryDefinition? category,
    required List<String> items,
    required String? audioId,
  }) async {
    final templateId = category?.defaultTemplateId;
    if (category == null || templateId == null) return;
    try {
      final identity = await _taskAgentService.createTaskAgent(
        taskId: task.id,
        templateId: templateId,
        profileId: category.defaultProfileId,
        allowedCategoryIds: {category.id},
        additionalWakeTokens: {?audioId},
      );
      await _seedChecklistProposals(
        agentId: identity.agentId,
        taskId: task.id,
        items: items,
      );
    } catch (e, stackTrace) {
      developer.log(
        'Failed to auto-assign agent for onboarding task ${task.id}: $e',
        name: 'OnboardingCaptureToTaskService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Seeds the structured checklist as **pending proposals** under [agentId] on
  /// [taskId], so the user confirms them — individually or via "Confirm all" —
  /// on the task page, in the same proposal card Laura's own suggestions render
  /// in, rather than the items being silently auto-committed.
  ///
  /// Built with the same [ChangeSetBuilder] a wake uses: an
  /// `add_multiple_checklist_items` batch is exploded into one pending
  /// `add_checklist_item` proposal per line ([ChangeSetBatchExplosion]), then
  /// persisted via the task agent's own `AgentSyncService`. Two or more items
  /// surface the "Confirm all" button; a lone item still shows as one
  /// confirmable row. The agent's concurrent creation wake merges any
  /// overlapping items into this same card, so the user never sees duplicates.
  ///
  /// Best effort: a seeding hiccup degrades to the bare-title task the agent
  /// still populates on its wake, never failing the capture. No-op when there
  /// is nothing to propose.
  Future<void> _seedChecklistProposals({
    required String agentId,
    required String taskId,
    required List<String> items,
  }) async {
    if (items.isEmpty) return;
    try {
      final builder = ChangeSetBuilder(
        agentId: agentId,
        taskId: taskId,
        threadId: _uuid.v4(),
        runKey: _uuid.v4(),
      );
      await builder.addBatchItem(
        toolName: TaskAgentToolNames.addMultipleChecklistItems,
        args: {
          'items': [
            for (final item in items) {'title': item},
          ],
        },
        summaryPrefix: 'Add',
      );
      await builder.build(_taskAgentService.syncService);
    } catch (e, stackTrace) {
      developer.log(
        'Failed to seed checklist proposals for onboarding task $taskId: $e',
        name: 'OnboardingCaptureToTaskService',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Derives a usable task title from a raw transcript: the first sentence,
  /// whitespace-collapsed and length-capped.
  String _fallbackTitle(String transcript) {
    final collapsed = transcript.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (collapsed.isEmpty) return '';

    // Split on sentence-ending punctuation only when it's followed by
    // whitespace or the end of the string, so decimals ("1.5 hours") and
    // abbreviations aren't truncated mid-token.
    final sentenceEnd = RegExp(r'[.!?]+(?=\s|$)').firstMatch(collapsed);
    final firstSentence = (sentenceEnd != null && sentenceEnd.start > 0)
        ? collapsed.substring(0, sentenceEnd.start)
        : collapsed;

    return firstSentence.length <= _maxFloorTitleLength
        ? firstSentence
        : firstSentence.substring(0, _maxFloorTitleLength).trimRight();
  }
}

/// Riverpod handle for [OnboardingCaptureToTaskService].
final onboardingCaptureToTaskServiceProvider =
    Provider<OnboardingCaptureToTaskService>(
      (ref) => OnboardingCaptureToTaskService(
        structuringService: ref.watch(onboardingTaskStructuringServiceProvider),
        metricsRepository: getIt<OnboardingMetricsRepository>(),
        categoryRepository: ref.watch(categoryRepositoryProvider),
        taskAgentService: ref.watch(taskAgentServiceProvider),
        journalRepository: ref.watch(journalRepositoryProvider),
      ),
    );
