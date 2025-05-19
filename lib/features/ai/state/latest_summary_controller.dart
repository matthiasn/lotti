import 'dart:async';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/state/action_item_suggestions_prompt.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/task_summary_controller.dart';
import 'package:lotti/features/ai/state/task_summary_prompt.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'latest_summary_controller.g.dart';

@riverpod
class LatestSummaryController extends _$LatestSummaryController {
  LatestSummaryController() {
    listen();
  }

  StreamSubscription<Set<String>>? _updateSubscription;
  final UpdateNotifications _updateNotifications = getIt<UpdateNotifications>();
  final watchedIds = <String>{aiResponseNotification};

  void listen() {
    _updateSubscription =
        _updateNotifications.updateStream.listen((affectedIds) {
      if (affectedIds.intersection(watchedIds).isNotEmpty) {
        _fetch().then((latest) {
          if (latest != state.value) {
            state = AsyncData(latest);
          }
        });
      }
    });
  }

  @override
  Future<AiResponseEntry?> build({
    required String id,
    required AiResponseType aiResponseType,
  }) async {
    ref.onDispose(() => _updateSubscription?.cancel());
    watchedIds
      ..add(id)
      ..add(aiResponseNotification);
    final latestAiEntry = await _fetch();
    return latestAiEntry;
  }

  Future<AiResponseEntry?> _fetch() async {
    final linked = await ref
        .read(journalRepositoryProvider)
        .getLinkedEntities(linkedTo: id);

    return linked
        .whereType<AiResponseEntry>()
        .where((element) => element.data.type == aiResponseType)
        .firstOrNull;
  }

  Future<void> removeActionItem({
    required String title,
  }) async {
    final latestAiEntry = state.valueOrNull;

    if (latestAiEntry == null) {
      return;
    }

    final updated = latestAiEntry.copyWith(
      data: latestAiEntry.data.copyWith(
        suggestedActionItems: latestAiEntry.data.suggestedActionItems
            ?.where((item) => item.title != title)
            .toList(),
      ),
    );

    state = AsyncData(updated);
    await ref.read(journalRepositoryProvider).updateJournalEntity(updated);
  }
}

@riverpod
class IsLatestSummaryOutdatedController
    extends _$IsLatestSummaryOutdatedController {
  Timer? _timer;

  @override
  Future<bool> build({
    required String id,
    required AiResponseType aiResponseType,
  }) async {
    if (aiResponseType == AiResponseType.taskSummary && !isTestEnv) {
      _timer ??= Timer.periodic(
        const Duration(seconds: 5),
        (timer) async {
          final enableAutoTaskTldr =
              await getIt<JournalDb>().getConfigFlag(enableAutoTaskTldrFlag);

          if (!enableAutoTaskTldr) {
            return;
          }

          final isOutdated = await build(
            id: id,
            aiResponseType: aiResponseType,
          );

          if (!isOutdated) {
            return;
          }

          final inferenceStatus = ref.read(
            inferenceStatusControllerProvider(
              id: id,
              aiResponseType: aiResponseType,
            ),
          );

          final isRunning = inferenceStatus == InferenceStatus.running;

          if (!isRunning) {
            await ref
                .read(taskSummaryControllerProvider(id: id).notifier)
                .getTaskSummary();
          }
        },
      );
    }
    final latestSummary = await ref.watch(
      latestSummaryControllerProvider(
        id: id,
        aiResponseType: aiResponseType,
      ).future,
    );

    final latestSummaryPrompt = latestSummary?.data.prompt;

    final latestUnrealizedPrompt = aiResponseType == AiResponseType.taskSummary
        ? await ref.watch(
            taskSummaryPromptControllerProvider(id: id).future,
          )
        : await ref.watch(
            actionItemSuggestionsPromptControllerProvider(id: id).future,
          );

    if (latestSummaryPrompt == null) {
      return false;
    }

    return latestSummaryPrompt != latestUnrealizedPrompt;
  }
}
