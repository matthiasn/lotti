import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/services/onboarding_task_structuring_service.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
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
    required this._autoChecklistService,
    required this._metricsRepository,
    PersistenceLogic? persistenceLogic,
    DateTime Function()? clock,
  }) : _persistenceLogic = persistenceLogic ?? getIt<PersistenceLogic>(),
       _clock = clock ?? DateTime.now;

  final OnboardingTaskStructuringService _structuringService;
  final AutoChecklistService _autoChecklistService;
  final OnboardingMetricsRepository _metricsRepository;
  final PersistenceLogic _persistenceLogic;
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
  Future<OnboardingCaptureResult> createTaskFromTranscript({
    required String transcript,
    required String categoryId,
    String? providerName,
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
      );
    }

    final task = await _materialize(
      title: structured.title,
      items: structured.checklistItems,
      categoryId: categoryId,
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

  /// Creates the title-only task, then attaches the checklist (best effort) so
  /// a checklist hiccup degrades to a bare-title task rather than failing.
  Future<Task?> _materialize({
    required String title,
    required List<String> items,
    required String categoryId,
  }) async {
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
      ),
      entryText: EntryText(plainText: title, markdown: title),
      categoryId: categoryId,
    );

    if (task != null && items.isNotEmpty) {
      // Best effort: a checklist hiccup must degrade to the bare-title task
      // (already persisted above), not fail the whole capture.
      try {
        await _autoChecklistService.autoCreateChecklist(
          taskId: task.id,
          suggestions: [
            for (final item in items)
              ChecklistItemData(
                title: item,
                isChecked: false,
                linkedChecklists: const [],
              ),
          ],
          shouldAutoCreate: true,
        );
      } catch (_) {
        // Keep the title-only task.
      }
    }
    return task;
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
        autoChecklistService: AutoChecklistService(
          checklistRepository: ref.watch(checklistRepositoryProvider),
        ),
        metricsRepository: getIt<OnboardingMetricsRepository>(),
      ),
    );
